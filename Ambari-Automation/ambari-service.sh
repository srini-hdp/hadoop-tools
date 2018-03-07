#!/bin/bash

if [ $# -lt 2 ]
    then
    echo "Usage : ambari-service.sh <ambari-FQDN> <operation>"
    echo "Supported Operations 	: startall to Start all HDP services"
    echo "			: stopall to Stop all HDP services"
    exit
fi

echo "Enter Ambari Admin password :"
read -s ambari_pass
ambari_fqdn=$1
ambari_url=`curl -s -i -u admin:"$ambari_pass" http://$ambari_fqdn:8080/api/v1/clusters | grep href | tail -1 | sed -n 's#.*\(http*://[^"]*\).*#\1#;p'`
if [[ -z $ambari_url ]]
  then
    echo -e "Unable to connect to Ambari Server.\nPlease check Ambari FQDN and/or Ambari password entered."
    exit
fi

service_state=`curl -s -i -u admin:"$ambari_pass" $ambari_url/services?fields=ServiceInfo/state | grep -w state | grep -v http | awk '{print $3}'`
state=`echo $service_state | grep STARTED`


if [ "$2" == "stopall" ]
    then
    if [[ -z $state ]]
	then
	echo "Services already stopped"
 	exit
    fi
    echo "Stopping all HDP services"
    curl -s -i -u admin:"$ambari_pass" -H "X-Requested-By: ambari"  -X PUT  -d '{"RequestInfo":{"context":"_PARSE_.STOP.ALL_SERVICES","operation_level":
{"level":"CLUSTER","cluster_name":"$clus"}},"Body":{"ServiceInfo":{"state":"INSTALLED"}}}' $ambari_url/services 2>&1 > /tmp/stopall.out
    req=`grep requests /tmp/stopall.out | sed -n 's#.*\(http*://[^"]*\).*#\1#;p'`
fi

if [ "$2" == "startall" ]
    then
    curl -s -i -u admin:"$ambari_pass" -H "X-Requested-By: ambari"  -X PUT  -d '{"RequestInfo":{"context":"_PARSE_.START.ALL_SERVICES","operation_level"
:{"level":"CLUSTER","cluster_name":"$clus"}},"Body":{"ServiceInfo":{"state":"STARTED"}}}' $ambari_url/services 2>&1 > /tmp/startall.out
    echo "Starting all HDP services"
    req=`grep requests /tmp/startall.out | sed -n 's#.*\(http*://[^"]*\).*#\1#;p'`
fi

req_status="PROGRESS"
echo "Checking the Request Status"
while [[ $req_status != *"COMPLETED"* ]]
do
   sleep 5
   req_status=`curl -s -i -u admin:"$ambari_pass" $req | grep request_status | awk '{print $NF}'`
echo "Operation is $req_status"
done