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

require "logger"

# states
ASG_STATE_STARTED="started"
ASG_STATE_STOPPED="stopped"
ASG_STATE_PAUSED="paused"
TYPE_LB="lb"
TYPE_CONTAINER="container"
START_TYPE_LEASE="start_type"
STOP_TYPE_LEASE="stop_type"
SHUTDOWN_STATES=["CLOUD_ISO_BOOT_TEAR_DOWN","CLOUD_INSTANCE_NETWORK_RECLAIM","RECLAIM_NETWORK"]
STARTUP_STATES=["ASSIGN_HOST","CLONE_CLOUD_TEMPLATE","ATTACH_PRIMARY_DISK","CLOUD_PROVISION_SETUP","CLOUD_CONFIGURE_METADATA_DISK","POWER_ON","INSTALL_COMPLETE","SERVICE_SETUP"]
RUNNING_STATE="RUNNING"
NOT_RUNNING_STATE="DOWN"
REQUEST_PROCESSING_STATE="PROCESSING"
STARTING_STATE="STARTING"
STOPPING_STATE="STOPPING"
STALLED_STATE="STALLED"

# intervals and timeout for workers 
INTERVAL=5
MAX_TIME=90

# logger settings
L = Logger.new(STDERR)
L.level = Logger::DEBUG



