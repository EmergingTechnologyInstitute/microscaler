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

require "rubygems"
require 'optparse'
require "json"
require "net/http"
require "fileutils"
require 'yaml'
require 'table_print'

HOME = File.join(Dir.home,".asg")
FileUtils.mkdir_p(HOME)
if(ENV['ASG_CLI_FILE']!=nil)
  CF_FILE=ENV['ASG_CLI_FILE']
else
  CF_FILE = File.join(HOME,'.default_config.yml')
end

options={}
optparse = OptionParser.new do|opt|
  opt.banner = "Usage: ms COMMAND [OPTIONS]"
  opt.separator  ""
  opt.separator  "Commands"
  opt.separator  "    load:            load defaults"
  opt.separator  "    login:           login"
  opt.separator  "    list-lbs:        list all load balancer"    
  opt.separator  "    add-lb:          add load balancer"
  opt.separator  "    update-lb:       update a load balancer"
  opt.separator  "    delete-lb:       delete load balancer"
  opt.separator  "    list-lconfs:     list all launch configurations"    
  opt.separator  "    add-lconf:       add launch configuration"
  opt.separator  "    update-lconf:    update launch configuration"
  opt.separator  "    delete-lconf:    delete launch configuration"
  opt.separator  "    list-asgs:       list all autoscaling groups"    
  opt.separator  "    add-asg:         add new autoscaling group"
  opt.separator  "    update-asg:      update autoscaling group"
  opt.separator  "    delete-asg:      delete autoscaling group"
  opt.separator  "    start-asg:       start autoscaling group"
  opt.separator  "    stop-asg:        stop autoscaling group" 
  opt.separator  "    list-instances:  list instances for an autoscaling group" 
  opt.separator  "    list-instance-types  list available instance types" 
  opt.separator  "    list-policies:   list all policies"  
  opt.separator  "    update-policies: update all policies"    
  opt.separator  "    add-policy:      add new policy"
  opt.separator  "    delete-policy:   delete autoscaling group"  
  opt.separator  ""
  opt.separator  "Options"

  #opt.on( '-a', '--asg NAME','ASG name' ) do |a|
  #  options[:an] = a
  #end

  opt.on( '-f', '--file FILE','[load] defaults file (yaml)' ) do |f|
    options[:f] = f
  end

  opt.on( '-t', '--target URL','[login] ASG API URL' ) do |t|
    options[:t] = t
  end

  opt.on( '-u', '--user USER','[login] user' ) do |u|
    options[:u] = u
  end

  opt.on( '-k', '--key KEY','[login]  API key' ) do |k|
    options[:k] = k
  end

  opt.on('-b','--lb-name NAME','[add/upd-lb/delete-lb] load balancer name' ) do |ln|
    options[:ln] = ln
  end

  opt.on('--lb-instances-port NAME','[add/upd-lb] instances port' ) do |ip|
      options[:ip] = ip
  end
 
# options below are commented since they cannot be set with shared LB   
=begin  
  opt.on('--lb-port NAME','[add/upd-lb] load balancer port' ) do |lp|
    options[:lp] = lp
  end
    
  opt.on('--lb-availability-zones NAME','[add/upd-lb] availability zones' ) do |az|
    options[:az] = az
  end

  opt.on('--lb-protocol NAME','[add/upd-lb] protocol' ) do |lp|
    options[:lp] = lp
  end
=end 
   
  opt.on('-c','--lconf-name NAME','[add/upd-lconf/delete-lconf] launch configuration name' ) do |lc|
    options[:lc] = lc
  end
  
  opt.on('--lconf-image-id NAME','[add/upd-lconf] image id' ) do |iid|
    options[:iid] = iid
  end
  
  opt.on('--lconf-instances-type NAME','[add/upd-lconf] instance type e.g. m1.small' ) do |it|
    options[:it] = it
  end
  
  opt.on('--lconf-key KEY','[add/upd-lconf] ssh image key' ) do |ik|
    options[:ik] = ik
  end
  
  opt.on('--lconf-metadata META','[add/upd-lconf] metadata in JSON format - e.g. \'{"test":"val"}\' ' ) do |im|
      options[:im] = im
  end

  opt.on('-a','--asg-name NAME','[add/delete/upd//start/stop-asg/list-instances] autoscaling group name' ) do |an|
    options[:an] = an
  end
  
  opt.on('--asg-availability-zones AZS','[add/upd-asg] autoscaling group availability zones (e.g. docker01,docker02)' ) do |az|
    options[:az] = az
  end 
  
  opt.on('--asg-launch-configuration N','[add/upd-asg] autoscaling group launch configuration' ) do |lc|
     options[:lc] = lc
  end 
  
  opt.on('--asg-min-size NUM',Integer,'[add/upd-asg] autoscaling group min size' ) do |min|
    options[:min] = min
  end 
  
  opt.on('--asg-max-size NUM',Integer,'[add/upd-asg] autoscaling group max size' ) do |max|
    options[:max] = max
  end 
  
  opt.on('--asg-desired-capacity NUM',Integer,'[add/upd-asg] autoscaling group desired capacity' ) do |dc|
     options[:dc] = dc
  end 
  
  opt.on('--asg-scale-out-cooldown NUM',Integer,'[add/upd-asg] autoscaling group scale out cooldown' ) do |soc|
    options[:soc] = soc
  end 

  opt.on('--asg-scale-in-cooldown NUM',Integer,'[add/upd-asg] autoscaling group scale in cooldown' ) do |sic|
    options[:sic] = sic
  end 
  
  opt.on('--asg-load-balancer NAME','[add/upd-asg] autoscaling group load balancer' ) do |lb|
    options[:lb] = lb
  end 
  
  options[:nolb]=false
  opt.on('-x','--asg-no-load-balancer','[add/upd-asg] autoscaling group load balancer' ) do 
      options[:nolb] = true
  end 
  
  opt.on('--asg-domain NAME','[add/upd-asg] autoscaling group ip domain' ) do |d|
    options[:d] = d
  end
     
  opt.on('-p','--policy-name NAME','[add/upd-policy/delete-policy] policyname' ) do |pn|
    options[:pn] = pn
  end
  
  opt.on('--policy-asg NAME','[add/upd-policy] autoscaling group name for this policy' ) do |an|
    options[:an] = an
  end
  
  opt.on('--policy-metric NAME','[add/upd-policy] metric for this policy(e.g. CPU)' ) do |m|
    options[:m] = m
  end  
  
  opt.on('--policy-statistic NAME','[add/upd-policy] statistic type for this policy(e.g. AVG)' ) do |st|
    options[:st] = st
  end    
  
  opt.on('--policy-sampling-window NU',Integer,'[add/upd-policy] sampling window for this policy(in seconds)' ) do |sw|
    options[:sw] = sw
  end      
  
  opt.on('--policy-breach-duration NU',Integer,'[add/upd-policy] breach duration for this policy(in seconds)' ) do |bd|
    options[:bd] = bd
  end   
  
  opt.on('--policy-scale-out-step NUM',Integer,'[add/upd-policy] scale-out step for this policy(e.g. 1)' ) do |sos|
    options[:sos] = sos
  end      
  
  opt.on('--policy-scale-in-step NUM',Integer,'[add/upd-policy] scale-in step for this policy(e.g. -1)' ) do |sis|
    options[:sis] = sis
  end    
  
  opt.on('--policy-upper-threshold NU',Integer,'[add/upd-policy] upper threshold for this policy' ) do |ut|
    options[:ut] = ut
  end    
  
  opt.on('--policy-lower-threshold NU',Integer,'[add/upd-policy] lower threshold for this policy' ) do |lt|
     options[:lt] = lt
  end   
  
  options[:dl]=false
  opt.on('--detailed-list',Integer,'[list-*] list with all details' ) do 
     options[:dl] = true
  end            
    
  opt.on_tail( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end

end

optparse.parse!

class RestClient
  def initialize(url)
    @base_url=url
  end

  def post(path,payload,headers)
    url=URI.parse(@base_url+path)
    req = Net::HTTP::Post.new(url.path, initheader = upd_header(headers))
    req.body = payload.to_json
    response= Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
  end

  def put(path,payload,headers)
    url=URI.parse(@base_url+path)

    req = Net::HTTP::Put.new(url.path, initheader = upd_header(headers))
    req.body = payload.to_json
    response= Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
  end

  def get(path,headers)
    url=URI.parse(@base_url+path)

    req = Net::HTTP::Get.new(url.path, initheader = upd_header(headers))
    response= Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
  end

  def delete(path,headers)
    url=URI.parse(@base_url+path)

    req = Net::HTTP::Delete.new(url.path, initheader = upd_header(headers))
    response= Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
  end

  private

  # add json header to supplied headers
  def upd_header(headers)
    hdr={'Content-Type' =>'application/json'}
    if(headers!=nil)
      headers['Content-Type']='application/json'
      hdr=headers
    end
    hdr
  end
end

class AsgCli
  def load(options)
    conf=YAML.load_file("#{options[:f]}")
    File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
  end
  
  def new_conf
    conf=Hash.new
    tokfile=YAML.load_file(CF_FILE)
    conf['login']=Hash.new
    conf['login']['token']=tokfile['login']['token']
    conf['login']['target']=tokfile['login']['target']  
    conf  
  end            

  def login(options)
    if(options[:u]==nil || options[:k]==nil || options[:t]==nil)
      p "Some options not provided, loading missing options from defaults..."
      if(!File.file?(CF_FILE))
        p "File defaults not loaded, please load defaults or provide all options"
        exit -1
      end
      conf=YAML.load_file(CF_FILE)
    else
      if(!File.file?(CF_FILE))
        conf={'login'=>{},'load_balancer'=>{},'launch_configuration'=>{},'autoscaling_group'=>{},'policy'=>{}}   
      else
        conf=YAML.load_file(CF_FILE)       
      end
    end  
    if(options[:u]!=nil)
      conf['login']['user']=options[:u]
    end
    if(options[:k]!=nil)
      conf['login']['key']=options[:k]
    end
    if(options[:t]!=nil)
      conf['login']['target']=options[:t]
    end
    rest=RestClient.new(conf['login']['target'])
    p "logging in @#{conf['login']['target']} user=#{conf['login']['user']} key=***** ..."
    result=rest.post('/login',{"user"=>conf['login']['user'],"key"=>conf['login']['key']},nil)
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p 'OK'
    conf['login']['token']=JSON.parse(result.body)['token']
    File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
  end

  def add_lb(options,upd)
    #if(options[:ln]==nil || options[:lp]==nil || options[:ip]==nil || options[:az]==nil || options[:lp]==nil)
    if(options[:ip]==nil)
      p "Some options not provided, loading missing options from defaults..."
    end
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    if (!upd)
      conf=YAML.load_file(CF_FILE)
    else
      conf=new_conf
      conf['load_balancer']=Hash.new
    end    
    if(options[:ln]==nil)
      p 'You must provide -b (--lb-name)'
      exit -1
    end
    conf['load_balancer']['name']=options[:ln]    
    if(options[:ip]!=nil)
      conf['load_balancer']['instances_port']=options[:ip]
    end
=begin  
    if(options[:lp]!=nil)
      conf['load_balancer']['lb_port']=options[:lp]
    end    
    if(options[:az]!=nil)
      conf['load_balancer']['availability_zones']=options[:az].split(",")
    end
    if(options[:lp]!=nil)
      conf['load_balancer']['protocol']=options[:lp]
    end
=end
    # CURRENTLY CAN ONLY USE THESE VALUES
    conf['load_balancer']['lb_port']=80
    conf['load_balancer']['availability_zones']=['docker02']
    conf['load_balancer']['protocol']='HTTP'  
    conf['load_balancer']['options']=["headers"]      
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    #File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
    rest=RestClient.new(conf['login']['target'])
    if(!upd)  
      p "adding load balancer #{conf['load_balancer']} ..."
      result = rest.post('/lbs',conf['load_balancer'], {"authorization"=>conf['login']['token']} )
    else
      p "updating load balancer #{conf['load_balancer']} ..."
      result = rest.put("/lbs/#{conf['load_balancer']['name']}",conf['load_balancer'], {"authorization"=>conf['login']['token']} )
    end      
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p 'OK'
  end

  def list_lbs(options)
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    conf=YAML.load_file(CF_FILE)
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    rest=RestClient.new(conf['login']['target'])
    result = rest.get("/lbs", {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    js=JSON.parse(result.body)
    tp js
  end
  
  def delete_lb(options)
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    conf=YAML.load_file(CF_FILE)
    if(options[:ln]==nil)
       p 'You must provide -b (--lb-name)'
       exit -1
    end
    conf['load_balancer']['name']=options[:ln]
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
    rest=RestClient.new(conf['login']['target'])
    p "deleting load balancer #{conf['load_balancer']['name']} ..."
    result = rest.delete("/lbs/#{conf['load_balancer']['name']}", {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p 'OK'
  end
  
  def add_lconf(options,upd)
    if(options[:iid]==nil || options[:it]==nil || options[:ik]==nil)
      p "Some options not provided, loading missing options from defaults..."
    end
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    if (!upd)
      conf=YAML.load_file(CF_FILE)
    else
      conf=new_conf
      conf['launch_configuration']=Hash.new
    end    
    if(options[:lc]==nil)
       p 'You must provide -c (--lconf-name)'
       exit -1
    end    
    conf['launch_configuration']['name']=options[:lc]
    if(options[:iid]!=nil)
      conf['launch_configuration']['image_id']=options[:iid]
    end
    if(options[:it]!=nil)
      conf['launch_configuration']['instances_type']=options[:it]
    end
    if(options[:ik]!=nil)
      conf['launch_configuration']['key']=options[:ik]
    end
    if(options[:im]!=nil)
      conf['launch_configuration']['metadata']=JSON.parse(options[:im])
    end

    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    #File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
    rest=RestClient.new(conf['login']['target'])
    if(!upd)  
      p "adding launch configuration #{conf['launch_configuration']} ..."
      result = rest.post('/lconfs',conf['launch_configuration'], {"authorization"=>conf['login']['token']} )
    else
      p "updating launch configuration #{conf['launch_configuration']} ..."
      result = rest.put("/lconfs/#{conf['launch_configuration']['name']}",conf['launch_configuration'], {"authorization"=>conf['login']['token']} )
    end  
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p 'OK'
  end
  
  def list_lconfs(options)
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    conf=YAML.load_file(CF_FILE)
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    rest=RestClient.new(conf['login']['target'])
    result = rest.get("/lconfs", {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    js=JSON.parse(result.body)
    # format metadata as string to print it
    js.each do |l| 
      if(l['metadata']!=nil)
        l['metadata']=l['metadata'].to_json
      else
        l['metadata']='N/A'    
      end  
    end  
    tp js, :name, {:image_id=>{:width=>48}},:instances_type, :key, {:metadata=>{:width=>48}} 
  end

  def delete_lconf(options)
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    conf=YAML.load_file(CF_FILE)
    if(options[:lc]==nil)
       p 'You must provide -c (--lconf-name)'
       exit -1
    end    
    conf['launch_configuration']['name']=options[:lc]
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
    rest=RestClient.new(conf['login']['target'])
    p "deleting launch configuration #{conf['launch_configuration']['name']} ..."
    result = rest.delete("/lconfs/#{conf['launch_configuration']['name']}", {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p 'OK'
  end

  def add_asg(options,upd)
    if(options[:az]==nil || options[:lc]==nil || options[:min]==nil || options[:max]==nil || 
      options[:soc]==nil || options[:sic]==nil || options[:lb]==nil || options[:d]==nil)
      p "Some options not provided, loading missing options from defaults..."
    end
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    if (!upd)
      conf=YAML.load_file(CF_FILE)
    else
      conf=new_conf
      p conf
      conf['autoscaling_group']=Hash.new
    end   
    if(options[:an]==nil)
      p 'You must provide -a (--asg-name)'
      exit -1
    end     
    conf['autoscaling_group']['name']=options[:an]
    if(options[:az]!=nil)
      conf['autoscaling_group']['availability_zones']=options[:az].split(",")
    end
    if(options[:lc]!=nil)
      conf['autoscaling_group']['launch_configuration']=options[:lc]
    end    
    if(options[:min]!=nil)
      conf['autoscaling_group']['min_size']=options[:min]
    end
    if(options[:max]!=nil)
      conf['autoscaling_group']['max_size']=options[:max]
    end
    if(options[:dc]!=nil)
      conf['autoscaling_group']['desired_capacity']=options[:dc]
    end
    if(options[:soc]!=nil)
      conf['autoscaling_group']['scale_out_cooldown']=options[:soc]
    end
    if(options[:sic]!=nil)
      conf['autoscaling_group']['scale_in_cooldown']=options[:sic]
    end
    if(options[:lb]!=nil)
       conf['autoscaling_group']['load_balancer']=options[:lb]
    end
    if(options[:nolb])
      conf['autoscaling_group']['no_lb']=true
    end
    if(options[:d]!=nil)
      conf['autoscaling_group']['domain']=options[:d]
    end   
                   
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    p conf['autoscaling_group']['name']
    p conf['autoscaling_group']  
    
    #File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
    rest=RestClient.new(conf['login']['target'])
    if(!upd)
      p "adding autoscaling group #{conf['autoscaling_group']} ..."
      result = rest.post('/asgs',conf['autoscaling_group'], {"authorization"=>conf['login']['token']} )
    else
      p "updating autoscaling group #{conf['autoscaling_group']} ..."
      result = rest.put("/asgs/#{conf['autoscaling_group']['name']}",conf['autoscaling_group'], {"authorization"=>conf['login']['token']} )
    end  
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p 'OK'
  end

  def list_asgs(options)
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    conf=YAML.load_file(CF_FILE)
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    rest=RestClient.new(conf['login']['target'])
    result = rest.get("/asgs", {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    js=JSON.parse(result.body)
    if(options[:dl])
      tp js
    else
      tp js,:name,:state,:availability_zones,{:url =>{:width => 48}},:min_size,:max_size,:desired_capacity,:launch_configuration
    end  
  end
  
  def delete_asg(options)
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    conf=YAML.load_file(CF_FILE)
    if(options[:an]==nil)
      p 'You must provide -a (--asg-name)'
      exit -1
    end    
    conf['autoscaling_group']['name']=options[:an]
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
    rest=RestClient.new(conf['login']['target'])
    p "deleting autoscaling group #{conf['autoscaling_group']['name']} ..."
    result = rest.delete("/asgs/#{conf['autoscaling_group']['name']}", {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p 'OK'
  end    
  
  def run_asg_command(options,command)
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    if(options[:an]==nil)
      p 'You must provide -a (--asg-name)'
      exit -1
    end    
    conf=YAML.load_file(CF_FILE)
    conf['autoscaling_group']['name']=options[:an]
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    #File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
    rest=RestClient.new(conf['login']['target'])
    p "running #{command} autoscaling group for #{conf['autoscaling_group']['name']} ..."
    result = rest.put("/asgs/#{conf['autoscaling_group']['name']}/#{command}",nil, {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p 'OK'
  end    
  
  def list_instances(options)
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    conf=YAML.load_file(CF_FILE)
    if(options[:an]==nil)
      p 'You must provide -a (--asg-name)'
      exit -1
    end    
    conf['autoscaling_group']['name']=options[:an]
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    rest=RestClient.new(conf['login']['target'])
    result = rest.get("/asgs/#{conf['autoscaling_group']['name']}/instances", {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p "listing instances for autoscaling group: #{conf['autoscaling_group']['name']}"
    js=JSON.parse(result.body)
    if(options[:dl])
      tp js
    else
      tp js,:instance_id,:status,:availability_zone,:private_ip_address,{:hostname =>{:width=>48}}
    end      
  end
  
  def list_instance_types(options) 
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    conf=YAML.load_file(CF_FILE) 
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    rest=RestClient.new(conf['login']['target'])
    result = rest.get("/instance_types", {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p "listing available instances types"
    js=JSON.parse(result.body)
    array=Array.new
    js.each { |key, value| 
      value['type']=key
      array << value  
    }
    tp array, :type, :vcpu, :memory              
  end
  
  def add_policy(options,upd)
    if(options[:an]==nil || options[:m]==nil || options[:st]==nil || options[:sw]==nil || 
      options[:bd]==nil || options[:sos]==nil || options[:sis]==nil || options[:ut]==nil || options[:lt]==nil)
      p "Some options not provided, loading missing options from defaults..."
    end
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    if (!upd)
       conf=YAML.load_file(CF_FILE)
    else
      conf=new_conf
      conf['policy']=Hash.new
    end   
    if(options[:pn]==nil)
      p 'You must provide -p (--policy-name)'
      exit -1
    end     
    conf['policy']['name']=options[:pn]
    if(options[:an]!=nil)
      conf['policy']['auto_scaling_group']=options[:an]
    end
    if(options[:m]!=nil)
      conf['policy']['metric']=options[:m]
    end    
    if(options[:st]!=nil)
      conf['policy']['statistic']=options[:st]
    end
    if(options[:sw]!=nil)
      conf['policy']['sampling_window']=options[:sw]
    end
    if(options[:bd]!=nil)
      conf['policy']['breach_duration']=options[:bd]
    end
    if(options[:sos]!=nil)
      conf['policy']['scale_out_step']=options[:sos]
    end
    if(options[:sis]!=nil)
      conf['policy']['scale_in_step']=options[:sis]
    end
    if(options[:ut]!=nil)
      conf['policy']['upper_threshold']=options[:ut]
    end   
    if(options[:lt]!=nil)
      conf['policy']['lower_threshold']=options[:lt]
    end   
                       
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
    rest=RestClient.new(conf['login']['target'])
    if(!upd)  
      p "adding policy#{conf['policy']} ..."
      result = rest.post('/policies',conf['policy'], {"authorization"=>conf['login']['token']} )
    else 
      p "updating policy#{conf['policy']} ..."
      result = rest.put("/policies/#{conf['policy']['name']}",conf['policy'], {"authorization"=>conf['login']['token']} )
    end     
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p 'OK'
  end

  def list_policies(options)
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    conf=YAML.load_file(CF_FILE)
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    rest=RestClient.new(conf['login']['target'])
    result = rest.get("/policies", {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    js=JSON.parse(result.body)
    if(options[:dl])
      tp js
    else
      tp js,:name,:auto_scaling_group,:metric,:statistic,:upper_threshold,:lower_threshold
    end   
  end

  def delete_policy(options)
    if(!File.file?(CF_FILE))
      p "File defaults not loaded, please load defaults or login first"
      exit -1
    end
    conf=YAML.load_file(CF_FILE)
    if(options[:pn]==nil)
      p 'You must provide -p (--policy-name)'
      exit -1
    end     
    conf['policy']['name']=options[:pn]
    if(conf['login']['token']==nil)
      p 'Please login before running this command'
      exit -1
    end
    File.open(CF_FILE, 'w') {|f| f.write conf.to_yaml }
    rest=RestClient.new(conf['login']['target'])
    p "deleting policy#{conf['policy']['name']} ..."
    result = rest.delete("/policies/#{conf['policy']['name']}", {"authorization"=>conf['login']['token']} )
    if(result.code!='200')
      p 'error: ' + result.body
      exit -1
    end
    p 'OK'
  end
  
end

cli=AsgCli.new

case ARGV[0]
when "load"
  puts "loading options from #{options[:f]}"
  cli.load(options)
when "login"
  cli.login(options)
when "add-lb"
  cli.add_lb(options,false)
when "update-lb"
  cli.add_lb(options,true)  
when "delete-lb"
  cli.delete_lb(options)
when "list-lbs"
  cli.list_lbs(options)  
when "add-lconf"
  cli.add_lconf(options,false)
when "update-lconf"
  cli.add_lconf(options,true)   
when "delete-lconf"
  cli.delete_lconf(options)
when "list-lconfs"
  cli.list_lconfs(options)    
when "add-asg"
  cli.add_asg(options,false)
when "update-asg"
  cli.add_asg(options,true)  
when "delete-asg"
  cli.delete_asg(options)
when "list-asgs"
  cli.list_asgs(options)    
when "start-asg"
  cli.run_asg_command(options,'start')      
when "stop-asg"
  cli.run_asg_command(options,'stop')   
when "list-instances"
  cli.list_instances(options)     
when "list-instance-types"
  cli.list_instance_types(options)            
when "add-policy"
  cli.add_policy(options,false)
when "update-policy"
  cli.add_policy(options,true)  
when "delete-policy"
  cli.delete_policy(options)
when "list-policies"
  cli.list_policies(options)        
else
  puts optparse
end
