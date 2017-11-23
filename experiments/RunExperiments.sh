#!/bin/bash


ssh canforaslvms9.westeurope.cloudapp.azure.com
screen -S coordinator

# general variables
remoteHome="/home/can"
localpchome="/home/can/asl-experiments"

prefix="canforaslvms"
suffix=".westeurope.cloudapp.azure.com"

dirName="asl-experiments"
dirNameMw="asl-fall17-project"

modeName=("writeonly" "readonly")
modeRatio=("1:0" "0:1")

expiryRange="9999-10000"
keyMaximum=1000

serverFileName="server"
serverFileExtension="txt"
reportFileName="report"
reportFileExtension="txt"
pingFileName="ping"
pingFileExtension="txt"


repeatCount=1

testTime=5
pingInterval=1

pingSafetyTime=2
testSafetyTime=3



# experiment configurations
experimentName="experiment1"
partName="part1"

IDservers=(6)
IDclients=(1 2 3)

threadCount=2
virtualClientCount=(1 8 16 24 32 64)

serverPort=11211


# part to control the server
for IDs in "${IDservers[@]}"; do
(
    ssh ${prefix}${IDs}${suffix} << EOSSH 
    mkdir -p $remoteHome/${dirName}/${experimentName}/${partName}
    #rm -f ${dirName}/*   # clear previous logs if necessary
    
    screen -d -m -S memcached bash -c 'memcached -A -v -p ${serverPort} > $remoteHome/${dirName}/${experimentName}/${partName}/${serverFileName}_${IDs}.${serverFileExtension}'
EOSSH
) &
done
wait

# POPULATE MEMCACHED SERVERS IF NEEDED, HALT SCRIPT IN THE MEAN TIME


# part to control the clients
for modeIndex in {0..1}; do
    for r in $(seq 1 $repeatCount); do
        for c in "${virtualClientCount[@]}"; do
            for IDc in "${IDclients[@]}"; do
            (
                ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                mkdir -p $remoteHome/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                screen -d -m -S pinger_${IDs} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDservers[0]}${suffix}; } > $remoteHome/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDservers[0]}_${pingFileName}.${pingFileExtension}"

                screen -d -m -S memtier_${IDs} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDservers[0]}${suffix} --port=${serverPort} --protocol=memcache_text --threads=${threadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDservers[0]}_${reportFileName}.${reportFileExtension}"
                
# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
            ) &
            done
            wait
        sleep $((${testTime}+${testSafetyTime}))
        done
    done
done


# close memcached at servers
for IDs in "${IDservers[@]}"; do
(
    { echo "shutdown"; } | telnet ${prefix}${IDs}${suffix} 11211
) &
done
wait



experimentName="experiment1"
partName="part2"

IDservers=(6 7) #(6 7 8)
IDclients=(1) #(1 2 3)

threadCount=1
virtualClientCount=(1 8 16 24 32 64)

serverPort=11211


# part to control the server
for IDs in "${IDservers[@]}"; do
(
    ssh ${prefix}${IDs}${suffix} << EOSSH 
    mkdir -p $remoteHome/${dirName}/${experimentName}/${partName}
    #rm -f ${dirName}/*   # clear previous logs if necessary
    
    screen -d -m -S memcached bash -c 'memcached -A -v -p ${serverPort} > $remoteHome/${dirName}/${experimentName}/${partName}/${serverFileName}_${IDs}.${serverFileExtension}'
EOSSH
) &
done
wait

# POPULATE MEMCACHED SERVERS IF NEEDED, HALT SCRIPT IN THE MEAN TIME


# part to control the clients
for modeIndex in {0..1}; do
    for r in $(seq 1 $repeatCount); do
        for c in "${virtualClientCount[@]}"; do
            for IDc in "${IDclients[@]}"; do
            (
                ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                mkdir -p $remoteHome/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                screen -d -m -S pinger_${IDservers[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDservers[0]}${suffix}; } > $remoteHome/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDservers[0]}_${pingFileName}.${pingFileExtension}"
                screen -d -m -S pinger_${IDservers[1]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDservers[1]}${suffix}; } > $remoteHome/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDservers[1]}_${pingFileName}.${pingFileExtension}"

                screen -d -m -S memtier_${IDservers[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDservers[0]}${suffix} --port=${serverPort} --protocol=memcache_text --threads=${threadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDservers[0]}_${reportFileName}.${reportFileExtension}"
                screen -d -m -S memtier_${IDservers[1]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDservers[1]}${suffix} --port=${serverPort} --protocol=memcache_text --threads=${threadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDservers[1]}_${reportFileName}.${reportFileExtension}"
                

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
            ) &
            done
            wait
        sleep $((${testTime}+${testSafetyTime}))
        done
    done
done


# close memcached at servers
for IDs in "${IDservers[@]}"; do
(
    { echo "shutdown"; } | telnet ${prefix}${IDs}${suffix} 11211
) &
done
wait


#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################




experimentName="experiment2"
partName="part1"

IDservers=(6) #(6 7 8)
IDmws=(4)
IDclients=(1) #(1 2 3)

threadCount=1
virtualClientCount=(1 8 16 24 32 64)
workerThreadCount=(8 16 32 64)

serverPort=11211
middlewarePort=16399

sharded="false"

# 


# part to control the server
for IDs in "${IDservers[@]}"; do
(
    ssh ${prefix}${IDs}${suffix} << EOSSH 
    mkdir -p $remoteHome/${dirName}/${experimentName}/${partName}
    #rm -f ${dirName}/*   # clear previous logs if necessary
    
    screen -d -m -S memcached bash -c 'memcached -A -v -p ${serverPort} > $remoteHome/${dirName}/${experimentName}/${partName}/${serverFileName}_${IDs}.${serverFileExtension}'
EOSSH
) &
done
wait

# POPULATE MEMCACHED SERVERS IF NEEDED, HALT SCRIPT IN THE MEAN TIME



#TODO: ITERATE OVER WORKER THREAD COUNTS

# part to control the middleware
for IDmw in "${IDmws[@]}"; do
(
    ssh ${prefix}${IDmw}${suffix} << EOSSH 
    screen -d -m -S mw bash -c 'java -jar $remoteHome/${dirNameMw}/dist/middleware-ccikis.jar -l ${prefix}${IDmw}${suffix} -p ${middlewarePort} -t 1 -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort}'

EOSSH
) &
done



# part to control the clients
for modeIndex in {0..1}; do
    for r in $(seq 1 $repeatCount); do
        for c in "${virtualClientCount[@]}"; do
            for IDc in "${IDclients[@]}"; do
            (
                ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                mkdir -p $remoteHome/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > $remoteHome/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDmws[0]}_${pingFileName}.${pingFileExtension}"

                screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${port} --protocol=memcache_text --threads=${threadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDmws[0]}_${reportFileName}.${reportFileExtension}"
                

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
            ) &
            done
            wait
            sleep $((${testTime}+${testSafetyTime}))
        done
    done
done


# close memcached at servers
for IDs in "${IDservers[@]}"; do
(
    { echo "shutdown"; } | telnet ${prefix}${IDs}${suffix} 11211
) &
done
wait








experimentName="experiment2"
partName="part2"

IDservers=(6) #(6 7 8)
IDmws=(4 5)
IDclients=(1) #(1 2 3)

threadCount=1
virtualClientCount=(1 8 16 24 32 64)
workerThreadCount=(8 16 32 64)

serverPort=11211
middlewarePort=16399

# -l 127.0.0.1 -p 16399 -t 1 -s false -m 127.0.0.1:11211


# part to control the server
for IDs in "${IDservers[@]}"; do
(
    ssh ${prefix}${IDs}${suffix} << EOSSH 
    mkdir -p $remoteHome/${dirName}/${experimentName}/${partName}
    #rm -f ${dirName}/*   # clear previous logs if necessary
    
    screen -d -m -S memcached bash -c 'memcached -A -v -p ${serverPort} > $remoteHome/${dirName}/${experimentName}/${partName}/${serverFileName}_${IDs}.${serverFileExtension}'
EOSSH
) &
done
wait

# POPULATE MEMCACHED SERVERS IF NEEDED, HALT SCRIPT IN THE MEAN TIME


#TODO: ITERATE OVER WORKER THREAD COUNTS

# part to control the middleware
for IDmw in "${IDmws[@]}"; do
(
    ssh ${prefix}${IDmw}${suffix} << EOSSH 
    screen -d -m -S mw bash -c 'java -jar $remoteHome/${dirNameMw}/dist/middleware-ccikis.jar -l ${prefix}${IDmw}${suffix} -p ${middlewarePort} -t 1 -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort} ${prefix}${IDservers[1]}${suffix}:${serverPort}'

EOSSH
) &
done


# part to control the clients
for modeIndex in {0..1}; do
    for r in $(seq 1 $repeatCount); do
        for c in "${virtualClientCount[@]}"; do
            for IDc in "${IDclients[@]}"; do
            (
                ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                mkdir -p $remoteHome/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > $remoteHome/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDmws[0]}_${pingFileName}.${pingFileExtension}"
                screen -d -m -S pinger_${IDmws[1]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[1]}${suffix}; } > $remoteHome/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDmws[1]}_${pingFileName}.${pingFileExtension}"

                screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${port} --protocol=memcache_text --threads=${threadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDmws[0]}_${reportFileName}.${reportFileExtension}"
                screen -d -m -S memtier_${IDmws[1]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[1]}${suffix} --port=${port} --protocol=memcache_text --threads=${threadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${r}_${c}_${IDc}_${IDmws[1]}_${reportFileName}.${reportFileExtension}"
                

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
            ) &
            done
            wait
            sleep $((${testTime}+${testSafetyTime}))
        done
    done
done


# close memcached at servers
for IDs in "${IDservers[@]}"; do
(
    { echo "shutdown"; } | telnet ${prefix}${IDs}${suffix} 11211
) &
done
wait
















# rsync - trailing "/" copies the ocntents of the folder
# GET CLIENT LOGS
for IDc in "${IDclients[@]}"; do
    rsync -avzhe ssh can@${prefix}${IDc}${suffix}:${remoteHome}/${dirName}/ ${localpchome}        # –remove-source-files
done
wait

# GET SERVER LOGS
for IDs in "${IDservers[@]}"; do
    rsync -avzhe ssh can@${prefix}${IDs}${suffix}:${remoteHome}/${dirName}/ ${localpchome}
done
wait



# REMOVE LOGS AT CLIENT
for IDc in "${IDclients[@]}"; do
(
    ssh ${prefix}${IDc}${suffix} << EOSSH 
    rm -f ${dirName}/*

EOSSH
) &
done
wait






# connect to server, save statistics











