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

require "json"
require "net/http"

module ASG
#--------------------------------------------------------
#   Rest Client
#--------------------------------------------------------
  class RestClient
    def initialize(url)
      @base_url=url
    end

    def post(path,payload,headers)
      url=URI.parse(@base_url+path)
      url_path=url.path
      if(url.query!=nil)
        url_path=url.path+"?"+url.query
      end
      req = Net::HTTP::Post.new(url_path, initheader = upd_header(headers))
      req.body = payload.to_json
      response= Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
    end

    def put(path,payload,headers)
      url=URI.parse(@base_url+path)
      url_path=url.path
      if(url.query!=nil)
        url_path=url.path+"?"+url.query
      end
      req = Net::HTTP::Put.new(url_path, initheader = upd_header(headers))
      req.body = payload.to_json
      response= Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
    end

    def get(path,headers)
      url=URI.parse(@base_url+path)
      url_path=url.path
      if(url.query!=nil)
        url_path=url.path+"?"+url.query
      end
      req = Net::HTTP::Get.new(url_path, initheader = upd_header(headers))
      response= Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
    end

    def delete(path,headers)
      url=URI.parse(@base_url+path)
      url_path=url.path
      if(url.query!=nil)
        url_path=url.path+"?"+url.query
      end
      req = Net::HTTP::Delete.new(url_path, initheader = upd_header(headers))     
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

end
