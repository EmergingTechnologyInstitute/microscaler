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

require 'json'
require "#{File.dirname(__FILE__)}/constants"
require "#{File.dirname(__FILE__)}/rest_client"

#
# Invokes the docker daemon using the Docker remote REST API to start, stop and check
# the status of containers
#
module ASG
  
  class DockerClient
    def initialize(user,key,url,dns,dns_search)
      @user=user
      @key=key
      @rest=ASG::RestClient.new(url)
      @dns=dns
      @dns_search=dns_search
      home=File.dirname(__FILE__)
      @conf=YAML.load_file("#{home}/../conf/microscaler.yml")
    end

    def check_credentials
      auth=false
      if @conf['auth'][@user]==@key
        auth=true
      else
        error_message=  "check_credentials: invalid account #{@user} or invalid key"
      end  
      if(auth)
        {"status"=>"OK"}
      else
        {"status"=>"ERROR","message"=>error_message}
      end
    end

    def launch_container(hostname,domain,n_cpus,max_memory,availability_zone,image_id,hourly_billing,user_data)
      # The tag 'az_name' is used as a kind of "tag" for emulating Availability Zone.
      user_data['az_name'] = availability_zone 
      # template to create a container
      template={
        "Hostname"=>hostname,
        "Domainname"=>domain,
        "User"=>"",
        "Memory"=>max_memory*1024*1024, # memory is in bytes for docker, while it is in MB for us
        "MemorySwap"=>0,
        "AttachStdin"=>false,
        "AttachStdout"=>false,
        "AttachStderr"=>false,
        "PortSpecs"=>nil,
        "Tty"=>true,
        "OpenStdin"=>false,
        "StdinOnce"=>false,
        "Env"=>('user_data=' + user_data.to_json),
        "Cmd"=>nil,
        "Dns"=>@dns, # This is for Docker 0.9 or earlier
        "Image"=>image_id,
        "Volumes"=>{},
        "VolumesFrom"=>"",
        "WorkingDir"=>"",
        "ExposedPorts"=>{},
        "Entrypoint"=>nil,
        "NetworkDisabled"=>false,
        "OnBuild"=>nil
      }
      # settings for running the container
      start_settings={
        "Binds"=>nil,
        "ContainerIDFile"=>"",
        "LxcConf"=>[],
        "Privileged"=>false,
        "PortBindings"=>{},
        "Links"=>nil,
        "PublishAllPorts"=>true,
        "Dns"=>@dns,
        "DnsSearch"=>@dns_search
      }
      begin
        # create the docker container
        result=@rest.post("/containers/create?name=#{hostname}",template,{"Availability-Zone" => availability_zone})
        if(result.code!="201")
          raise result.body
        end
        id=JSON.parse(result.body)['Id'][0..11] # container ID (first 12 chars)
        # launch the docker container 
        result=@rest.post("/containers/#{id}/start",start_settings,{"Availability-Zone" => availability_zone})
        if(result.code!="204")
          raise result.body
        end
        {"status"=>"OK","id"=>id}
        rescue =>e
          error_message = "Could not create & launch Docker container: #{e.message}"
          {"status"=>"ERROR","message"=>error_message}
      end
    end

    def check_container_status(id)
      begin
        result=@rest.get("/v1.10/containers/#{id}/json",{})
        if(result.code=="200")
          js=JSON.parse(result.body)
          state=js['State']['Running']
          private_ip = js['NetworkSettings']['IPAddress'] # ?
          public_ip=''
          if(state)
            status=RUNNING_STATE
          else
            status=NOT_RUNNING_STATE
          end
        elsif(result.code=="404") # it is possible that container is still waiting to be launched by resque workers or it was stopped and deleted but we cannot distinguish, we consider it removed
          status=SHUTDOWN_STATES[2]
        else
          raise result.body
        end
        {"status"=>status,"public_ip"=>public_ip,"private_ip"=>private_ip}
      rescue =>e
        error_message = "check_container_status: #{e}"
        {"status"=>"ERROR","message"=>error_message}
      end
    end

    def delete_container(id)
      begin
        # stop the container
        result=@rest.post("/v1.10/containers/#{id}/stop?t=5",{},{})
        if(result.code!="204")
          raise "Error stopping the container: #{result.code} :  #{result.body}"
        end
        
        # remove the container and the volumes
        result=@rest.delete("/containers/#{id}?v=true",{})
        if(result.code!="204")
          raise "Error deleting the container: #{result.code} :  #{result.body}"
        end
        {"status"=>"OK"}
      rescue =>e
        error_message = "delete_container: #{e}"
        {"status"=>"ERROR","message"=>error_message}
      end
    end
  end 
end

