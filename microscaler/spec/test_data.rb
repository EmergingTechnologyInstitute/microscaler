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

# test data

TEST_DB="IBM123"
TEST_USER="user01"
TEST_PASS="key"
TEST_DOC={"id"=>"1234","value1"=>"val1","value2"=>"val2"}
TEST_DOC2={"id"=>"1234","value1"=>"val3","value2"=>"val4"}
TEST_COLL="IBM123.mycollection"

USER="user01"
WRONG_USER="user100"
KEY="key"


TEST_AZ='docker01'
ASG_NAME='myasg'
#TEST_IMAGE_ID='acmeair/asg-agent'
TEST_IMAGE_ID='cirros'
TEST_HOST='docker_host'
TEST_DOMAIN='mydomain.com'
TEST_CPUS=1
TEST_MEM=1024
HOURLY_INSTANCE=true
TEST_DATA={"test"=>'some_data'}

LB_DOC={"name"=>"mylb","lb_port"=>80,"instances_port"=>8082,"availability_zones"=>["A1"],"protocol"=>"HTTP","options"=>["headers"]}
LB_DOC2={"name"=>"mylb","lb_port"=>80,"instances_port"=>8083,"availability_zones"=>["A3"],"protocol"=>"HTTP","options"=>["headers"]}
DOC_WRONG={"name"=>"x"}

LCONF_DOC={"name"=>"mylconf","image_id"=>"#{TEST_IMAGE_ID}","instances_type"=>"m1.small","key"=>"keypair"}
LCONF_DOC2={"name"=>"mylconf","image_id"=>"#{TEST_IMAGE_ID}","instances_type"=>"m1.medium","key"=>"keypair"}

ASG_DOC={"name"=>"myasg","availability_zones"=>["docker01","docker02"],"launch_configuration"=>"mylconf","min_size"=>1,"max_size"=>4,"desired_capacity"=>1,"scale_out_cooldown"=>60,"scale_in_cooldown"=>60,"load_balancer"=>"mylb","domain"=>"research.ibm.com"}
ASG_DOC2={"name"=>"myasg","availability_zones"=>["docker01","docker02"],"launch_configuration"=>"mylconf","min_size"=>1,"max_size"=>5,"desired_capacity"=>1,"scale_out_cooldown"=>60,"scale_in_cooldown"=>60,"load_balancer"=>"mylb","domain"=>"research.ibm.com"}

POLICY_DOC={"name"=>"mypolicy","auto_scaling_group"=>"myasg","metric"=>"CPU","statistic"=>"AVG","sampling_window"=>60,"breach_duration"=>60,"scale_out_step"=>1,"scale_in_step"=>-1,"upper_threshold"=>80,"lower_threshold"=>30}
POLICY_DOC2={"name"=>"mypolicy","auto_scaling_group"=>"myasg","metric"=>"CPU","statistic"=>"AVG","sampling_window"=>60,"breach_duration"=>60,"scale_out_step"=>1,"scale_in_step"=>-1,"upper_threshold"=>90,"lower_threshold"=>40}

INSTANCE_DOC={"guid"=>"321c78c6-6560-4e4f-85fa-d5ae0177d6f0","name"=>"myasg","instance_id"=>"0","type"=>TYPE_CONTAINER,"status"=>"RUNNING","private_ip_address"=>"50.1.3.4","public_ip_address"=>"9.2.10.0","hostname"=>"host1","domain"=>"mydomain.com","n_cpus"=>1,"max_memory"=>1024,"availability_zone"=>"docker01","image_id"=>"abcd1234","hourly_billing"=>true,"timestamp"=>1000}
INSTANCE_DOC2={"guid"=>"321c78c6-6560-4e4f-85fa-d5ae0177d6f0","name"=>"myasg","instance_id"=>"0","type"=>TYPE_CONTAINER,"status"=>"STOPPED","private_ip_address"=>"50.1.3.4","public_ip_address"=>"9.2.10.0","hostname"=>"host2","domain"=>"mydomain.com","n_cpus"=>1,"max_memory"=>1024,"availability_zone"=>"docker01","image_id"=>"abcd1234","hourly_billing"=>true,"timestamp"=>12344}

LB_INSTANCE_DOC={"guid"=>"321c78c6-6560-4e4f-85fa-d5ae0177d6f0","name"=>"myasg","instance_id"=>"0","type"=>TYPE_LB,"status"=>"RUNNING","private_ip_address"=>"50.1.3.4","public_ip_address"=>"9.2.10.0","hostname"=>"host3","domain"=>"mydomain.com","n_cpus"=>1,"max_memory"=>1024,"availability_zone"=>"docker01","image_id"=>"abcd1234","hourly_billing"=>true,"timestamp"=>2000}

TEST_TEMPLATE={:asg_name=>ASG_NAME,:instance_type=>"m1.small",:n_cpus=>1,:memory=>64,:desired=>1,:type=>TYPE_CONTAINER,:domain=>TEST_DOMAIN,:image_id=>TEST_IMAGE_ID,:hourly_billing=>HOURLY_INSTANCE,:availability_zones=>["docker01","docker02"],:metadata=>TEST_DATA}   

