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

require 'spec_helper'
require 'test_data'
require "json"

['TERM', 'INT'].each { |sig| trap(sig) { exit! } }


REST_URL="http://localhost:56785/asgcc"
#---------------------------------------------------
# ASG REST API tests
#---------------------------------------------------
describe ASG::RestClient do

  before :all do
     @home=File.dirname(__FILE__)
     @conf=YAML.load_file("#{@home}/../conf/microscaler.yml")
     im_db=@conf["database"]["im_db"]
     asg_db=@conf["database"]["asg_db"]
     @as_auth_token=@conf["autoscaler"]["authorization_token"]
     im_user=@conf["database"]["im_user"]
     im_password=@conf["database"]["im_password"]
     asg_user=@conf["database"]["asg_user"]
     asg_password=@conf["database"]["asg_password"]
     dbm=ASG::DbManager.new
     dbm.drop_db(im_db)
     dbm.drop_db(asg_db)
     dbm.create_db(im_db,im_user,im_password)
     dbm.create_db(asg_db,asg_user,asg_password)
     `/usr/bin/supervisorctl restart controller worker-launch worker-stop healthmanager agent`

    @rest=ASG::RestClient.new(REST_URL)
  end
 
#---------------------------------------------------
# Login tests
#---------------------------------------------------

  describe "#login" do
    it "logins with wrong creds" do
      result=@rest.post('/login',{"user"=>USER,"key"=>"WRONG_KEY"},nil)
      js = JSON.parse(result.body)
      result.code.should eql "500"
      js["status"].should eql "ERROR"
    end
  end

  describe "#login" do
    it "logins and gets token" do
      result=@rest.post('/login',{"user"=>USER,"key"=>KEY},nil)
      js = JSON.parse(result.body)
      result.code.should eql "200"
      js["status"].should eql "OK"
      $token=js["token"]
    end
  end

#---------------------------------------------------
# LB  tests
#---------------------------------------------------
  describe "#create_lb" do
    it "creates a new lb" do
      result=@rest.post('/lbs',LB_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
    end
  end

  describe "#retrieve_lb" do
    it "retrieves lb" do
      result=@rest.get("/lbs/#{LB_DOC["name"]}",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["name"].should eql LB_DOC["name"]
    end
  end

  describe "#update_lb" do
    it "updates lb" do
      result=@rest.put("/lbs/#{LB_DOC["name"]}",LB_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
    end
  end

  describe "#list_lbs" do
    it "lists lbs" do
      result=@rest.get("/lbs",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js.length.should eql 1
      js[0]["name"].should eql LB_DOC["name"]
    end
  end

   describe "#delete_lb" do
    it "deletes lb" do
      result=@rest.delete("/lbs/#{LB_DOC["name"]}",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
      result=@rest.get("/lbs/#{LB_DOC["name"]}",{"authorization"=>$token})
      result.code.should eql "500"
      js = JSON.parse(result.body)
      js["status"].should eql "ERROR"
      js["message"].should include("not found")
    end
  end
#---------------------------------------------------
# LC  tests
#---------------------------------------------------
  describe "#create_lc" do
    it "creates a new lc" do
      result=@rest.post('/lconfs',LCONF_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
    end
  end

  describe "#retrieve_lconf" do
    it "retrieves lconf" do
      result=@rest.get("/lconfs/#{LCONF_DOC["name"]}",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["name"].should eql LCONF_DOC["name"]
    end
  end

  describe "#update_lconf" do
    it "updates lconf" do
      result=@rest.put("/lconfs/#{LCONF_DOC["name"]}",LCONF_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
    end
  end

  describe "#list_lconfs" do
    it "lists lconfs" do
      result=@rest.get("/lconfs",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js.length.should eql 1
      js[0]["name"].should eql LCONF_DOC["name"]
    end
  end

   describe "#delete_lconf" do
    it "deletes lconf" do
      result=@rest.delete("/lconfs/#{LCONF_DOC["name"]}",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
      result=@rest.get("/lconfs/#{LCONF_DOC["name"]}",{"authorization"=>$token})
      result.code.should eql "500"
      js = JSON.parse(result.body)
      js["status"].should eql "ERROR"
      js["message"].should include("not found")
    end
  end
#---------------------------------------------------
# ASG  tests
#---------------------------------------------------
  describe "#create_asg" do
    it "creates a new asg" do
      result=@rest.post('/asgs',ASG_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
    end
  end

  describe "#retrieve_asg" do
    it "retrieves asg" do
      result=@rest.get("/asgs/#{ASG_DOC["name"]}",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["name"].should eql ASG_DOC["name"]
    end
  end

  describe "#update_asg" do
    it "updates asg" do
      result=@rest.put("/asgs/#{ASG_DOC["name"]}",ASG_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
    end
  end

  describe "#list_asgs" do
    it "lists asgs" do
      result=@rest.get("/asgs",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js.length.should eql 1
      js[0]["name"].should eql ASG_DOC["name"]
    end
  end

   describe "#delete_asg" do
    it "deletes asg" do
      result=@rest.delete("/asgs/#{ASG_DOC["name"]}",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
      result=@rest.get("/lbs/#{ASG_DOC["name"]}",{"authorization"=>$token})
      result.code.should eql "500"
      js = JSON.parse(result.body)
      js["status"].should eql "ERROR"
      js["message"].should include("not found")
    end
  end

#---------------------------------------------------
# Policy  tests
#---------------------------------------------------
=begin
  describe "#create_policy" do
    it "creates a new policy" do
      # need asg first
      result=@rest.post('/asgs',ASG_DOC,{"authorization"=>$token})
      result=@rest.post('/policies',POLICY_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
    end
  end

  describe "#retrieve_policy" do
    it "retrieves policy" do
      result=@rest.get("/policies/#{POLICY_DOC["name"]}",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["name"].should eql POLICY_DOC["name"]
    end
  end

  describe "#update_policy" do
    it "updates policy" do
      result=@rest.put("/policies/#{POLICY_DOC["name"]}",POLICY_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
    end
  end

  describe "#list_policies" do
    it "lists policies" do
      result=@rest.get("/policies",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js.length.should eql 1
      js[0]["name"].should eql POLICY_DOC["name"]
    end
  end

   describe "#delete_policy" do
    it "deletes policy" do
      result=@rest.delete("/policies/#{POLICY_DOC["name"]}",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"
      result=@rest.get("/policies/#{POLICY_DOC["name"]}",{"authorization"=>$token})
      result.code.should eql "500"
      js = JSON.parse(result.body)
      js["status"].should eql "ERROR"
      js["message"].should include("not found")
      # clean up asg
      @rest.delete("/asgs/#{ASG_DOC["name"]}",{"authorization"=>$token})
    end
  end
=end
#---------------------------------------------------
# AS API  tests
#---------------------------------------------------
 
  describe "#setup" do
    it "sets up for testing the AS API" do
      result=@rest.post('/lbs',LB_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"

      result=@rest.post('/lconfs',LCONF_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"

      result=@rest.post('/asgs',ASG_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"

      result=@rest.put("/asgs/#{ASG_NAME}/start",ASG_DOC,{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"

      #result=@rest.post('/policies',POLICY_DOC,{"authorization"=>$token})
      #js = JSON.parse(result.body)
      #if(result.code=="500")
      #  p js["message"]
      #end
      #result.code.should eql "200"
      #js["status"].should eql "OK"

      sleep(5)
    end
  end
  
  describe "#list_asgs" do
    it "lists asgs" do
      result=@rest.get("/#{USER}/asgs",{"authorization"=>@as_auth_token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js.length.should eql 1
      js[0]["name"].should eql ASG_DOC["name"]
    end
  end

  describe "#list_asgs_wrong_token" do
    it "lists asgs with wrong token" do
      result=@rest.get("/#{USER}/asgs",{"authorization"=>"wrong_token"})
      js = JSON.parse(result.body)
      result.code.should eql "500"
      js["status"].should eql "ERROR"
    end
  end

  describe "#list_instances" do
    it "lists instances for an asg" do    
      # wait until == 1
      k=0
      while true do
        result=@rest.get("/#{USER}/asgs/#{ASG_NAME}/instances",{"authorization"=>@as_auth_token})
        js = JSON.parse(result.body)
        if(result.code=="500")
          p js["message"]
        end
        k+=1
        if(js.length==1 || k>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      result.code.should eql "200"
      js.length.should eql 1
      js[0]["name"].should eql ASG_DOC["name"]
    end
  end
  
  describe "#check_started" do
    it "checks that the ASG is started" do
      result=@rest.get("/asgs/#{ASG_NAME}",{"authorization"=>$token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["state"].should eql ASG_STATE_STARTED
      js["name"].should eql ASG_DOC["name"]
    end
  end

  describe "#update_num_instances_scale_out" do
    it "update num instances for an asg scale out" do
      result=@rest.put("/#{USER}/asgs/#{ASG_NAME}/instances",{"n_instances"=>2},{"authorization"=>@as_auth_token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"

      # wait until == 2
      k=0
      while true do
        result=@rest.get("/#{USER}/asgs/#{ASG_NAME}/instances",{"authorization"=>@as_auth_token})
        js = JSON.parse(result.body)
        if(result.code=="500")
          p js["message"]
        end
        k+=1
        if(js.length==2 || k>MAX_TIME/INTERVAL )
                break
        end
        sleep(INTERVAL)
      end  
      result.code.should eql "200"
      js.length.should eql 2
      js[0]["name"].should eql ASG_DOC["name"]
    end
  end

  describe "#update_num_instances_scale_in" do
    it "update num instances for an asg scale in" do
      result=@rest.put("/#{USER}/asgs/#{ASG_NAME}/instances",{"n_instances"=>1},{"authorization"=>@as_auth_token})
      js = JSON.parse(result.body)
      if(result.code=="500")
        p js["message"]
      end
      result.code.should eql "200"
      js["status"].should eql "OK"

      # wait until == 1
      k=0
      while true do
        result=@rest.get("/#{USER}/asgs/#{ASG_NAME}/instances",{"authorization"=>@as_auth_token})
        js = JSON.parse(result.body)
        if(result.code=="500")
          p js["message"]
        end
        k+=1
        if(js.length==1 || k>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      result.code.should eql "200"
      js.length.should eql 1
      js[0]["name"].should eql ASG_DOC["name"]
    end
  end
=begin
  describe "#test_autoscaling_scale_out" do
    it "start load and check autoscaling is operating to scale out" do
      `#{@home}/../bin/start-load.sh`
      k=0
      while true do
        result=@rest.get("/#{USER}/asgs/#{ASG_NAME}/instances",{"authorization"=>@as_auth_token})
        js = JSON.parse(result.body)
        if(result.code=="500")
          p js["message"]
        end 
        k+=1
        #p "instances: #{js.length}"
        if(js.length==2 || k>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      js.length.should eql 2
    end
  end

  describe "#test_autoscaling_scale_in" do
    it "stop load and check autoscaling is operating to scale in" do
      `#{@home}/../bin/stop-load.sh`
      k=0
      while true do
        result=@rest.get("/#{USER}/asgs/#{ASG_NAME}/instances",{"authorization"=>@as_auth_token})
        js = JSON.parse(result.body)
        if(result.code=="500")
          p js["message"]
        end
        k+=1
        if(js.length==1 || k>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      js.length.should eql 1
    end
  end
=end
  after:all do
    result=@rest.put("/asgs/#{ASG_NAME}/stop",ASG_DOC,{"authorization"=>$token})
    sleep(10)  
    p result.body
  end
end
