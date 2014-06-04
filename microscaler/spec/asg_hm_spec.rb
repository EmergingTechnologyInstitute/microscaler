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
# Autoscaling Groups Manager Tests
#---------------------------------------------------
describe ASG::ASGManager do

  before :all do
    sleep(2)
    @home=File.dirname(__FILE__)
    @dbm=ASG::DbManager.new
    conf=YAML.load_file("#{@home}/../conf/microscaler.yml")
    im_db=conf["database"]["im_db"]
    im_user=conf["database"]["im_user"]
    im_password=conf["database"]["im_password"]
    asg_db=conf["database"]["asg_db"]
    asg_user=conf["database"]["asg_user"]
    asg_password=conf["database"]["asg_password"]

    dbm=ASG::DbManager.new
    dbm.drop_db(im_db)
    dbm.drop_db(asg_db)
    dbm.create_db(im_db,im_user,im_password)
    dbm.create_db(asg_db,asg_user,asg_password)

    `/usr/bin/supervisorctl stop healthmanager`
    `/usr/bin/supervisorctl restart agent worker-launch worker-stop`

    @lbm=ASG::LbManager.new
    @lcm=ASG::LConfManager.new
    @im=ASG::InstanceManager.new
    @am=ASG::AuthManager.new
    @asgm=ASG::ASGManager.new(@am,@lbm,@lcm,@im)
    @hm=ASG::HealthManager.new
    @client=ASG::ClientFactory.create(USER,KEY)

    # populate data for the lb, lc and auth
    @am.login(USER,KEY)
    @lbm.create_lb(USER,LB_DOC)
    @lcm.create_lconf(USER,LCONF_DOC)

    # start HM in a separate thread since it is blocking
    @th=Thread.new{@hm.run()}
  end

  describe "#new" do
    it "takes 3 parameters and returns a asg  manager object" do
      @asgm.should be_an_instance_of ASG::ASGManager
    end
  end

  describe "#create" do
    it "creates a new asg" do
      @asgm.create_asg(USER,ASG_DOC)
      doc=@asgm.retrieve_asg(USER,"myasg")
      doc["max_size"].should_not eql nil
    end
  end

  describe "#start_asg" do
    it "starts a new asg & checks that one instance is registered" do
      @asgm.start_asg(USER,"myasg")
      # wait since this is an async process
      n=0
      len=-1
      while true do
        if(@hm.get_map.has_key?(USER+"."+ASG_NAME))
          len=@hm.get_map[USER+"."+ASG_NAME][0].length
        end
        n+=1
        if(len==1 || n>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      @hm.get_map[USER+"."+ASG_NAME][0].length.should eql 1
      x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},nil,100)
      x.length.should eql 1
      x[0]["status"].should eql RUNNING_STATE
      $id=x[0]["instance_id"]
    end
  end
  
  describe "#check_HM_updater_stale_instance" do
    it "checks that one killed instance is removed from HM registry and IM" do
      # kill instance without knowledge of IM
      @client.delete_container($id)
      # wait for updater to change state
      n=0
      len=-1
      while true do
        if(@hm.get_map.has_key?(USER+"."+ASG_NAME))
          len=@hm.get_map[USER+"."+ASG_NAME][0].length
        end
        n+=1
        if(len==0 || n>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER,"instance_id"=>$id},nil,100)
      x.length.should eql 1
      x[0]["status"].should eql NOT_RUNNING_STATE
      @hm.get_map[USER+"."+ASG_NAME][0].length.should eql 0
    end
  end

  describe "#check_reconciler_reconcile_killing_1" do
    it "checks that one instance is restarted after killing one" do
      # wait for reconciler to do its job
      n=0
      len=-1
      while true do
        if(@hm.get_map.has_key?(USER+"."+ASG_NAME))
          len=@hm.get_map[USER+"."+ASG_NAME][0].length
        end
        x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},nil,100)
        n+=1
        if(len==1 && x.length==1 || n>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      @hm.get_map[USER+"."+ASG_NAME][0].length.should eql 1
      x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},nil,100)
      x.length.should eql 1
      x[0]["status"].should eql RUNNING_STATE
    end
  end

  describe "#check_reconciler_reconcile_extra_1" do
    it "checks that one instance is stopped after starting extra one outside ASG manager" do
      lock=@im.lease_lock(USER,ASG_NAME,START_TYPE_LEASE,1)
      @im.launch_instance(USER,KEY,ASG_NAME,TYPE_CONTAINER,TEST_HOST,TEST_DOMAIN,TEST_CPUS,TEST_MEM,TEST_AZ,TEST_IMAGE_ID,true,lock,nil)
      # wait for reconciler to do its job
      n=0
      len=-1
      while true do
        if(@hm.get_map.has_key?(USER+"."+ASG_NAME))
          len=@hm.get_map[USER+"."+ASG_NAME][0].length
        end
        n+=1
        if(len==1 || n>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      @hm.get_map[USER+"."+ASG_NAME][0].length.should eql 1
    end
  end

  describe "#check_update_desired_capacity" do
    it "checks changing the ASG target number of instances" do
      asg_spec=@asgm.retrieve_asg(USER,ASG_NAME)
      p asg_spec
      asg_spec['desired_capacity']=3
      @asgm.update_asg(USER,ASG_NAME,asg_spec)
      # wait since this is an async process
      n=0
      len=-1
      while true do
        if(@hm.get_map.has_key?(USER+"."+ASG_NAME))
          len=@hm.get_map[USER+"."+ASG_NAME][0].length
        end
        n+=1
        if(len==3 || n>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      @hm.get_map[USER+"."+ASG_NAME][0].length.should eql 3
      x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},nil,100)
        p x
      sleep(INTERVAL)
      x.length.should eql 3
      len.should eql 3
      x[0]["status"].should eql RUNNING_STATE
      x[1]["status"].should eql RUNNING_STATE
      x[2]["status"].should eql RUNNING_STATE
      $id1=x[0]["instance_id"]
      $id2=x[1]["instance_id"]
      $id3=x[2]["instance_id"]
    end
  end

  describe "#check_reconciler_reconcile_killing_3" do
    it "checks that all instances are restarted after killing 3" do
      @client.delete_container($id1)
      @client.delete_container($id2)
      @client.delete_container($id3)
      n=0
      len=-1
      while true do
        if(@hm.get_map.has_key?(USER+"."+ASG_NAME))
          len=@hm.get_map[USER+"."+ASG_NAME][0].length
        end
        n+=1
        if(len<3 || n>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      p "killed some instances..."
      # wait for reconciler to do its job
      n=0
      len=-1
      sleep(2)
      while true do
        if(@hm.get_map.has_key?(USER+"."+ASG_NAME))
          len=@hm.get_map[USER+"."+ASG_NAME][0].length
        end
        x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},nil,100)
        n+=1
        #p " starting ? ---> #{@im.instances_starting?(USER,ASG_NAME,TYPE_CONTAINER)} len=#{len} x.length=#{x.length}  "
        if(len==3 && x.length==3 && !@im.instances_starting?(USER,ASG_NAME,TYPE_CONTAINER) || n>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      @hm.get_map[USER+"."+ASG_NAME][0].length.should eql 3
      x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},nil,100)
      x.length.should eql 3
      x[0]["status"].should eql RUNNING_STATE
      x[1]["status"].should eql RUNNING_STATE
      x[2]["status"].should eql RUNNING_STATE
    end
  end

  describe "#stop_asg" do
    it "stops a asg" do
      @asgm.stop_asg(USER,"myasg")
      # wait since this is an async process
      n=0
      len=-1
      while true do
        if(@hm.get_map.has_key?(USER+"."+ASG_NAME))
          len=@hm.get_map[USER+"."+ASG_NAME][0].length
        end
        n+=1
        if(len==0 || n>MAX_TIME/INTERVAL )
          break
        end
        sleep(INTERVAL)
      end
      @hm.get_map[USER+"."+ASG_NAME][0].length.should eql 0
      x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},nil,100)
      x.length.should eql 0
    end
  end
 
  after :all do
    @th.terminate
    x=@im.query_instances(USER,{"name"=>ASG_NAME,"type"=>TYPE_CONTAINER},nil,100)
    if(x.length>0)
      lock=@im.lease_lock(USER,ASG_NAME,STOP_TYPE_LEASE,x.length)
      x.each do |instance|
        @im.stop_instance(USER,KEY,ASG_NAME,TYPE_CONTAINER,lock)        
      end
    end
  end
end
