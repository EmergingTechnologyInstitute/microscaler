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
require "json"
require "json-schema"
require "#{File.dirname(__FILE__)}/model"
require "#{File.dirname(__FILE__)}/client_factory"
require "nats/client"
require "pp"
require "uuidtools"
require "yaml"
require "logger"
require "#{File.dirname(__FILE__)}/constants"
require "#{File.dirname(__FILE__)}/lb_manager"
require "#{File.dirname(__FILE__)}/lconf_manager"
require "#{File.dirname(__FILE__)}/instance_manager"
require "#{File.dirname(__FILE__)}/asg_manager"
require "#{File.dirname(__FILE__)}/auth_manager"

module ASG
  # manage health for autoscaling groups
  class HealthManager
    def initialize()
      conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
      @updater_interval=conf["health_manager"]["updater_interval"]
      @reconciler_interval=conf["health_manager"]["reconciler_interval"]
      @max_age_stale=conf["health_manager"]["max_age_stale"]
      @max_age_from_launch=conf["health_manager"]["max_age_from_launch"]
      @stalled=conf["instance_manager"]["stalled"]
      @register_subject=conf["health_manager"]["register_subject"]
      @unregister_subject=conf["health_manager"]["unregister_subject"]
      lbm=ASG::LbManager.new
      lcm=ASG::LConfManager.new
      @im=ASG::InstanceManager.new
      @am=ASG::AuthManager.new
      @asgm=ASG::ASGManager.new(@am,lbm,lcm,@im)
      @asgs=Hash.new
    end

    def run
      NATS.start do
        setup_listeners
        setup_updaters
        setup_reconcilers
      end
    end

    def get_map
      @asgs
    end

    private

    def setup_listeners
      NATS.subscribe(@register_subject) { |msg|
        #L.debug msg
        update_instances(JSON.parse(msg))
      }
      NATS.subscribe(@unregister_subject) { |msg|
        #L.debug msg
      }
    end

    def setup_updaters
      EM.add_periodic_timer(@updater_interval) {
        updater
      }
    end

    def setup_reconcilers
      EM.add_periodic_timer(@reconciler_interval) {
        reconciler
      }
    end

    def update_instances(msg)
      instance_id=msg["tags"]["metrics"]["instanceID"]
      account=msg["tags"]["metrics"]["account"]
      asg_name=msg["tags"]["metrics"]["appId"]
      ip_address=msg["host"]

      asg_key=get_asg_key(account, asg_name)
      asg_entry=@asgs[asg_key]
      if(asg_entry==nil)
        instances=Hash.new
        ts=0
      else
        instances=asg_entry[0]
        ts=asg_entry[1]
      end  
      if(!instances.has_key?(instance_id))
        begin
          L.debug "HM ---> new instance id=#{instance_id} account=#{account} asg_name=#{asg_name}"
          x=@im.query_instances(account,{"name"=>asg_name,"instance_id"=>instance_id},nil,1)
          if(x.length>0)
            x[0]["status"]=RUNNING_STATE
            x[0]["private_ip_address"]=ip_address
            @im.create_or_update_instance(account,x[0])
          end
        rescue=>e
          L.error e.message
        end
      end

      instances[instance_id]=Time.now.to_i
      @asgs[asg_key]=[instances,ts]
    end

    def updater
      @asgs.each do |asg_key,asg_entry|
        instances=asg_entry[0]
        instances.delete_if{ |id,ts|
          stale = Time.now.to_i-ts > @max_age_stale
          if(stale)
            begin
              s=asg_key.split('.')
              account=s.first
              asg_name=s.last
              L.debug "HM --> stale instance id=#{id} account=#{account} asg_name=#{asg_name}"
              x=@im.query_instances(account,{"name"=>asg_name,"instance_id"=>id},nil,1)
              if(x.length>0)
                x[0]["status"]=NOT_RUNNING_STATE
                @im.create_or_update_instance(account,x[0])
              end
            rescue=>e
              L.error e.message
            end
          end
          stale
        }
      end
    end

    # run periodically compare actual state as from in-memory registry with
    # desired state as the # of instances from IM (including those in 'down' state)
    def reconciler
      begin
        accounts=@im.list_accounts
        accounts.each { |account|
          asgs=@asgm.list_asgs(account)
          asgs.each { |asg|
            # get the desired state
            asg_name=asg["name"]
            asg_def=@asgm.retrieve_asg(account,asg_name)
            if(asg_def['state']==ASG_STATE_STARTED)
              desired_count=asg_def['desired_capacity']
              min_size=asg_def['min_size']
              max_size=asg_def['max_size']
              # check that we are not in a cooldown period  
              if((asg_def['last_scale_in_ts']!=nil && Time.now.to_i-asg_def['last_scale_in_ts']<=asg_def['scale_in_cooldown']) or 
                (asg_def['last_scale_out_ts']!=nil && Time.now.to_i-asg_def['last_scale_out_ts']<=asg_def['scale_in_cooldown']) ) 
                L.debug "HM ---> asg=#{asg_name} account=#{account} is in COOLDOWN state! no action taken until cooldown expires."   
                next  
              end  
              # compare state only if there are instances started from IM
              if(desired_count>0)
                actual_count=get_actual_state(account,asg_name)
                stalled=@im.query_instances(account,{"name"=>asg_name,"status"=>STALLED_STATE},nil,1000)
                stalled_count=stalled.length  
                L.debug "HM ---> target=#{desired_count}, actual=#{actual_count}, stalled=#{stalled_count} asg=#{asg_name} account=#{account}"                
                if(desired_count>actual_count &&
                (Time.now.to_i - max_ts_launched(account,asg_name)>@max_age_from_launch)  &&
                actual_count < max_size && stalled_count < max_size)
                  L.debug "HM ---> scale-up asg=#{asg_name} account=#{account}"
                  lock=@im.lease_lock(account,asg_name,START_TYPE_LEASE,desired_count-actual_count)
                  if(lock!=nil )
                    if (!@im.instances_starting?(account,asg_name,TYPE_CONTAINER) && 
                    Time.now.to_i-get_last_ts_pending_action(account,asg_name)>(@max_age_stale+@updater_interval))
                      L.debug "HM ---> starting #{desired_count-actual_count} instances for #{asg_name} account=#{account}"                    
                      template=@asgm.build_template(account,asg_def)
                      start_instances(account,template,desired_count-actual_count,lock)
                      asg_def['last_scale_out_ts']=Time.now.to_i
                      @asgm.update_asg(account,asg_name,asg_def)  
                    else
                      # update timestamp for last time starting state was detected
                      asg_key=get_asg_key(account,asg_name)
                      @asgs[asg_key]=[@asgs[asg_key][0],Time.now.to_i]
                      L.warn "HM ---> waiting for other instances to start on #{asg_name} account=#{account}"    
                    end  
                  else
                     L.warn "HM ---> busy lock on #{asg_name} account=#{account}"                  
                  end
                elsif (desired_count<actual_count &&
                (Time.now.to_i - min_ts_running(account,asg_name )>@max_age_stale) &&
                actual_count > min_size)
                  L.debug "HM ---> scale-down asg=#{asg_name} account=#{account}"
                  lock=@im.lease_lock(account,asg_name,STOP_TYPE_LEASE,actual_count-desired_count)
                  if(lock!=nil)
                    if(!@im.instances_stopping?(account,asg_name,TYPE_CONTAINER) && 
                    Time.now.to_i-get_last_ts_pending_action(account,asg_name)>(@max_age_stale+@updater_interval))
                      L.debug "HM ---> stopping #{actual_count-desired_count} instances for asg=#{asg_name} account=#{account}" 
                      stop_instances(account,asg_name,TYPE_CONTAINER,actual_count-desired_count,lock)
                      asg_def['last_scale_in_ts']=Time.now.to_i
                      @asgm.update_asg(account,asg_name,asg_def)  
                    else
                      # update timestamp for last time stopping state was detected
                      asg_key=get_asg_key(account,asg_name)
                      @asgs[asg_key]=[@asgs[asg_key][0],Time.now.to_i]
                      L.debug "HM ---> waiting for other instances to stop for asg=#{asg_name} account=#{account}"
                    end   
                  else
                    L.debug "HM ---> busy lock for asg=#{asg_name} account=#{account}"
                  end
                end
              end
            else
              L.debug "HM ---> asg=#{asg_name} account=#{account} is in '#{asg_def['state']}' state - no action will be performed "
            end
          }
        }
      rescue=>e
        L.error "#{e.message} -  #{e.backtrace}"
      end
    end

    def get_asg_key(account, asg_name)
      asg_key=account+"."+asg_name
    end

    def get_instances(account,asg_name)
      asg_key=get_asg_key(account,asg_name)
      if (@asgs[asg_key]!=nil)
        return @asgs[asg_key][0]
      else
        return []
      end
    end

    # gets the last ts detected for a pending action such as stopping or starting
    # this is used to wait a little after a pending action since the state might not be current
    def get_last_ts_pending_action(account,asg_name)
      asg_key=get_asg_key(account,asg_name)
      if(@asgs[asg_key]!=nil)
        return @asgs[asg_key][1]
      else
        return 0
      end
    end

    # finds the timestamp for the youngest instance that was launched
    # we use this to check if we should wait the instance starts before attempt action
    def max_ts_launched(account,asg_name) 
      instances=@im.list_instances(account,asg_name,TYPE_CONTAINER)
      ts_max=0
      instances.each do |instance|
        ts=instance["timestamp"]
        if(ts>ts_max)
          ts_max=ts
        end        
      end
      ts_max
    end

    # find the older timestamp for running instances
    def min_ts_running(account,asg_name)
      instances=get_instances(account,asg_name)
      ts_min=1073741823
      instances.each { |k,ts|
        if(ts<ts_min)
          ts_min=ts
        end
      }
      ts_min
    end

    def get_actual_state(account, asg_name)
      actual_count=0
      instances=get_instances(account,asg_name)
      if(instances!=nil)
        actual_count=instances.length
      else
        actual_count=0  
      end
      return actual_count
    end

    # launch as many instances as needed to keep actual state == desired state
    def start_instances(account,template,n_instances,lock)
      # get credentials to launch instances from auth manager
      key=@am.get_credentials(account)      
      azs=@im.pick_azs(account,template[:asg_name],template[:availability_zones],n_instances)
      (1..n_instances).each do
        @im.launch_instance(account,key,template[:asg_name],template[:type],@im.gen_hostname(account,template[:asg_name]),template[:domain],template[:n_cpus],template[:memory],azs.shift(),template[:image_id],template[:hourly_billing],lock,template[:metadata])                
      end
      
      # Garbage Collection - find and kill instances in DOWN state
      @im.gc_instances(account,key,template[:asg_name],template[:type])
    end

    # stop as many instances as needed to keep actual state == desired state
    def stop_instances(account,asg_name,type,n_instances,lock)
      key=@am.get_credentials(account)
      @im.stop_instances(account,key,asg_name,type,n_instances,lock)
    end

  end
end
