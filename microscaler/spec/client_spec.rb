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

['TERM', 'INT'].each { |sig| trap(sig) { exit! } }

USER_DATA={'nats_url'=>'http://locahost:4222','nats_subject'=>'router.register','eth_interface'=>'eth1','local_http_port'=>'8080','asg_name'=>ASG_NAME,'account'=>USER,'sample_interval'=>15,'domain'=>TEST_DOMAIN}

#--------------------------------------------------
#  Client
#--------------------------------------------------
describe ASG::ClientFactory do

  before :all do
     @client=ASG::ClientFactory.create(USER,KEY)
    @wrong=ASG::ClientFactory.create(WRONG_USER,KEY)
  end

  describe "#check_credentials" do
    it "checks credentials" do
       @client.check_credentials()["status"].should eql "OK"
    end
  end  

  describe "#check_credentials" do
    it "checks credentials for wrong ID" do
      @wrong.check_credentials()["status"].should eql "ERROR"
    end
  end 
  
  describe "launch_container" do
    it "launches an instance from a template image" do
      result= @client.launch_container(TEST_HOST,TEST_DOMAIN,TEST_CPUS,512,TEST_AZ,TEST_IMAGE_ID,HOURLY_INSTANCE,USER_DATA)
      result["id"].should_not be_nil
      $id=result["id"]
      result["status"].should eql "OK"
    end
  end

  describe "#check_container_status" do
    n=0
    it "checks an instance status after a create" do
      while true do
        status= @client.check_container_status($id)
        p status
        n+=1
        if(status["status"]=="RUNNING" || n>MAX_TIME/INTERVAL)
          break
        end
        sleep(INTERVAL)
      end
    end
  end
  
describe "#delete_container" do
    WRONG_ID="1234"
    it "deletes an instance with wrong ID" do
        @client.delete_container(WRONG_ID)["status"].should eql "ERROR"
    end
  end

  describe "#delete_container" do
    it "deletes an instance with correct ID" do
      status =  @client.delete_container($id)["status"]  
      status.should eql "OK"
    end
  end
  
  describe "#check_container_status" do
    n=0
    it "checks instance status after a delete" do
      while true do
        status= @client.check_container_status($id)
        p status
        n+=1
        if(status["status"]=="RECLAIM_NETWORK" || n>MAX_TIME/INTERVAL || status["status"]=="ERROR" )
          break
        end
        sleep(INTERVAL)
      end
    end
  end
end
   


