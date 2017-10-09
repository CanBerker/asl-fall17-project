#!/bin/bash

nodeid=0
server="bach0"
interval=5

#Check if there is an argument to the script
if [[ $# > 0 ]]; then
	nodeid="$1"
fi

#Check if there is a 2nd argument to the script
if [[ $# > 1 ]]; then
	interval="$2"
fi

#cleanup old files
rm ping*.log

for i in {1..8}; do
	if [ $nodeid != $i ]; then
		cmd="ping -i ${interval} ${server}${i} > ping-${i}.log"
		eval $cmd &
	fi
done

echo "pings are running."





