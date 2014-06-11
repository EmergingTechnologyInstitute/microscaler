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

module ASG

# manage launch configurations for autoscaling groups
  class LConfManager < ASG::EntityManager
    def initialize
      @conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
      asg_db=@conf["database"]["asg_db"]
      asg_user=@conf["database"]["asg_user"]
      asg_password=@conf["database"]["asg_password"]
      super(asg_db,asg_user,asg_password)
      @collections_index=Hash.new 
    end

    def create_lconf(account,doc) 
      errors=JSON::Validator.validate!($LCONF_SCHEMA, doc)
      collection=get_collection(account)
      begin
        lc=retrieve_lconf(account,doc["name"])
      rescue
      end
      if(lc!=nil)
        raise "launch configuration with name '#{doc["name"]}' exists!"
      end
      instance_type=doc["instances_type"]
      if(!@conf["instance_types"].has_key?(instance_type))
        raise "instance type #{instance_type} not supported."
      end
      create(collection,doc)
    end

    def update_lconf(account,name,doc)
      collection=get_collection(account)
      #doc["name"]=name
      current_doc=retrieve_lconf(account,name)
        L.debug current_doc
      upd_doc(doc,current_doc)  
        L.debug current_doc
      if(current_doc['metadata']==nil)
        current_doc['metadata']={}
      end
      update(collection,{"name"=>name},current_doc)
    end

    def retrieve_lconf(account,name)
      collection=get_collection(account)
      doc=retrieve(collection,{"name"=>name})
      if(doc.size==1)
        return remove_db_id(doc)[0]
      else
        raise "entity with name #{name} not found for account #{account}"
      end
    end

    def delete_lconf(account,name)
      collection=get_collection(account)
      retrieve_lconf(account,name)
      delete(collection,{"name"=>name})
    end

    def list_lconfs(account)
      collection=get_collection(account)
      doc=list_all(collection)
      remove_db_id(doc)
    end

    private
    def get_collection(account)
      collection="#{account}.launch-configurations"
      if(@collections_index[collection]==nil)
        create_index(collection,"name")
        @collections_index[collection]=true
      end
      collection
    end

  end
end

