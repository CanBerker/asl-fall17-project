#!/bin/bash

cmdpart="./memtier_benchmark --port=11211 --protocol=memcache_text --ratio=0:1 --expiry-range=9999-10000 --key-maximum=1000 --hide-histogram"

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





