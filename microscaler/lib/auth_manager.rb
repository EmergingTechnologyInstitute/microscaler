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

require "uuidtools"
require "json"


module ASG
  class AuthManager
    TOK_COLLECTION="tokens"
    def initialize()
      home=File.dirname(__FILE__)
      conf=YAML.load_file("#{home}/../conf/microscaler.yml")
      @auth_db=conf["database"]["auth_db"]
      @auth_user=conf["database"]["auth_user"]
      @auth_password=conf["database"]["auth_password"]
      @token_expiration=conf["authorization"]["token_expiration"].to_i
      @dbm=ASG::DbManager.new()
      @adb=@dbm.create_db(@auth_db,@auth_user,@auth_password)
      @em=ASG::EntityManager.new(@auth_db,@auth_user,@auth_password)
      @em.create_index(TOK_COLLECTION,"user")
      @em.create_index(TOK_COLLECTION,"password")
      @em.create_index(TOK_COLLECTION,"token")
    end
    
    def login(user,password)
      client=ASG::ClientFactory.create(user,password)
      auth=client.check_credentials()
      if(auth["status"]=="OK")
        token=UUIDTools::UUID.random_create.to_s
        doc=@em.retrieve(TOK_COLLECTION,{"user"=>user,"password"=>password})
        db=user # set db name == user name
        if(doc.empty?)
          @em.create(TOK_COLLECTION,{"token"=>token,"db"=>db,"user"=>user,"password"=>password,"timestamp"=>Time.now.to_i})
          @dbm.create_db(db,user,password)
          else
          if(doc[0]["token"]==nil)
            doc[0]["token"]=token
          end
          doc[0]["timestamp"]=Time.now.to_i
          @em.remove_db_id(doc)
          @em.update(TOK_COLLECTION,{"user"=>user,"password"=>password},doc[0])
          token=doc[0]['token']
        end
        elsif (auth["status"]=="ERROR")
        raise auth["message"]
        else
        raise "Authentication Exception"
      end
      token
    end
    
    def check_token(token)
      doc=@em.retrieve(TOK_COLLECTION,{"token"=>token})
      if(doc.empty?)
        raise "Invalid token. Please login to acquire valid token"
        else
        timestamp=doc[0]["timestamp"]
        if(Time.now.to_i-timestamp>@token_expiration)
          # reset token & update
          doc[0]["token"]=nil
          @em.remove_db_id(doc)
          @em.update(TOK_COLLECTION,{"user"=>user=doc[0]["user"],"password"=>doc[0]["password"]},doc[0])
          raise "Token expired. Please login to acquire new token"
        end
        user=doc[0]["user"]
        db=doc[0]["db"]
        password=doc[0]["password"]
        # refresh token so that if it keeps being used it does not expire right away
        doc[0]["timestamp"]=Time.now.to_i
        @em.remove_db_id(doc)
        @em.update(TOK_COLLECTION,{"user"=>user,"password"=>password},doc[0])
      end
      return db,user,password
    end
    
    # this must be used only by the Health Manager to act on behalf
    # of a user and should not be exposed to the REST API
    def get_credentials(account)
      doc=@em.retrieve(TOK_COLLECTION,{"user"=>account})
      if(doc.empty?)
        raise "Account #{account} not found in auth DB"
      end
      doc[0]["password"]
    end
    
  end
end
