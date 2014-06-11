################################################################################
# Copyright (c) 2014 IBM Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

require "mongo"
require "yaml"
require "json-schema"
require "#{File.dirname(__FILE__)}/model"
require "logger"
require "#{File.dirname(__FILE__)}/constants"

module ASG
  # manage launch configurations for autoscaling groups
  class ASGManager < ASG::EntityManager
    ASG_COLLECTION="autoscaling-groups"
    def initialize(auth_manager,lb_manager,lc_manager,i_manager)
      @conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
      asg_db=@conf["database"]["asg_db"]
      asg_user=@conf["database"]["asg_user"]
      asg_password=@conf["database"]["asg_password"]
      @lb_domain=@conf['load_balancer']['domain'] 
      super(asg_db,asg_user,asg_password)
      @collections_index=Hash.new
      @am=auth_manager
      @lbm=lb_manager
      @lcm=lc_manager
      @im=i_manager
      i=$AS
    end

    def create_asg(account,doc)
      doc["state"]= ASG_STATE_STOPPED
      if(doc['load_balancer']!=nil) 
        doc['url']="#{doc['name']}.#{account.downcase}.#{@lb_domain}"
      else
        doc['url']='N/A'     
      end  
      check(doc)
      collection=get_collection(account)
      begin
        asg=retrieve_asg(account,doc["name"])
      rescue
      end
      if(asg!=nil)
        raise "asg configuration with name '#{doc["name"]}' exists!"
      end    
      create(collection,doc)
    end

    def update_asg(account,name,doc)
      collection=get_collection(account)
      doc["name"]=name
      if(doc['load_balancer']!=nil) 
        doc['url']="#{doc['name']}.#{account.downcase}.#{@lb_domain}" 
      else
        doc['url']='N/A'     
      end     
      current_doc=retrieve_asg(account,name)  
      upd_doc(doc,current_doc)            
      L.debug current_doc 
      check(current_doc)  
      if(current_doc['state']==ASG_STATE_STARTED)
        # get credentials to launch instances from auth manager
        key=@am.get_credentials(account)
        @im.update_num_instances(account,key,name,TYPE_CONTAINER,current_doc['desired_capacity'],current_doc['availability_zones'],build_template(account,current_doc))
      end
      update(collection,{"name"=>name},current_doc)
    end

    def retrieve_asg(account,name)
      collection=get_collection(account)
      doc=retrieve(collection,{"name"=>name})
      if(doc.size==1)
        return remove_db_id(doc)[0]
      else
        raise "entity with name #{name} not found for account #{account}"
      end
    end

    def delete_asg(account,name)
      collection=get_collection(account)
      asg_doc=retrieve_asg(account,name)
      if(asg_doc["state"]!=ASG_STATE_STOPPED)
        raise "ASG #{name} is not stopped - please stop autoscaling group before deleting it"
      end
      delete(collection,{"name"=>name})
    end

    def list_asgs(account)
      collection=get_collection(account)
      doc=list_all(collection)
      remove_db_id(doc)
    end

    # gather all the info set for load balancer, launch config and asg to start the ASG
    def start_asg(account,name)
      # note: if using ELB needs integration with ELB APIs
      asg_doc=retrieve_asg(account,name)
      if(asg_doc["state"]==ASG_STATE_STARTED)
        raise "ASG #{name} is already started"
      end

      # get credentials to launch instances from auth manager
      key=@am.get_credentials(account)
      template=build_template(account,asg_doc)
      desired=template[:desired]
      # launch ASG instances
      lock=@im.lease_lock(account,name,START_TYPE_LEASE,desired)
      if(lock!=nil)
        azs=@im.pick_azs(account,name,template[:availability_zones],desired)
        (1..desired).each do
          @im.launch_instance(account,key,name,template[:type],@im.gen_hostname(account,name),template[:domain],template[:n_cpus],template[:memory],azs.shift(),template[:image_id],template[:hourly_billing],lock,template[:metadata])
        end
      end
      # update the state of the ASG
      asg_doc=retrieve_asg(account,name)
      asg_doc["state"]=ASG_STATE_STARTED
      asg_doc['last_scale_out_ts']=Time.now.to_i
      update(get_collection(account),{"name"=>name},asg_doc)
    end
   
    def stop_asg(account,name)
      asg_doc=retrieve_asg(account,name)
      if(asg_doc["state"]==ASG_STATE_STOPPED)
        raise "ASG #{name} is already stopped"
      end
      # stop all - HM should take care of makig state what is expected
      x=@im.list_instances(account,name,TYPE_CONTAINER)
      key=@am.get_credentials(account)
      lock=@im.lease_lock(account,name,STOP_TYPE_LEASE,x.length)
      (1..x.length).each do
        @im.stop_instance(account,key,name,TYPE_CONTAINER,lock)
      end
      # update the state of the ASG
      asg_doc["state"]=ASG_STATE_STOPPED
      update(get_collection(account),{"name"=>name},asg_doc)
    end

    # build the template we need to launch a new ASG instance
    def build_template(account,asg_doc)
      if(asg_doc['load_balancer']!=nil)
        lb_doc=@lbm.retrieve_lb(account,asg_doc["load_balancer"])
        if(lb_doc==nil)
          raise "could not find load balancer configuration: #{asg_doc["load_balancer"]}"
        end
      end
      lc_doc=@lcm.retrieve_lconf(account,asg_doc["launch_configuration"])
      if(lc_doc==nil)
        raise "could not find launch configuration #{asg_doc["launch_configuration"]}"
      end       
      if(lc_doc['metadata']==nil)
        lc_doc['metadata']=Hash.new
      end
      if(lb_doc!=nil)
        lc_doc['metadata']['local_http_port']=lb_doc['instances_port']
      end   
      {:asg_name=>asg_doc['name'],:instance_type=>lc_doc["instances_type"],:n_cpus=>@conf["instance_types"]["m1.small"]["vcpu"],
       :memory=>@conf["instance_types"]["m1.small"]["memory"],:desired=>asg_doc["desired_capacity"],
       :type=>TYPE_CONTAINER,:domain=>asg_doc["domain"],:image_id=>lc_doc["image_id"],
       :hourly_billing=>@conf["instances"]["hourly_billing"],:availability_zones=>asg_doc["availability_zones"],:metadata=>lc_doc['metadata']}   
    end  
    
    def pause_asg(account,name)
      collection=get_collection(account)
      doc=retrieve(collection,{"name"=>name})
      if(doc["state"]==ASG_STATE_RUNNING)
        doc["state"]=ASG_STATE_PAUSED
        update(collection,{"name"=>name},doc)
      else
        raise "ASG #{name} could not be paused for account #{account} - not in running state"
      end
    end

    def resume_asg(account,name)
      collection=get_collection(account)
      doc=retrieve(collection,{"name"=>name})
      if(doc["state"]==ASG_STATE_PAUSED)
        doc["state"]=ASG_STATE_RUNNING
        update(collection,{"name"=>name},doc)
      else
        raise "ASG #{name} could not be resumed for account #{account} - not in paused state"
      end
    end

    private

    def get_collection(account)
      collection="#{account}.autoscaling-groups"
      if(@collections_index[collection]==nil)
        create_index(collection,"name")
        @collections_index[collection]=true
      end
      collection
    end
    
    def check(doc)
      errors=JSON::Validator.validate!(ASG_SCHEMA, doc)
      if(doc['no_lb']!=nil && doc['no_lb']=true)
        doc.delete('load_balancer')
      end  
      if(doc['desired_capacity']>doc['max_size'])
        raise 'cannot set target number of instances larger then max_size [#{doc["max_size"]}]'
      elsif(doc['desired_capacity']<doc['min_size'])
        raise 'cannot set target number of instances smaller then min_size [#{doc["min_size"]}]'
      end       
    end
   
  end
end

