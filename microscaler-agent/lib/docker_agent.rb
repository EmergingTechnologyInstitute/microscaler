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

require "yaml"
require "json"
require "nats/client"
require "logger"
require "#{File.dirname(__FILE__)}/rest_client"

# logger settings
L = Logger.new(STDERR)
L.level = Logger::DEBUG

module ASG
  class DockerAgent
    def initialize()
      conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/agent.yml")
      @pollers_interval=conf["agent"]["poller_interval"]
      @nats_url=conf['agent']['nats']
      @nats_subject=conf['agent']['nats_subject']
      daemon_url=conf['docker']['daemon_url']
      @rest=ASG::RestClient.new(daemon_url)
    end

    def run
      NATS.on_error { |err| puts "Server Error: #{err}"; exit! }
      NATS.start(:uri => @nats_url, :autostart => true) do
        setup_pollers
      end
    end
    
    def setup_pollers
      EM.add_periodic_timer(@pollers_interval) {
        poller
      }
    end

    def poller
      begin
        p 'start pollers'
        result=@rest.get("/v1.10/containers/json",{})
        if(result.code=="200")
          list=JSON.parse(result.body)
            list.each do |c|
              id=c['Id']
              result=@rest.get("/v1.10/containers/#{id}/json",{})
              if(result.code=="200")
                info=JSON.parse(result.body)
                #p info
                env= info['Config']['Env']
                i=env.index {|x| x.match /user_data/}
                if(i!=nil)
                   host = info['NetworkSettings']['IPAddress']
                   data=JSON.parse(env[i].split('=')[1])               
                   port=data['local_http_port']
                   asg_name=data['asg_name']
                   domain=data['domain']
                   account=data['account']
                   instance_id=id[0..11] # container ID (first 12 chars)
                   msg=build_hb_message(host,port,asg_name,domain,account,instance_id)
                   L.debug "publishing #{msg}"
                   NATS.publish(@nats_subject, msg)
                end
              end
            end
        end
      rescue=>e
        p e
      end
    end

  private
  # does not compute CPU/Memory for the time being....
  def build_hb_message(host,port,asg_name,domain,account,instance_id)
    timestamp=(Time.now.to_f * 1000.0).to_i    # ts should be in ms
    metrics={:account=>account,:appId=>asg_name, :instanceID=>instance_id,:timestamp=>timestamp,:entryList=>[{:name=>"METRIC_CPU",:value=>0},{:name=>"METRIC_CPU_DEMAND",:value=>0},{:name=>"METRIC_CPU_NUM",:value=>1},{:name=>"METRIC_MEM",:value=>0},{:name=>"METRIC_MEM_FREE",:value=>0}]}
    hb={:host=>host,:port=>port.to_i,:uris=>["#{asg_name}.#{domain}"],:tags=>{:metrics=>metrics}}
    hb.to_json
  end
  end
end

