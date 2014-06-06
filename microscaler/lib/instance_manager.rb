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
require "#{File.dirname(__FILE__)}/entity_manager.rb"
require "#{File.dirname(__FILE__)}/im_worker.rb"
require "resque"
require "uuidtools"
require "logger"
require "securerandom"
require "#{File.dirname(__FILE__)}/constants"

module ASG
# manage instances for autoscaling groups
  class InstanceManager < ASG::EntityManager
    def initialize()
      conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
      im_db=conf["database"]["im_db"]
      im_user=conf["database"]["im_user"]
      im_password=conf["database"]["im_password"]
      super(im_db,im_user,im_password)
      @stalled=conf["instance_manager"]["stalled"]
      @lease_duration=conf["instance_manager"]["lease_duration"]
      @collections_index=Hash.new
    end

    def create_or_update_instance(account,doc)
      collection=get_collection(account)
      errors=JSON::Validator.validate!($INSTANCE_SCHEMA, doc)
      name=doc["name"]
      instance_id=doc["instance_id"]
      type=doc["type"]
      begin
        inst=retrieve_instance(account,name,instance_id,type)
      rescue
      end
      if(inst!=nil)
          update(collection,{"name"=>name,"instance_id"=>instance_id,"type"=>type},doc)
      else
          create(collection,doc)   
      end     
    end

    def retrieve_instance(account,name,instance_id,type)
      collection=get_collection(account)
      doc=retrieve(collection,{"name"=>name,"instance_id"=>instance_id,"type"=>type})       
      if(doc.size==1)
        return remove_db_id(doc)[0]
      else
        raise "instance #{instance_id} and type #{type} for asg #{name} not found for account #{account}" 
      end
    end

    # query instances, where the query is of the form: 
    # e.g. {"name"=>name,"type"=>type}
    def query_instances(account,query,sorter,limit)
      collection=get_collection(account)
      if(sorter==nil)
        sorter={}
      end
      if(limit==nil)
        limit=100000 # if no limit is specified return all
      end
      doc=find(collection,query,sorter,limit)
      remove_db_id(doc)
    end
    
    def lease_lock(account,asg_name,type,count)
      collection=get_lease_collection(account)
      x=find(collection,{"asg_name"=>asg_name,"type"=>type},{},1)
      if(x.length>0)
        if(Time.now.to_i-x[0]["timestamp"]>@lease_duration)
          delete(collection,{"asg_name"=>asg_name,"type"=>type})
        else
          L.debug "cannot lease lock for account #{account} and asg #{asg_name}"
          return nil
        end
      end
      lock=UUIDTools::UUID.random_create.to_s
      create(collection,{"asg_name"=>asg_name,"type"=>type, "id"=>lock, "count"=>count, "timestamp"=>Time.now.to_i})
      lock
    end

    def release_lock(account,asg_name,lock)
      collection=get_lease_collection(account)
      x=find(collection,{"asg_name"=>asg_name,"id"=>lock},{},1)
      if(x.length==0)
        L.error "no lock with id=#{lock} for asg #{asg_name} found"
        return
      end
      count=x[0]["count"]
      if(count==1)
        L.debug "deleting lock #{lock} type=#{x[0]["type"]} asg=#{asg_name}"
        delete(collection,{"asg_name"=>asg_name,"id"=>lock})
      elsif (count>1)
        L.debug "setting lock count to #{count-1} for #{lock} type=#{x[0]["type"]} asg=#{asg_name}"
        update(collection,{"asg_name"=>asg_name,"id"=>lock},{"asg_name"=>asg_name,"type"=>x[0]["type"], "id"=>lock, "count"=>count-1, "timestamp"=>x[0]["timestamp"]})
      else
        raise "issue with decrementing count - count=#{count}"  
      end
    end
    
    def delete_instance(account,name,instance_id,type)
      collection=get_collection(account)
      retrieve_instance(account,name,instance_id,type)
      delete(collection,{"name"=>name,"instance_id"=>instance_id,"type"=>type})
    end

    def list_instances(account,name,type)
      collection=get_collection(account)
      doc=retrieve(collection,{"name"=>name,"type"=>type})
      remove_db_id(doc)
    end

    def instances_starting?(account,name,type)
      x=query_instances(account,{"name"=>name,"type"=>type,"status"=>STARTING_STATE},{},1000)
      starting=false
      x.each{ |instance| 
        if(Time.now.to_i-instance["timestamp"] > @stalled)
          instance["status"]=STALLED_STATE
          update(get_collection(account),{"name"=>name,"instance_id"=>instance["instance_id"],"type"=>type},instance)
        else
          starting=true  
        end
      }
      starting
    end

    def instances_stopping?(account,name,type)
      x=query_instances(account,{"name"=>name,"type"=>type,"status"=>STOPPING_STATE},{},1)
      if(x.length>0)
        return true
      else
        return false
      end
    end

    # launch an instance using the job queue and async workers
    def launch_instance(user,key,asg_name,type,hostname,domain,n_cpus,max_memory,availability_zone,image_id,hourly_billing,lock,metadata)
      L.debug "launching instance for asg=#{asg_name} and user=#{user} with az=#{availability_zone}"
      Resque.enqueue(ASG::LaunchInstanceWorker,user,key,asg_name,type,hostname,domain,n_cpus,max_memory,availability_zone,image_id,hourly_billing,lock,metadata)
    end

   # stops an instance using the job queue and async workers 
    def stop_instance(user,key,asg_name,type,lock)
      instance_id=stop_policy(user,asg_name,type)   
      if(instance_id!=nil)   
        L.debug "stopping instance for asg=#{asg_name} and user=#{user} with id=#{instance_id}"
        Resque.enqueue(ASG::StopInstanceWorker,user,key,asg_name,instance_id,type,false,lock)
      else
        L.error "stop policy could not find instances to stop for asg=#{asg_name} and user=#{user}"
      end    
    end
    
    # GC dead instances
    def gc_instances(user,key,asg_name,type)
      instances=query_instances(user,{"name"=>asg_name,"type"=>type, "status"=>NOT_RUNNING_STATE},{"timestamp"=>1},1000) 
      if(instances.length>0)
        L.debug "GC: found #{instances.length} instance(s) to remove for asg=#{asg_name} and user=#{user}"  
        stop_lock=lease_lock(user,asg_name,STOP_TYPE_LEASE,instances.length)   
        instances.each do |instance|
          instance_id=instance['instance_id']
          L.debug "garbage collecting instance for asg=#{asg_name} and user=#{user} with id=#{instance_id}"
          #delete_instance(user,asg_name,instance_id,type)
          Resque.enqueue(ASG::StopInstanceWorker,user,key,asg_name,instance_id,type,true,stop_lock)
        end    
      end
    end
 
    # generate a unique hostname
    def gen_hostname(account,asg_name)
      # generate a short unique ID and use for the hostname
      id = SecureRandom.hex(5)
      "#{asg_name.gsub("_", "-")}-#{id}" 
    end

    # updates & sets a absolute number of instances
    def update_num_instances(account,key,asg_name,type,n_instances,availability_zones,template)
      t=list_instances(account,asg_name,type)
      n_current=t.length
      n_delta=n_instances-n_current
      if(n_delta>0)
        lock=lease_lock(account,asg_name,START_TYPE_LEASE,n_delta)
        if(lock!=nil)
          L.debug "starting #{n_delta} instances"
          start_instances(account,key,asg_name,type,n_delta,lock,availability_zones,template)
        else
          L.warn "could not acquire lock for updating n instances"
        end
      elsif (n_delta<0)
        lock=lease_lock(account,asg_name,STOP_TYPE_LEASE,n_delta.abs)
        if(lock!=nil)
          L.debug "stopping #{n_delta.abs} instances"
          stop_instances(account,key,asg_name,type,n_delta.abs,lock)
        else
          L.warn "could not acquire lock for stopping n instances"
        end
      else
        L.debug "nothing to be done"  
      end
    end

    # launch n instances for a ASG 
    def start_instances(account,key,asg_name,type,n_instances,lock,availability_zones,template)
      azs=pick_azs(account,asg_name,availability_zones,n_instances)
      (1..n_instances).each do
        launch_instance(account,key,template[:asg_name],type,gen_hostname(account,template[:asg_name]),template[:domain],template[:n_cpus],template[:memory],azs.shift(),template[:image_id],template[:hourly_billing],lock,template[:metadata])
       end
    end
    
    # stop n instances for an ASG
    def stop_instances(account,key,asg_name,type,n_instances,lock)
      (1..n_instances).each do
        stop_instance(account,key,asg_name,type,lock)
      end
    end
    
    # picks a list of availability zone to be used when a list of availability zones is provided.
    # currently the same weight should be assigned to all availability zones and we should just
    # round robin between AZs
    def pick_azs(account,asg_name,availability_zones,n)
      azs=Array.new
      if(availability_zones.length==1)
        (1..n).each do
          azs.push(availability_zones[0])
        end  
        return azs
      end
      
      # create a list of all the AZs to use - key is AZ name, value is how many are already deployed 
      # assign initially 0 to each entry 
      list = Hash.new
        availability_zones.each do |az|
        list[az]=0
      end  
      
      # now query instance manager to check what instances are already running and get the AZs for them
      instances=query_instances(account,{"name"=>asg_name,"type"=>TYPE_CONTAINER,"status"=>RUNNING_STATE},{},1000) 
      
      # now update the list with the number of instances in each AZ
      instances.each do |i|
        az=i['availability_zone']
        list[az]=list[az]+1  
      end 
      
      (1..n).each do   
        # sort in ascending order and iterate the instance that has the lowest value
        array=list.sort_by{|k,v| v}
        # pick entry with lowest # of instances
        az=array[0][0]  
        azs.push(az)
        # update the list 
        list[az]=list[az]+1
      end  
      azs  
    end  
    
    private
    # stop policy based on removing instances belonging to the availability zone with more instances
    # first we pick az, the we pick the oldest instance for that az 
    # why oldest : to reduce chances of trying to stop an instance that is started
    def stop_policy(account,asg_name,type) 
      instances=query_instances(account,{"name"=>asg_name,"type"=>type,"status"=>{:$in=>[RUNNING_STATE,STARTING_STATE]}},{},1000) 
      if(instances.length==0)
        return instances
      end  
      azs=Hash.new
      # now update the list with the number of instances in each AZ
      instances.each do |i|
        az=i['availability_zone']
        if(azs[az]==nil)
          azs[az]=0
        else    
          azs[az]=azs[az]+1
        end    
      end 
      sorted=azs.sort_by{|k,v| v}     
      az=sorted.pop[0]
      L.debug "going to stop instance for az=#{az}"
      # finally, pick the oldest instance for the picked az
      instance=query_instances(account,{"name"=>asg_name,"type"=>type, "availability_zone"=>az,"status"=>{:$in=>[RUNNING_STATE,STARTING_STATE]}},{"timestamp"=>1},1)  
      if(instance.length==0)
        raise 'could not find am instance to stop for asg=#{asg_name} account=#{account} availability_zone=#{az}'
      end
      # update status here
      instance[0]['status']=STOPPING_STATE
      update(get_collection(account),{"name"=>asg_name,"instance_id"=>instance[0]['instance_id']},instance[0])   
      instance[0]['instance_id']       
    end

    def get_collection(account)
      collection="#{account}.instances"
      if(@collections_index[collection]==nil)
        create_index(collection,"name")
        create_index(collection,"type")
        create_index(collection,"instance_id")
        @collections_index[collection]=true
      end
      collection
    end

    def get_lease_collection(account)
      collection="#{account}.im_lease"
      if(@collections_index[collection]==nil)
        create_index(collection,"asg_name")
        create_index(collection,"type")
        create_index(collection,"id")
        @collections_index[collection]=true
      end
      collection
    end
  end
end
