#!/bin/bash



################# BACKUPS ###################

#parameter from command line

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
clients=(1 2)
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






# subsquent subprocess calls with wait

for IDc in "${IDclients[@]}"; do
(
    ssh ${prefix}${IDc}${suffix} << EOSSH 
    sleep 3s
    EOSSH
) &
done
wait


echo "lel"


for IDc in "${IDclients[@]}"; do
(
    ssh ${prefix}${IDc}${suffix} << EOSSH 
    sleep 3s
    EOSSH
) &
done
wait


echo "lel"

#############################
# FIXED VARIABLES W/O LOOPS
#############################

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

IDserver=${IDserver1}
IDclient=${IDclient1}


fullServerName=${prefix}${IDserver}${suffix}
fullClientName=${prefix}${IDclient}${suffix}


ssh ${fullClientName} << EOSSH
mkdir -p ${dirName}
rm -f ${dirName}/*

# start pinging -- takes 2 secs longer than test time
screen -d -m -S pinger bash -c 'timeout $(($testTime+2)) ping -i ${pingInterval} ${prefix}${IDserver}${suffix} > ${dirName}/${now}_ping_${IDclient}_${IDserver}.log'
screen -d -m -S memtier bash -c '/home/can/memtier_benchmark-master/memtier_benchmark --server=${fullServerName} --port=11211 --protocol=memcache_text --threads=${threadCount} --clients=${clientCount} --test-time=${testTime} --ratio=${ratio} --expiry-range=9999-10000 --key-maximum=1000 --hide-histogram --out-file=${dirName}/${now}_report_${IDclient}_${IDserver}.txt'
EOSSH






#######################################
# LOCAL - NESTED FOOR LOOP W/ SCREEN
#######################################

# general variables
home="/home/can/asl-experiments"
dirName="experiment1"
writeonly="1:0"
readonly="0:1"

prefix="canforaslvms"
suffix=".westeurope.cloudapp.azure.com"


# experiment configurations
IDservers=(6) #(6 7 8)
IDmws=(4 5)
IDclients=(1 2 3) #(1 2 3)

testTime=2
pingInterval=1

ratio=${writeonly}
threadCount=2
virtualClientCount=(1 8 16 32)



for IDc in "${IDclients[@]}"; do
    for IDs in "${IDservers[@]}"; do
        # start pinging -- takes 2 secs longer than test time
        screen -d -m -S pinger_${IDs} bash -c "{ ping -w $(($testTime+2)) -i ${pingInterval} 127.0.0.1; } > $home/${dirName}/${IDc}_${IDs}_ping.log"
        screen -d -m -S memtier_${IDs} bash -c '/home/can/memtier_benchmark-master/memtier_benchmark --server=127.0.0.1 --port=11211 --protocol=memcache_text --threads=${threadCount} --clients=${c} --test-time=${testTime} --ratio=${ratio} --expiry-range=9999-10000 --key-maximum=1000 --hide-histogram --out-file=$home/${dirName}/${r}_${IDc}_${IDs}_report.txt'
    done
done


#######################################
# CLOUD - #SIMPLE SERVER LOOP
#######################################
for IDc in "${IDclients[@]}"; do
(
    ssh -T ${prefix}${IDc}${suffix} << 'EOSSH'
    mkdir -p ${dirName}
    for IDs in "${IDservers[@]}"; do
        # start pinging -- takes 2 secs longer than test time
        echo $IDc > $home/${dirName}/asd.log
        echo $IDs >> $home/${dirName}/asd.log
        #screen -d -m -S pinger_${IDs} bash -c "{ ping -w $(($testTime+2)) -i ${pingInterval} ${prefix}${IDservers[0]}${suffix}; } > $home/${dirName}/${IDc}_${IDs}_ping.log"
        #screen -d -m -S memtier_${IDs} bash -c "/home/can/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDservers[0]}${suffix} --port=11211 --protocol=memcache_text --threads=${threadCount} --clients=${c} --test-time=${testTime} --ratio=${ratio} --expiry-range=9999-10000 --key-maximum=1000 --hide-histogram --out-file=$home/${dirName}/${r}_${IDc}_${IDs}_report.txt"
    done

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &
done
wait









