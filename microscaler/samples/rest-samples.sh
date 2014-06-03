curl -X POST -H "Content-Type: application/json" -d '{"user":"IBM290445","key":"5809731035998b9540297ade59105677734299f70b87c46ec340a246715099d7"}' http://50.22.42.10:56785/asgcc/login

curl -X POST -H "Content-Type: application/json" -H "authorization: " -d '{"name":"mylb","lb_port":8081,"instances_port":9080,"availability_zones":["docker01"],"protocol":"HTTP","options":["headers"]}' http://50.22.42.10:56785/asgcc/lbs

curl -X POST -H "Content-Type: application/json" -H "authorization: " -d '{"name":"mylconf","image_id":"fb430cfe-4620-4764-88c3-34d7219eff0a","instances_type":"m1.small","key":"keypair"}' http://50.22.42.10:56785/asgcc/lconfs

curl -X POST -H "Content-Type: application/json" -H "authorization: " -d '{"name":"myasg","availability_zones":["docker01"],"launch_configuration":"mylconf","min_size":1,"max_size":3,"scale_out_cooldown":300,"scale_in_cooldown":90,"load_balancer":"mylb"}' http://50.22.42.10:56785/asgcc/asgs

curl -X POST -H "Content-Type: application/json" -H "authorization: " -d '{"name":"mypolicy","auto_scaling_group":"myasg","metric":"CPU","statistic":"AVG","sampling_window":60,"breach_duration":180,"scale_out_step":1,"scale_in_step":-1,"upper_threshold":80,"lower_threshold":30}' http://50.22.42.10:56785/asgcc/policies

curl -X PUT -H "Content-Type: application/json" -H "authorization: " -d '' http://50.22.42.10:56785/asgcc/asgs/myasg/start

