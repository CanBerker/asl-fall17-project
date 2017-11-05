#!/bin/bash

cmdpart="memtier_benchmark --port=11211 --protocol=memcache_text --ratio=0:1 --expiry-range=9999-10000 --key-maximum=1000 --hide-histogram"

server="localhost"
time=20

#Check if there is an argument to the script
if [[ $# > 0 ]]; then
	server="$1"
fi

#Check if there is a 2nd argument to the script
if [[ $# > 1 ]]; then
	time="$2"
fi

#define parameter ranges
clients=(1 2 4)
threads=(2 4 8 16)


for c in "${clients[@]}"; do
	for th in "${threads[@]}"; do
		#add parameters to the command
		cmd="${cmdpart} --server=${server} --test-time=${time} --clients=${c} --threads=${th}"
		#run the command
		echo $cmd
		$cmd
	done
done

echo "done."





# general variables
dirname="experiment1"
writeonly="1:0"
readonly="0:1"

prefix="canforaslvms"
suffix=".westeurope.cloudapp.azure.com"

IDclient1=1
IDclient2=2
IDclient3=3

IDmw1=4
IDmw2=5

IDserver1=6
IDserver2=7
IDserver3=8

#localhost="127.0.0.1"
#prefix=""
#suffix=""


# experiment configurations
ratio=${writeonly}
IDserver=${IDserver1}
#server=$IDserver1
IDclient=${IDclient1}

threadCount=2
clientCount=1
testTime=2
pingInterval=1


fullServerName=${prefix}${IDserver}${suffix}
fullClientName=${prefix}${IDclient}${suffix}


now=$(date +"%Y%m%d_%H%M%S")

ssh ${fullClientName} << EOSSH
# part to be sent to clients with ssh
mkdir ${dirname}

# start pinging -- takes 2 secs longer than test time
screen -d -m -S pinger bash -c 'timeout $(($testTime+2)) ping -i ${pingInterval} ${prefix}${IDserver}${suffix} > ${dirname}/${now}_ping_${IDclient}_${IDserver}.log'

#screen -d -m -S batch_init /home/users/geocode/init_geocoder
screen -d -m -S memtier bash -c 'memtier_benchmark --server=${fullServerName} --port=11211 --protocol=memcache_text --threads=${threadCount} --clients=${clientCount} --test-time=${testTime} --ratio=${ratio} --expiry-range=9999-10000 --key-maximum=1000 --hide-histogram --out-file=${dirname}/${now}_report_${IDclient}_${IDserver}.txt'
EOSSH



rsync -avzhe ssh can@$client1$link:/home/can/experiment1 /home/can/experiment1 
rsync -avzhe ssh can@$client2$link:/home/can/experiment1 /home/can/experiment1 
rsync -avzhe ssh can@$client3$link:/home/can/experiment1 /home/can/experiment1 





# part to control the middleware

# part to control the server
# connect to server, save statistics







































