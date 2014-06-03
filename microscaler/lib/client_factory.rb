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
require "#{File.dirname(__FILE__)}/docker_client.rb"

module ASG
  class ClientFactory
    
    def self.create(user,key) 
      @home=File.dirname(__FILE__)
      conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")
      driver=conf["driver"]
      if(driver=='docker')
        url=conf['docker']['daemon_url']
        dns=conf['docker']['container_dns']
        dns_search=conf['docker']['container_dns_search']
        return ASG::DockerClient.new(user,key,url,dns,dns_search)
      else
        raise "driver must be one of 'docker'"
      end
    end
  end  
end

