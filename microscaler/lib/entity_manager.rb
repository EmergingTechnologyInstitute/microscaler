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
require "json"

module ASG

  class EntityManager
    def initialize(dbName,user,password)
      @user=user
      @password=password
      home=File.dirname(__FILE__)
      conf=YAML.load_file("#{home}/../conf/microscaler.yml")
      address=conf["database"]["ip-address"]
      port=conf["database"]["port"]
      pool_size=conf["database"]["pool_size"]
      pool_timeout=conf["database"]["pool_timeout"]
      begin  
        @client = Mongo::MongoClient.new(address,port,:pool_size => pool_size,:pool_timeout => pool_timeout)
        @db=@client.db(dbName)
        @db.authenticate(user,password)
      rescue=>e
        p e
      end  
    end
    
    def create_index(collection,key)
      @db.collection(collection).create_index(key)
    end

    def create(collection,doc) 
      coll=@db.collection(collection)
      doc.delete("_id")
      coll.insert(doc)  
    end

    def retrieve(collection,selector)
      coll=@db.collection(collection)
      tmp=coll.find(selector).to_a.to_json
      doc=JSON.parse(tmp)
    end

    def find(collection,selector,sorter,max)
      coll=@db.collection(collection)
      tmp=coll.find(selector).sort(sorter).limit(max).to_a.to_json
      doc=JSON.parse(tmp)
    end

    def update(collection,selector,doc)
      coll=@db.collection(collection)
      doc.delete("_id")
      coll.update(selector,doc)
    end

    def delete(collection,selector)
      coll=@db.collection(collection)
      coll.remove(selector)
    end

    def list_all(collection)
      coll=@db.collection(collection)
      tmp=coll.find.to_a.to_json
      doc=JSON.parse(tmp)      
    end

    def remove_db_id(doc)
      doc.each do |x|
        x.delete("_id")
      end
      doc
    end

    def list_accounts()
      accounts=Array.new
      h=Hash.new
      @db.collections.each do |collection|
        prefix=collection.name.split('.').first
        if(prefix!='system' && !h.has_key?(prefix))
          accounts << prefix
          h[prefix]=true
        end
      end
      accounts
    end
    
    def upd_doc(new,current)
      new.each { |key,value|
        current[key]=value
      }   
    end   

  end
end

