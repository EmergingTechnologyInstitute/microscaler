#!/usr/bin/env ruby
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

require "#{File.dirname(__FILE__)}/../lib/rest_controller.rb"

# capture CTRL-C to close
['TERM', 'INT'].each { |sig| trap(sig) { exit! } }


conf=YAML.load_file("#{File.dirname(__FILE__)}/../conf/microscaler.yml")

webrick_options = 
{
  :Port            => conf['controller']['port'],
  :SSLEnable       => conf['controller']['ssl'],
}

# start server
Rack::Handler::WEBrick.run ASG::RestController, webrick_options
