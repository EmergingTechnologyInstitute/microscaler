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

module ASG

# manage DB connections and DB operations
  class DbManager
    MONGO_TIMEOUT=2

    def initialize
      home=File.dirname(__FILE__)
      conf=YAML.load_file("#{home}/../conf/microscaler.yml")
      address=conf["database"]["ip-address"]
      port=conf["database"]["port"]
      admin_user=conf["database"]["admin_user"]
      admin_password=conf["database"]["admin_password"]
      pool_size=conf["database"]["pool_size"]
      pool_timeout=conf["database"]["pool_timeout"]
      @client = Mongo::MongoClient.new(address,port,:pool_size => pool_size,:pool_timeout => pool_timeout)
      @db=@client.db("admin")
      @db.authenticate(admin_user,admin_password)    
    end

    def create_db(dbname,username, password)    
      @client.db(dbname).add_user(username, password)
    end

    def drop_db(dbname)
      @client.drop_database(dbname)
    end

    def add_user(dbname,username,password)
      create_db(dbname,username,password)
    end
    
    def remove_user(dbname,username)
      @client.db(dbname).remove_user(username)
    end
  end
end

