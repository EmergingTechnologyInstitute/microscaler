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

require 'logger'
require 'sinatra'
require 'webrick'
require 'webrick/https'
require 'json'
require 'uuidtools'
require "#{File.dirname(__FILE__)}/entity_manager"
require "#{File.dirname(__FILE__)}/db_manager"
require "#{File.dirname(__FILE__)}/lb_manager"
require "#{File.dirname(__FILE__)}/lconf_manager"
require "#{File.dirname(__FILE__)}/instance_manager"
require "#{File.dirname(__FILE__)}/asg_manager"
require "#{File.dirname(__FILE__)}/auth_manager"
require "#{File.dirname(__FILE__)}/policy_manager"
require "#{File.dirname(__FILE__)}/constants"

module ASG

class RestController < Sinatra::Base

configure do
# Don't log them. We'll do that ourself
    set :dump_errors, false
 
    # Don't capture any errors. Throw them up the stack
    set :raise_errors, false
 
    # Disable internal middleware for presenting errors
    # as useful HTML pages
    set :show_exceptions, false
end
  #----------------------------------------------
  # initialize properties &  components
  #----------------------------------------------


  conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
  im_db=conf["database"]["im_db"]
  im_user=conf["database"]["im_user"]
  im_password=conf["database"]["im_password"]
  asg_db=conf["database"]["asg_db"]
  asg_user=conf["database"]["asg_user"]
  asg_password=conf["database"]["asg_password"]
  as_auth_token=conf["autoscaler"]["authorization_token"]
  instance_types=conf["instance_types"]
  
  dbm=ASG::DbManager.new
  dbm.create_db(im_db,im_user,im_password)
  dbm.create_db(asg_db,asg_user,asg_password)
  
  lbm=ASG::LbManager.new
  lcm=ASG::LConfManager.new
  im=ASG::InstanceManager.new
  am=ASG::AuthManager.new
  asgm=ASG::ASGManager.new(am,lbm,lcm,im)
  tm=ASG::PolicyManager.new(asgm) 

  #----------------------------------------------------
  # Autentication
  # uses the user and key to validate account, if OK
  # creates mongo DB and provides token to user.
  #---------------------------------------------------
  post '/asgcc/login' do
    body = request.body.read
    begin
      json = JSON.parse(body)
      token=am.login(json["user"],json["key"])
      content_type :json
      status 200 
      {:status=>"OK",:token=>token}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  #----------------------------------------------------
  # LB Management
  #---------------------------------------------------
  
  # create new LB 
  post '/asgcc/lbs' do
    token=env["HTTP_AUTHORIZATION"]
    body = request.body.read
    L.debug("POST /asgcc/lbs - token: #{token}  #{body.inspect} ")
    begin
      doc = JSON.parse(body)
      creds=am.check_token(token)
      account=creds[1]
      lbm.create_lb(account,doc)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # retrieves LB 
  get '/asgcc/lbs/:lb_name' do
    token=env["HTTP_AUTHORIZATION"]
    lb_name=params[:lb_name]
    L.debug("GET /asgcc/lbs/:lb_name - token: #{token} #{lb_name} #{body.inspect} ")
    begin
      creds=am.check_token(token)
      account=creds[1]
      doc=lbm.retrieve_lb(account,lb_name)
      content_type :json
      status 200
      if(doc==nil)
        doc={"status"=>"ERROR","message"=>"entity with name #{lb_name} not found"}
      end
      doc.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # updates LB 
  put '/asgcc/lbs/:lb_name' do
    token=env["HTTP_AUTHORIZATION"]
    lb_name=params[:lb_name]
    body = request.body.read
    L.debug("PUT /asgcc/lbs/:lb_name - token: #{token} #{lb_name} #{body.inspect} ")
    begin
      doc = JSON.parse(body)
      creds=am.check_token(token)
      account=creds[1]
      lbm.update_lb(account,lb_name,doc)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # deletes LB
  delete '/asgcc/lbs/:lb_name' do
    token=env["HTTP_AUTHORIZATION"]
    lb_name=params[:lb_name]
    L.debug("DELETE /asgcc/lbs/:lb_name - token: #{token} #{lb_name} ")
    begin
      creds=am.check_token(token)
      account=creds[1]
      lbm.delete_lb(account,lb_name)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # list LBs
  get '/asgcc/lbs' do
    token=env["HTTP_AUTHORIZATION"]
    L.debug("GET /asgcc/lbs - token: #{token}")
    begin
      creds=am.check_token(token)
      account=creds[1]
      list=lbm.list_lbs(account)
      content_type :json
      status 200
      list.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  #----------------------------------------------------
  # Launch Configuration Management
  #---------------------------------------------------
  
  # create new LC
  post '/asgcc/lconfs' do
    token=env["HTTP_AUTHORIZATION"]
    body = request.body.read
    L.debug("POST /asgcc/lconfs - token: #{token}  #{body.inspect} ")
    begin
      doc = JSON.parse(body)
      creds=am.check_token(token)
      account=creds[1]
      lcm.create_lconf(account,doc)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # retrieves LC 
  get '/asgcc/lconfs/:lc_name' do
    token=env["HTTP_AUTHORIZATION"]
    lc_name=params[:lc_name]
    L.info("GET /asgcc/lconfs/:lc_name - token: #{token} #{lc_name} #{body.inspect} ")
    begin
      creds=am.check_token(token)
      account=creds[1]
      doc=lcm.retrieve_lconf(account,lc_name)
      content_type :json
      status 200
      doc.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # updates LC
  put '/asgcc/lconfs/:lc_name' do
    token=env["HTTP_AUTHORIZATION"]
    lc_name=params[:lc_name]
    body = request.body.read
    L.info("PUT /asgcc/lconfs/:lc_name - token: #{token} #{lc_name} #{body.inspect} ")
    begin
      doc = JSON.parse(body)
      creds=am.check_token(token)
      account=creds[1]
      lcm.update_lconf(account,lc_name,doc)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # deletes LC
  delete '/asgcc/lconfs/:lc_name' do
    token=env["HTTP_AUTHORIZATION"]
    lc_name=params[:lc_name]
    L.debug("DELETE /asgcc/lconfs/:lc_name - token: #{token} #{lc_name} ")
    begin
      creds=am.check_token(token)
      account=creds[1]
      lcm.delete_lconf(account,lc_name)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # list LCs
  get '/asgcc/lconfs' do
    token=env["HTTP_AUTHORIZATION"]
    L.debug("GET /asgcc/lconfs - token: #{token}")
    begin
      creds=am.check_token(token)
      account=creds[1]
      list=lcm.list_lconfs(account)
      content_type :json
      status 200
      list.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  #----------------------------------------------------
  # Autoscaling Groups Management
  #---------------------------------------------------
  
  # create new ASG
  post '/asgcc/asgs' do
    token=env["HTTP_AUTHORIZATION"]
    body = request.body.read
    L.debug("POST /asgcc/asgs - token: #{token}  #{body.inspect} ")
    begin
      doc = JSON.parse(body)
      creds=am.check_token(token)
      account=creds[1]
      asgm.create_asg(account,doc)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # starts/stops ASG 
  put '/asgcc/asgs/:asg_name/:command' do
    token=env["HTTP_AUTHORIZATION"]
    asg_name=params[:asg_name]
    command=params[:command]
    L.info("PUT /asgcc/asgs/:asg_name/:command - token: #{token} #{asg_name} ")
    begin
      if(!['start','stop'].include? command)
        raise "unsupported command #{command} - must be 'start' or 'stop'"
      end
      creds=am.check_token(token)
      account=creds[1]
      if(command=='start')
        asgm.start_asg(account,asg_name)
      elsif
        asgm.stop_asg(account,asg_name)
      end
      content_type :json
      status 200
      {"status"=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # retrieves ASG 
  get '/asgcc/asgs/:asg_name' do
    token=env["HTTP_AUTHORIZATION"]
    asg_name=params[:asg_name]
    L.info("GET /asgcc/asgs/:asg_name - token: #{token} #{asg_name} #{body.inspect} ")
    begin
      creds=am.check_token(token)
      account=creds[1]
      doc=asgm.retrieve_asg(account,asg_name)
      content_type :json
      status 200
      if(doc==nil)
        doc={"status"=>"ERROR","message"=>"entity with name #{asg_name} not found"}
      end
      doc.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # updates ASG
  put '/asgcc/asgs/:asg_name' do
    token=env["HTTP_AUTHORIZATION"]
    asg_name=params[:asg_name]
    body = request.body.read
    L.info("PUT /asgcc/asgs/:asg_name - token: #{token} #{asg_name} #{body.inspect} ")
    begin
      doc = JSON.parse(body)
      creds=am.check_token(token)
      account=creds[1]
      asgm.update_asg(account,asg_name,doc)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # deletes ASG
  delete '/asgcc/asgs/:asg_name' do
    token=env["HTTP_AUTHORIZATION"]
    asg_name=params[:asg_name]
    L.debug("DELETE /asgcc/asgs/:asg_name - token: #{token} #{asg_name} ")
    begin
      creds=am.check_token(token)
      account=creds[1]
      asgm.delete_asg(account,asg_name)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # list ASGs
  get '/asgcc/asgs' do
    token=env["HTTP_AUTHORIZATION"]
    L.debug("GET /asgcc/asgs - token: #{token}")
    begin
      creds=am.check_token(token)
      account=creds[1]
      list=asgm.list_asgs(account)
      content_type :json
      status 200
      list.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

# list instances for an ASG
  get '/asgcc/asgs/:asg_name/instances' do
    token=env["HTTP_AUTHORIZATION"]
    asg_name=params[:asg_name]
    body = request.body.read
    L.info("GET /asgcc/asgs/:asg_name/instances - token: #{token} #{asg_name} ")
    begin
      creds=am.check_token(token)
      account=creds[1]
      list=im.query_instances(account,{"name"=>asg_name,"type"=>TYPE_CONTAINER},nil,100)
      content_type :json
      status 200
      list.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end
  
  # list instances types
  get '/asgcc/instance_types' do
    token=env["HTTP_AUTHORIZATION"]
    L.debug("GET /asgcc/instance_types - token: #{token}")
    begin
      creds=am.check_token(token)
      account=creds[1]
      content_type :json
      status 200
      instance_types.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end
  #----------------------------------------------------
  # Policys Management
  #---------------------------------------------------
   
  # create new policy
  post '/asgcc/policies' do
    token=env["HTTP_AUTHORIZATION"]
    body = request.body.read
    L.debug("POST /asgcc/policies - token: #{token}  #{body.inspect} ")
    begin
      doc = JSON.parse(body)
      creds=am.check_token(token)
      account=creds[1]
      tm.create_policy(account,doc)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # retrieves policy
  get '/asgcc/policies/:t_name' do
    token=env["HTTP_AUTHORIZATION"]
    t_name=params[:t_name]
    L.info("GET /asgcc/policies/:t_name - token: #{token} #{t_name} #{body.inspect} ")
    begin
      creds=am.check_token(token)
      account=creds[1]
      doc=tm.retrieve_policy(account,t_name)
      content_type :json
      status 200
      if(doc==nil)
        doc={"status"=>"ERROR","message"=>"entity with name #{t_name} not found"}
      end
      doc.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # updates policy
  put '/asgcc/policies/:t_name' do
    token=env["HTTP_AUTHORIZATION"]
    t_name=params[:t_name]
    body = request.body.read
    L.info("PUT /asgcc/policies/:t_name - token: #{token} #{t_name} #{body.inspect} ")
    begin
      doc = JSON.parse(body)
      creds=am.check_token(token)
      account=creds[1]
      tm.update_policy(account,t_name,doc)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # deletes policy
  delete '/asgcc/policies/:t_name' do
    token=env["HTTP_AUTHORIZATION"]
    t_name=params[:t_name]
    L.debug("DELETE /asgcc/policies/:t_name - token: #{token} #{t_name} ")
    begin
      creds=am.check_token(token)
      account=creds[1]
      tm.delete_policy(account,t_name)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  # list policies
  get '/asgcc/policies' do
    token=env["HTTP_AUTHORIZATION"]
    L.debug("GET /asgcc/policies - token: #{token}")
    begin
      creds=am.check_token(token)
      account=creds[1]
      list=tm.list_policies(account)
      content_type :json
      status 200
      list.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  #----------------------------------------------------
  # Internals: AS=>ASGCC 
  #---------------------------------------------------
  get '/asgcc/:account/asgs' do
    token=env["HTTP_AUTHORIZATION"]
    begin
      if(token!=as_auth_token)
        raise "authorization error: invalid token"
      end
      account=params[:account]
      list=asgm.list_asgs(account)
      content_type :json
      status 200
      list.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  get '/asgcc/:account/asgs/:asg_name/instances' do
    token=env["HTTP_AUTHORIZATION"]
    begin
      if(token!=as_auth_token)
        raise "authorization error: invalid token"
      end
      account=params[:account]
      asg_name=params[:asg_name]
      list=im.query_instances(account,{"name"=>asg_name,"type"=>TYPE_CONTAINER},nil,100)
      content_type :json
      status 200
      list.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end

  put '/asgcc/:account/asgs/:asg_name/instances' do
    token=env["HTTP_AUTHORIZATION"]
    begin
      if(token!=as_auth_token)
        raise "authorization error: invalid token"
      end
      account=params[:account]
      asg_name=params[:asg_name]
      body = request.body.read
      doc=JSON.parse(body)
      n_instances=doc["n_instances"]
      key=am.get_credentials(account)
      # now update the target number of instances
      asg_def=asgm.retrieve_asg(account,asg_name)
      asg_def['desired_capacity']=n_instances
      asgm.update_asg(account,asg_name,asg_def)
      content_type :json
      status 200
      {:status=>"OK"}.to_json
    rescue=>e
      L.error(e.message)
      content_type :json
      status 500
      {"status"=>"ERROR","message"=>e.message}.to_json
    end
  end
end
end
