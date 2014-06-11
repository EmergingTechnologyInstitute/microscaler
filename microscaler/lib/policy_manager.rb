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
require "#{File.dirname(__FILE__)}/rest_client"

module ASG

# manage policies for autoscaling groups
  class PolicyManager < ASG::EntityManager
    def initialize(asg_manager)
      conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
      asg_db=conf["database"]["asg_db"]
      asg_user=conf["database"]["asg_user"]
      asg_password=conf["database"]["asg_password"]
      autoscaler_url=conf["autoscaler"]["url"]
      @autoscaler_default_space=conf["autoscaler"]["default_space"]
      super(asg_db,asg_user,asg_password)
      @asgm=asg_manager
      @rest=ASG::RestClient.new(autoscaler_url)
      @collections_index=Hash.new
    end

    def create_policy(account,doc) 
      errors=JSON::Validator.validate!($POLICY_SCHEMA, doc)
      collection=get_collection(account)
      begin
        tr=retrieve_policy(account,doc["name"])
      rescue
      end
      if(tr!=nil)
        raise "policy with name '#{doc["name"]}' exists!"
      end
      create_or_update_as_policy(account,doc)
      create_or_update_as_asg(account,doc)
      create(collection,doc)
    end

    def update_policy(account,name,doc)
      collection=get_collection(account)
      #doc["name"]=name
      current_doc=retrieve_policy(account,name)
      upd_doc(doc,current_doc)  
      create_or_update_as_policy(account,current_doc)
      create_or_update_as_asg(account,current_doc)
      update(collection,{"name"=>name},current_doc)
    end

    def retrieve_policy(account,name)
      collection=get_collection(account)
      doc=retrieve(collection,{"name"=>name})
      if(doc.size==1)
        return remove_db_id(doc)[0]
      else
        raise "entity with name #{name} not found for account #{account}"
      end
    end

    def delete_policy(account,name)
      collection=get_collection(account)
      policy_doc=retrieve_policy(account,name)
      asg_name=policy_doc["auto_scaling_group"]
      delete_as_asg(account,asg_name)
      delete_as_policy(account,name)
      delete(collection,{"name"=>name})
    end

    def list_policies(account)
      collection=get_collection(account)
      doc=list_all(collection)
      remove_db_id(doc)
    end

    private
    def get_collection(account)
      collection="#{account}.policies"
      if(@collections_index[collection]==nil)
        create_index(collection,"name")
        @collections_index[collection]=true
      end
      collection
    end

    def create_or_update_as_policy(account,policy_doc)
      policy=build_policy(account,policy_doc)
      policy_name=policy_doc["name"]  
      as_tr=get_as_policy(account,policy_name)
      if(as_tr==nil)
        #create
        post_as_policy(account,policy_name,policy)
      else
        #update
        put_as_policy(account,policy_name,policy)
      end
    end

    def create_or_update_as_asg(account,policy_doc)
      policy_name=policy_doc["name"]
      asg_name=policy_doc["auto_scaling_group"]
      asg=get_as_asg(account,asg_name)
      if(asg==nil)
        #create
        post_as_asg(account,asg_name,policy_name)
      else
        #update
        put_as_asg(account,asg_name,policy_name)
      end
    end

    def build_policy(account,policy_doc)
      asg_name=policy_doc["auto_scaling_group"]
      asg_doc=@asgm.retrieve_asg(account,asg_name)
      if(asg_doc==nil)
        raise "could not find asg with name #{asg_name}"
      end
      policy={"instanceMinCount"=>asg_doc["min_size"].to_s,"instanceMaxCount"=>asg_doc["max_size"].to_s,"metricType"=>policy_doc["metric"],"statType"=>policy_doc["statistic"].downcase,"statWindow"=>policy_doc["sampling_window"].to_s,"breachDuration"=>policy_doc["breach_duration"].to_s,"lowerThreshold"=>policy_doc["lower_threshold"].to_s,"upperThreshold"=>policy_doc["upper_threshold"].to_s,"instanceStepCountDown"=>policy_doc["scale_in_step"].to_s,"instanceStepCountUp"=>policy_doc["scale_out_step"].to_s,"stepDownCoolDownSecs"=>asg_doc["scale_in_cooldown"].to_s,"stepUpCoolDownSecs"=>asg_doc["scale_out_cooldown"].to_s}
    end

    def get_as_policy(account,policy_name)
      response=@rest.get("/org/#{account}/space/#{@autoscaler_default_space}/policies/#{policy_name}",{"AUTH_TOKEN"=>"x123"})
      if(response.code=="400")
        nil
      else
        response.body
      end
    end

    def post_as_policy(account,policy_name,policy_doc)
      response=@rest.post("/org/#{account}/space/#{@autoscaler_default_space}/policies/#{policy_name}",policy_doc,nil)
    end

    def put_as_policy(account,policy_name,policy_doc)
      response=@rest.put("/org/#{account}/space/#{@autoscaler_default_space}/policies/#{policy_name}",policy_doc,nil)
    end

    def delete_as_policy(account,policy_name)
      response=@rest.delete("/org/#{account}/space/#{@autoscaler_default_space}/policies/#{policy_name}",nil)
    end

    def get_as_asg(account,asg_name)
      response=@rest.get("/org/#{account}/space/#{@autoscaler_default_space}/apps/#{asg_name}",nil)
      if(response.code=="400")
        nil
      else
        response.body
      end
    end

    def post_as_asg(account,asg_name,policy_name)
      response=@rest.post("/org/#{account}/space/#{@autoscaler_default_space}/apps/#{asg_name}",{"configId"=>policy_name},nil)
    end

    def put_as_asg(account,asg_name,policy_name)
      response=@rest.put("/org/#{account}/space/#{@autoscaler_default_space}/apps/#{asg_name}",{"configId"=>policy_name},nil)
    end

    def delete_as_asg(account,asg_name)
      response=@rest.delete("/org/#{account}/space/#{@autoscaler_default_space}/apps/#{asg_name}",nil)
    end
  end

end

