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

#---------------------------------------
# LB Schema
#---------------------------------------
$LB_SCHEMA = {
  "$schema"=> "http://json-schema.org/draft-04/schema#",
  "type" => "object",
  "required" => ["name","lb_port","instances_port","availability_zones"],
  "optional" => ["protocol","options"],
  "properties" => {
    "name" => {"type" => "string"},
    "lb_port" => {"type" => "int"},
    "instance_port" => {"type" => "int"},
    "availability_zones" => {"type" => "array"},
    "protocol" => {"type" => "string"},
    "options"  => {"type" => "array"}
  }
}

#---------------------------------------
# LCONF Schema
#---------------------------------------
$LCONF_SCHEMA = {
"$schema"=> "http://json-schema.org/draft-04/schema#",
"type" => "object",
"required" => ["name","image_id","instances_type","key"],
"properties" => {
  "name" => {"type" => "string"},
  "image_id" => {"type" => "string"},
  "instance_type" => {"type" => "string"},
  "key" => {"type" => "string"},
  "metadata"=> {"type"=>"object"}  
  }
}


#---------------------------------------
# ASG Schema
#---------------------------------------
ASG_SCHEMA = {
  "$schema"=> "http://json-schema.org/draft-04/schema#",
  "type" => "object",
  "required" => ["name","availability_zones","launch_configuration","min_size","max_size","scale_out_cooldown","scale_in_cooldown","desired_capacity","domain","state"],
  "properties" => {
    "name" => {"type" => "string"},
    "availability_zones" => {"type" => "array"},
    "launch_configuration" => {"type" => "string"},
    "min_size" => {"type" => "int"},
    "max_size" => {"type" => "int"},
    "scale_out_cooldown" => {"type" => "int"},
    "scale_in_cooldown" => {"type" => "int"},
    "load_balancer" => {"type" => "string"},
    "desired_capacity" => {"type" => "int"},
    "domain" => {"type" => "string"},
    "state" => {"type" => "string"},
    "url" => {"type" => "string"},
    "last_scale_out_ts"  => {"type" => "int"},
    "last_scale_in_ts"   => {"type" => "int"},
    "no_lb" => {"type" => "boolean"}             
  }
}

#---------------------------------------
# Policy Schema
#---------------------------------------
$POLICY_SCHEMA = {
  "$schema"=> "http://json-schema.org/draft-04/schema#",
  "type" => "object",
  "required" => ["name","auto_scaling_group","metric","statistic","sampling_window","breach_duration","scale_out_step","scale_in_step","upper_threshold","lower_threshold"],
  "properties" => {
    "name" => {"type" => "string"},
    "auto_scaling_group" => {"type" => "string"},
    "metric" => {"type" => "string"},
    "statistic" => {"type" => "string"},
    "sampling_window" => {"type" => "int"},
    "breach_duration" => {"type" => "int"},
    "scale_out_step" => {"type" => "int"},
    "scale_in_step" => {"type" => "int"},
    "upper_threshold" => {"type" => "int"},
    "lower_threshold" => {"type" => "int"},
  }
}

#---------------------------------------
# Instance Schema
#---------------------------------------
$INSTANCE_SCHEMA = {
  "$schema"=> "http://json-schema.org/draft-04/schema#",
  "type" => "object",
  "required" => ["guid","name","instance_id","type","status","private_ip_address","public_ip_address","hostname","domain","n_cpus","max_memory","availability_zone","image_id","hourly_billing","timestamp"],
  "properties" => {
    "guid" => {"type" => "string"},
    "name" => {"type" => "string"},
    "instance_id" => {"type" => "string"},
    "type" => {"type" => "string"},
    "status" => {"type" => "string"},
    "private_ip_address" => {"type" => "string"},
    "public_ip_address" => {"type" => "string"},
    "hostname" => {"type" => "string"},
    "domain" => {"type" => "string"},
    "n_cpus" => {"type" => "int"},
    "max_memory" => {"type" => "int"},
    "availability_zone" => {"type" => "string"},
    "image_id" => {"type" => "string"},
    "hourly_billing" => {"type" => "boolean"},
    "timestamp" => {"type" => "int"},
  }
}

