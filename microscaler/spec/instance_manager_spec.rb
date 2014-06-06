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


#---------------------------------------------------
# Instance Manager
#---------------------------------------------------
describe ASG::InstanceManager do

  before :all do
    @home=File.dirname(__FILE__)
    conf=YAML.load_file("#{@home}/../conf/microscaler.yml")
    `/usr/bin/supervisorctl restart worker-launch worker-stop`
    `/usr/bin/supervisorctl stop healthmanager`
    im_db=conf["database"]["im_db"]
    im_user=conf["database"]["im_user"]
    im_password=conf["database"]["im_password"]
    asg_db=conf["database"]["asg_db"]
    asg_user=conf["database"]["asg_user"]
    asg_password=conf["database"]["asg_password"]
    @client=ASG::ClientFactory.create(USER,KEY)
    @dbm=ASG::DbManager.new
    @dbm.drop_db(im_db)
    @dbm.create_db(im_db,im_user,im_password)
    @dbm.drop_db(asg_db)
    @dbm.create_db(asg_db,asg_user,asg_password)
    @im=ASG::InstanceManager.new()
  end

  describe "#new" do
    it "takes no parameters and returns an instance manager object" do
      @im.should be_an_instance_of ASG::InstanceManager
    end
  end
  
  describe "#create_or_update" do
    it "creates_or_updates a doc" do
      @im.create_or_update_instance(USER,LB_INSTANCE_DOC)
    end
  end
 
  describe "#create_or_update" do
    it "creates_or_updates a doc" do
      @im.create_or_update_instance(USER,INSTANCE_DOC)
    end
  end

  describe "#create_or_update" do
    it "updates a doc" do
      LB_INSTANCE_DOC["hostname"]="host4"
      @im.create_or_update_instance(USER,LB_INSTANCE_DOC)
      doc=@im.retrieve_instance(USER,ASG_NAME,"0",TYPE_LB)
      doc["hostname"].should eql "host4"
    end
  end
 
  describe "#create_or_update" do
    it "updates a doc" do
      INSTANCE_DOC["hostname"]="host5"
      @im.create_or_update_instance(USER,INSTANCE_DOC)
      doc=@im.retrieve_instance(USER,ASG_NAME,"0",TYPE_CONTAINER)
      doc["hostname"].should eql "host5"
    end
  end
  
  describe "#create" do
    it "tries to insert a doc with missing parameters" do
      expect {@im.create_or_update_instance(USER,DOC_WRONG)}.to raise_error
    end
  end

  describe "#retrieve" do
    it "retrieves a doc" do
      @im.retrieve_instance(USER,ASG_NAME,"0",TYPE_CONTAINER).should_not be_nil
    end
  end

  describe "#retrieve" do
    it "retrieves a doc" do
      @im.retrieve_instance(USER,ASG_NAME,"0",TYPE_LB).should_not be_nil
    end
  end

  describe "#list_instances" do
    it "list all instance instances for a asg" do
      @im.list_instances(USER,ASG_NAME,TYPE_CONTAINER).should_not be_empty
    end
  end

  describe "#list_instances" do
    it "list all lb instances for a asg" do
      @im.list_instances(USER,ASG_NAME,TYPE_LB).should_not be_empty
    end
  end

  describe "#delete_instance" do
    it "deletes a doc" do
      @im.delete_instance(USER,ASG_NAME,"0",TYPE_CONTAINER)
      expect {@im.retrieve_instance(USER,ASG_NAME,"0",TYPE_CONTAINER)}.to raise_error
    end
  end
 
  describe "#delete_instance" do
    it "deletes a doc" do
      @im.delete_instance(USER,ASG_NAME,"0",TYPE_LB)
      expect {@im.retrieve_instance(USER,ASG_NAME,"0",TYPE_LB)}.to raise_error
    end
  end

  describe "#query" do
    it "query and sort instances by ts" do
      @im.create_or_update_instance(USER,INSTANCE_DOC)
      INSTANCE_DOC2["instance_id"]="1"
      @im.create_or_update_instance(USER,INSTANCE_DOC2)
      @im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},{"timestamp"=>1},1).length().should eql 1
      x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},{"timestamp"=>1},2)
      x.length().should eql 2
      x[0]["timestamp"].should eql 1000
      # clean up
      @im.delete_instance(USER,ASG_NAME,"0",TYPE_CONTAINER)
      @im.delete_instance(USER,ASG_NAME,"1",TYPE_CONTAINER)
    end
  end
  
  describe "launch_instance" do
    it "launches an instance" do
      lock=@im.lease_lock(USER,ASG_NAME,START_TYPE_LEASE,1)
      @im.launch_instance(USER,KEY,ASG_NAME,TYPE_CONTAINER,TEST_HOST,TEST_DOMAIN,TEST_CPUS,TEST_MEM,TEST_AZ,TEST_IMAGE_ID,true,lock,TEST_DATA)
      sleep(15) # wait since this is an async process
      x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},{"timestamp"=>1},100)
      $id=x[0]["instance_id"]
      p "started instance id=#{$id}"  
      x.length().should eql 1
    end
  end

 describe "stop_instance" do
    it "stops an instance" do
      lock=@im.lease_lock(USER,ASG_NAME,STOP_TYPE_LEASE,1)
      @im.stop_instance(USER,KEY,ASG_NAME,TYPE_CONTAINER,lock)
      # wait since this is an async process
      n=0
      while true do
        status= @client.check_container_status($id)
        n+=1
        if(status["status"]=="RECLAIM_NETWORK" || n>MAX_TIME/INTERVAL || status["status"]=="ERROR" )
          break
        end
        sleep(INTERVAL)
      end
      x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},{"timestamp"=>1},100)
      x.length().should eql 0
      # it is async, should wait to complete before db is dropped
    end
  end
  
  describe "update_num_instance" do
    it "updates an instance count to set an absolute num of instances" do
      lock=@im.lease_lock(USER,ASG_NAME,START_TYPE_LEASE,1)
      @im.launch_instance(USER,KEY,ASG_NAME,TYPE_CONTAINER,TEST_HOST,TEST_DOMAIN,TEST_CPUS,TEST_MEM,TEST_AZ,TEST_IMAGE_ID,true,lock,TEST_DATA)
      n=0
      while true do
        x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},{"timestamp"=>1},100)
        n+=1
        if(x.length==1 || n>MAX_TIME/INTERVAL )
           break
        end
        sleep(INTERVAL)
      end
      x.length().should eql 1
      @im.update_num_instances(USER,KEY,ASG_NAME,TYPE_CONTAINER,3,['docker01','docker02'],TEST_TEMPLATE)
      n=0
      while true do
        x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},{"timestamp"=>1},100)
        n+=1
        if(x.length==3 || n>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      x.length().should eql 3
      @im.update_num_instances(USER,KEY,ASG_NAME,TYPE_CONTAINER,1,['docker01','docker02'],TEST_TEMPLATE)
      while true do
        x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},{"timestamp"=>1},100)
        n+=1
        if(x.length==1 || n>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      x.length().should eql 1
    end
  end

  after :all do
    x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},nil,100)
    if(x.length>0)
      lock=@im.lease_lock(USER,ASG_NAME,START_TYPE_LEASE,x.length)
      x.each do |instance|        
          @im.stop_instance(USER,KEY,ASG_NAME,TYPE_CONTAINER,lock)        
      end
    end
  end
end

