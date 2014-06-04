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

require "#{File.dirname(__FILE__)}/client_factory.rb"
require "#{File.dirname(__FILE__)}/instance_manager.rb"
require "logger"
require "uuidtools"
require "#{File.dirname(__FILE__)}/constants"


module ASG

  class StopInstanceWorker
    @queue = :stop_queue

    # stops an instance for a asg and authorized user
    # if kill == true stops an instance in DOWN state
    def self.perform(user,key,asg_name,instance_id,type,kill,lock)
      begin
        client=ASG::ClientFactory.create(user,key)
        im=ASG::InstanceManager.new()        
        im.release_lock(user,asg_name,lock)
        if(!kill)
          L.debug "stopping #{instance_id} lock=#{lock}"
          # need to check that the instance is in a started state so it can be deleted,
          # otherwise wait until either get to running state or times out       
          n=0
          while true do
            status=client.check_container_status(instance_id)
            p status
            n+=1
            if(status["status"]==RUNNING_STATE  || n>MAX_TIME/INTERVAL)
              break
            end
            sleep(INTERVAL)
          end
        else
          L.debug "garbage collecting #{instance_id} lock=#{lock}"
        end      
        status=client.delete_container(instance_id)
        # delete from IM
        im.delete_instance(user,asg_name,instance_id,type)
      rescue=>e
        L.error "#{e.message} -  #{e.backtrace}"
      end
    end
  end
  
  # launch   an instance and store id and metadata in DB
  class LaunchInstanceWorker
    @queue = :launch_queue
    conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
         
    def self.perform(user,key,asg_name,type,hostname,domain,n_cpus,max_memory,availability_zone,image_id,hourly_billing,lock,metadata)
          begin           
            client=ASG::ClientFactory.create(user,key)
            im=ASG::InstanceManager.new()
            im.release_lock(user,asg_name,lock)
          
            # prepare user metadata to be associated with the instance
            user_domain="#{user.downcase}.#{@lb_domain}"
            if(metadata!=nil && metadata['local_http_port']!=nil)
              local_http_port=metadata['local_http_port']  # currently we use metadata to propagate the value of the local http port
              metadata.delete('local_http_port')    # remove now from metadata
            else
              local_http_port=""  
            end
            user_data=build_user_data(asg_name,user,user_domain,local_http_port,metadata)
    
            # launch
            result=client.launch_container(hostname,domain,n_cpus,max_memory,availability_zone,image_id,hourly_billing,user_data)
            L.debug "container launched with id=#{result["id"]}, user metadata=#{user_data}, FQHN=#{hostname}.#{domain}, AZ=#{availability_zone}"
            if(result["status"]!="OK")
              raise result["message"]
            end
            guid=UUIDTools::UUID.random_create.to_s
            doc=build_doc(guid,result["id"].to_s,asg_name,type,hostname,domain,n_cpus,max_memory,availability_zone,image_id,hourly_billing,metadata)           
            im.create_or_update_instance(user,doc)          
          rescue=>e
            L.error "#{e.message} -  #{e.backtrace}"
          end
        end
          
        def self.build_doc(guid,instance_id,asg_name,type,hostname,domain,n_cpus,max_memory,availability_zone,image_id,hourly_billing,metadata)
          doc={"guid"=>guid,"name"=>asg_name,"instance_id"=>instance_id,"type"=>type,"status"=>STARTING_STATE,"private_ip_address"=>"","public_ip_address"=>"","hostname"=>hostname,"domain"=>domain,"n_cpus"=>n_cpus,"max_memory"=>max_memory,"availability_zone"=>availability_zone,"image_id"=>image_id,"hourly_billing"=>hourly_billing,"timestamp"=>Time.now.to_i,"metadata"=>metadata}
        end
        
        def self.build_user_data(asg_name,account,lb_domain,local_http_port,metadata)
          {'asg_name'=>asg_name,'account'=>account,'domain'=>lb_domain,'local_http_port'=>local_http_port,'metadata'=>metadata}
        end
      end
    end