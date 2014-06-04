microscaler - an implementation of autoscaling groups for docker containers. 
============================================================================

## Requirements
docker 0.9 and higher

## Installing

Set up the demon on the docker host so that it uses the network and not just Unix sockets.

	$ sudo vi /etc/default/docker

and edit it as follows:

```bash
	DOCKER_OPTS="-r=true -H tcp://0.0.0.0:4243 -H unix:///var/run/docker.sock  ${DOCKER_OPTS}"
```
Then run:
  
	$ sudo service docker restart

clone the microscaler docker installer github repo 

	$ git clone https://github.com/EmergingTechnologyInstitute/acmeair-netflixoss-dockerlocal
	$ cd acmeair-netflixoss-dockerlocal

build the docker containers for microscaler and host agent:

	$ docker build -t acmeair/base base
	$ docker build -t acmeair/microscaler microscaler
	$ docker build -t acmeair/microscaler-agent microscaler-agent

## Running

	$ docker run -t -d -P acmeair/asg-controller
	$ docker run -t -d -P acmeair/microscaler-agent

## Using
acmeair-netflixoss-dockerloca/bin/configureasg.sh provides an example of running the microscaler by invoking the CLI from the host with ssh.

You may also ssh into the microscaler container to use the microscaler CLI and interact with the microscaler components.

### Configuration file
The microscaler configuration file is located at:

```bash
/usr/local/microscaler/config/microscaler.yml
```

Make sure that the address set for the docker daemon_url is set to the address of the interface docker0 in the docker host.
If you make changes to the configuration you will need to restart microscaler components with the command:

	$ supervisorctl restart controller healthmanager worker-launch worker-stop

### Managing microscaler components
microscaler components are managed by supervisor. To find out the status of each component run:

	$ supervisorctl

For example:

	$ supervisorctl status
	controller                       RUNNING    pid 748, uptime 8:44:29
	gnatsd                           RUNNING    pid 9, uptime 10:26:16
	healthmanager                    RUNNING    pid 908, uptime 8:37:03
	mongodb                          RUNNING    pid 8, uptime 10:26:16
	redis                            RUNNING    pid 7, uptime 10:26:16
	sshd                             RUNNING    pid 17, uptime 10:26:16
	worker-launch                    RUNNING    pid 606, uptime 9:02:35
	worker-stop                      RUNNING    pid 570, uptime 9:03:04

### Using the microscaler CLI

You can access the microscaler CLI help screen simply typing: 

	$ ms

here is a simple example of using the CLI to configure and start an autoscaling group for the docker image *cirros*

#### Logging in

	$ ms login --target http://localhost:56785/asgcc/ --user user01 --key key 

#### Adding a launch configuration

	$ ms add-lconf --lconf-name lconf1 --lconf-image-id cirros --lconf-instances-type m1.small --lconf-key key1

#### Adding an autoscaling group

	$ ms add-asg --asg-name asg1 --asg-availability-zones docker02 --asg-launch-configuration lconf1 --asg-min-size 1 --asg-desired-capacity 1 --asg-max-size 4 --asg-scale-out-cooldown 60 --asg-scale-in-cooldown 60 --asg-domain mydomain.net --asg-no-load-balancer 

#### Starting the autoscaling group

	$ ms start-asg --asg-name asg1

#### Checking status
You can check if the new instances are started running *docker ps* from the host; e.g.

	$ docker ps
	CONTAINER ID        IMAGE                           COMMAND                CREATED             STATUS              PORTS                   NAMES
	963968b5bd43        cirros:0.3.0                    /sbin/init             56 seconds ago      Up 56 seconds         
	56b6936c45eb        acmeair/asg-controller:latest   /usr/bin/supervisord   13 hours ago        Up 13 hours         0.0.0.0:49153->22/tcp   asg-controller      

You can run *list-asgs* to query about ASGs, *ms list-instances* to query about instances for an ASG, *ms list-lconfs* to query about launch configurations; e.g.

	$ ms list-asgs
	NAME  | STATE   | AVAILABILITY_ZONES | URL            | MIN_SIZE | MAX_SIZE | DESIRED_CAPACITY
	------|---------|--------------------|----------------|----------|----------|-----------------
	dock1 | started | ["docker02"]       | N/A 			  | 1        | 3        | 1     

#### Checking Logs
Logs are managed by supervisor and located at:

```bash
/var/log/supervisor/
```

The most useful logs are:

##### Health manager log
it shows which instances are up or down and actions taken to recover when instances crash or are killed.

```bash
/var/log/supervisor/healthmanager*.log
```

##### Instance manager workers log 
it shows events related to the interaction with the docker engine (e.g. invoking the docker engine to launch a new docker container) and errors that may occur when starting or stopping docker instances.

```bash
/var/log/supervisor/worker*.log
```

##### Rest controller log 
it shows events related to the invocation of the REST API (e.g. through CLI or another REST client)

```bash
/var/log/supervisor/controller*.log
```

## Limitations
1. docker agent is not reporting CPU/memory metrics.
2. monitoring components and webhooks to support policy-based elastic autoscaling are not implemented.

## License

Apache 2.0
