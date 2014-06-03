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


#--------------------------------------------------
#  DbManager
#--------------------------------------------------
describe ASG::DbManager do

  before :each do
    @dbm=ASG::DbManager.new
  end

  describe "#create_db" do
    it "creates a db" do
      @dbm.create_db(TEST_DB,TEST_USER,TEST_PASS).should_not be_nil
    end
  end  

  describe "#drop_db" do
    it "drops the db" do
      @dbm.drop_db(TEST_DB).should_not be_nil
    end
  end
end

#---------------------------------------------------
# Entity Manager
#---------------------------------------------------
describe ASG::EntityManager do

  before :all do
    @dbm=ASG::DbManager.new
    @dbm.create_db(TEST_DB,TEST_USER,TEST_PASS)
    @em=ASG::EntityManager.new(TEST_DB,TEST_USER,TEST_PASS)
    @em.create_index(TEST_COLL,"id")
  end

  describe "#new" do
    it "takes 3 parameters and returns a entity manager object" do
      @em.should be_an_instance_of ASG::EntityManager
    end
  end
  
  describe "#create" do
    it "creates a doc" do
      @em.create(TEST_COLL,TEST_DOC)
    end
  end

  describe "#retrieve" do
    it "retrieves a doc" do
      @em.retrieve(TEST_COLL,{"id"=>"1234"}).should_not be_nil
    end
  end

  describe "#list_all" do
    it "list all docs in a collection" do
      @em.list_all(TEST_COLL).should_not be_empty
    end
  end

  describe "#update" do
    it "updates a doc" do
      @em.update(TEST_COLL,{"id"=>"1234"},TEST_DOC2)
    end
  end

  describe "#delete" do
    it "deletes a doc" do
      @em.delete(TEST_COLL,{"id"=>"1234"})
      @em.retrieve(TEST_COLL,{"id"=>"1234"}).should be_empty
    end
  end

  describe "#list_accounts" do
    it "list accounts" do
      @em.list_accounts.length.should eql 1
    end
  end

  after :all do
    @dbm.drop_db(TEST_DB)
  end
end
#---------------------------------------------------
# LOAD BALANCER Manager
#---------------------------------------------------
describe ASG::LbManager do

  before :all do
    @dbm=ASG::DbManager.new
    conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
    @asg_db=conf["database"]["asg_db"]
    @asg_user=conf["database"]["asg_user"]
    @asg_password=conf["database"]["asg_password"]
    @dbm.drop_db(@asg_db)
    @dbm.create_db(@asg_db,@asg_user,@asg_password)
    @lbm=ASG::LbManager.new
  end

  describe "#new" do
    it "takes 3 parameters and returns a lb manager object" do
      @lbm.should be_an_instance_of ASG::LbManager
    end
  end
  
  describe "#create" do
    it "creates a doc" do
      @lbm.create_lb(USER,LB_DOC)
    end
  end

  describe "#create" do
    it "tries to create a duplicate lb" do
      expect {@lbm.create_lb(USER,LB_DOC)}.to raise_error
    end
  end

  describe "#create" do
    it "tries to insert a doc with missing parameters" do
      expect {@lbm.create_lb(USER,DOC_WRONG)}.to raise_error
    end
  end

  describe "#retrieve" do
    it "retrieves a doc" do
      @lbm.retrieve_lb(USER,"mylb").should_not be_nil
    end
  end

  describe "#list_all" do
    it "list all docs in a collection" do
      @lbm.list_lbs(USER).should_not be_empty
    end
  end

  describe "#update" do
    it "updates a doc" do
      @lbm.update_lb(USER,"mylb",LB_DOC2)
      doc=@lbm.retrieve_lb(USER,"mylb")
      doc["instances_port"].should eql 8083
    end
  end

  describe "#delete" do
    it "deletes a doc" do
      @lbm.delete_lb(USER,"mylb")
      expect {@lbm.retrieve_lb(USER,"mylb")}.to raise_error
    end
  end

  after :all do
    @dbm.drop_db(@asg_db)
  end

end

#---------------------------------------------------
# Launch Configuration Manager
#---------------------------------------------------
describe ASG::LConfManager do

  before :all do
    @dbm=ASG::DbManager.new
    conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
    @asg_db=conf["database"]["asg_db"]
    @asg_user=conf["database"]["asg_user"]
    @asg_password=conf["database"]["asg_password"]
    @dbm.create_db(@asg_db,@asg_user,@asg_password)
    @lcm=ASG::LConfManager.new
  end

  describe "#new" do
    it "takes 3 parameters and returns a lconf manager object" do
      @lcm.should be_an_instance_of ASG::LConfManager
    end
  end
  
  describe "#create" do
    it "creates a doc" do
      @lcm.create_lconf(USER,LCONF_DOC)
    end
  end

  describe "#create" do
    it "tries to create a duplicate lconf" do
      expect {@lcm.create_lconf(USER,LCONF_DOC)}.to raise_error
    end
  end

  describe "#create" do
    it "tries to insert a doc with missing parameters" do
      expect {@lcm.create_lconf(USER,DOC_WRONG)}.to raise_error
    end
  end

  describe "#retrieve" do
    it "retrieves a doc" do
      @lcm.retrieve_lconf(USER,"mylconf").should_not be_nil
    end
  end

  describe "#list_all" do
    it "list all docs in a collection" do
      @lcm.list_lconfs(USER).should_not be_empty
    end
  end

  describe "#update" do
    it "updates a doc" do
      @lcm.update_lconf(USER,"mylconf",LCONF_DOC2)
      doc=@lcm.retrieve_lconf(USER,"mylconf")
      doc["instances_type"].should eql "m1.medium"
    end
  end

  describe "#delete" do
    it "deletes a doc" do
      @lcm.delete_lconf(USER,"mylconf")
      expect {@lcm.retrieve_lconf(USER,"mylconf")}.to raise_error
    end
  end

  after :all do
    @dbm.drop_db(@asg_db)
  end

end
#---------------------------------------------------
# Autoscaling Groups Manager
#---------------------------------------------------
describe ASG::ASGManager do

  before :all do
    @dbm=ASG::DbManager.new
    conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
    @asg_db=conf["database"]["asg_db"]
    @asg_user=conf["database"]["asg_user"]
    @asg_password=conf["database"]["asg_password"]
    @dbm.create_db(@asg_db,@asg_user,@asg_password)
    @asgm=ASG::ASGManager.new(nil,nil,nil,nil)
  end

  describe "#new" do
    it "takes 3 parameters and returns a asg  manager object" do
      @asgm.should be_an_instance_of ASG::ASGManager
    end
  end
  
  describe "#create" do
    it "creates a doc" do
      @asgm.create_asg(USER,ASG_DOC)
    end
  end

  describe "#create" do
    it "tries to create a duplicate asg" do
      expect {@asgm.create_asg(USER,ASG_DOC)}.to raise_error
    end
  end

  describe "#create" do
    it "tries to insert a doc with missing parameters" do
      expect {@asgm.create_asg(USER,DOC_WRONG)}.to raise_error
    end
  end

  describe "#retrieve" do
    it "retrieves a doc" do
      @asgm.retrieve_asg(USER,"myasg").should_not be_nil
    end
  end

  describe "#list_all" do
    it "list all docs in a collection" do
      @asgm.list_asgs(USER).should_not be_empty
    end
  end

  describe "#update" do
    it "updates a doc" do
      @asgm.update_asg(USER,"myasg",ASG_DOC2)
      doc=@asgm.retrieve_asg(USER,"myasg")
      doc["max_size"].should eql 5
    end
  end

  describe "#delete" do
    it "deletes a doc" do
      @asgm.delete_asg(USER,"myasg")
      expect {@asgm.retrieve_asg(USER,"myasg")}.to raise_error
    end
  end

  after :all do
    @dbm.drop_db(@asg_db)
  end

end

#---------------------------------------------------
# Authentication  Manager
#---------------------------------------------------
describe ASG::AuthManager do

  before :all do
    @dbm=ASG::DbManager.new
    @am=ASG::AuthManager.new
  end

  describe "#new" do
    it "takes no parameters and returns an auth manager object" do
      @am.should be_an_instance_of ASG::AuthManager
    end
  end

  describe "#login" do
    it "logins and returns a token" do
      $token=@am.login(USER,KEY)
    end
  end

  describe "#check_token" do
    it "check token and gets user db info" do
      values=@am.check_token($token)
      values[0].should eql USER
      values[1].should eql USER
      values[2].should eql KEY
    end
  end
 
  describe "#login" do
    it "repeats logins and returns a token" do
      $token=@am.login(USER,KEY)
    end
  end

  describe "#check_token" do
    it "repeats check token and gets user db info" do
      values=@am.check_token($token)
      values[0].should eql USER
      values[1].should eql USER
      values[2].should eql KEY
    end
  end

  describe "#get_credentials" do
    it "gets credentials from account" do
      @am.get_credentials(USER).should eql KEY
    end
  end

 describe "#login" do
    it "attempts login with wrong credential and gets exception" do
      expect {@am.login(WRONG_USER,KEY)}.to raise_error
    end
  end

 after :all do
    @dbm.drop_db(USER)
    @dbm.drop_db("authdb")
  end

end

