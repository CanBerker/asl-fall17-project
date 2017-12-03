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

mwQueueFileName="queueLengthLog"
mwQueueFileExtension="csv"
mwRequestFileName="requestLog"
mwRequestFileExtension="csv"


repeatCount=1

testTime=15
pingInterval=1

mwStartSafetyTime=8
pingSafetyTime=2
testSafetyTime=2
mwLoggingSafetyTime=6



# experiment configurations
experimentName="experiment1"
partName="part1"

IDservers=(6)
IDclients=(1 2 3)

memtierThreadCount=2
virtualClientCount=(1 8 16 24 32 64 96)

serverPort=11211


# part to control the server
for IDs in "${IDservers[@]}"; do
(
    ssh ${prefix}${IDs}${suffix} << EOSSH 
    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}
    #rm -f ${dirName}/*   # clear previous logs if necessary
    
    screen -d -m -S memcached bash -c "memcached -A -v -p ${serverPort} > ${remoteHome}/${dirName}/${experimentName}/${partName}/${serverFileName}_${IDs}.${serverFileExtension}"
EOSSH
) &
done
wait

# POPULATE MEMCACHED SERVERS IF NEEDED, HALT SCRIPT IN THE MEAN TIME


# part to control the clients
for c in "${virtualClientCount[@]}"; do
    for modeIndex in {0..1}; do
        for r in $(seq 1 $repeatCount); do
            for IDc in "${IDclients[@]}"; do
            (
                ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                screen -d -m -S pinger_${IDs} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDservers[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${IDc}_${IDservers[0]}_${r}_${pingFileName}.${pingFileExtension}"

                screen -d -m -S memtier_${IDs} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDservers[0]}${suffix} --port=${serverPort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${IDc}_${IDservers[0]}_${r}_${reportFileName}.${reportFileExtension}"
         
                sleep $((${testTime}+${testSafetyTime}))

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
            ) &
            done
            wait
        done
    done
done




experimentName="experiment1"
partName="part2"

IDservers=(6 7)
IDclients=(1)

memtierThreadCount=1
virtualClientCount=(1 8 16 24 32 64 96)

serverPort=11211


# part to control the clients
for c in "${virtualClientCount[@]}"; do
    for modeIndex in {0..1}; do    
        for r in $(seq 1 $repeatCount); do
            for IDc in "${IDclients[@]}"; do
            (
                ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                screen -d -m -S pinger_${IDservers[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDservers[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${IDc}_${IDservers[0]}_${r}_${pingFileName}.${pingFileExtension}"
                screen -d -m -S pinger_${IDservers[1]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDservers[1]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${IDc}_${IDservers[1]}_${r}_${pingFileName}.${pingFileExtension}"

                screen -d -m -S memtier_${IDservers[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDservers[0]}${suffix} --port=${serverPort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${IDc}_${IDservers[0]}_${r}_${reportFileName}.${reportFileExtension}"
                screen -d -m -S memtier_${IDservers[1]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDservers[1]}${suffix} --port=${serverPort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${IDc}_${IDservers[1]}_${r}_${reportFileName}.${reportFileExtension}"
                
                sleep $((${testTime}+${testSafetyTime}))

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
            ) &
            done
            wait
        done
    done
done


#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################




experimentName="experiment2"
partName="part1"

IDservers=(6)
IDmws=(4)
IDclients=(1)

memtierThreadCount=2
virtualClientCount=(1 8 16 24 32 64 96)
workerThreadCount=(8 16 32 64)

serverPort=11211
middlewarePort=16399

sharded="false"


for c in "${virtualClientCount[@]}"; do
    for t in "${workerThreadCount[@]}"; do
        for modeIndex in {0..1}; do
            for r in $(seq 1 $repeatCount); do
                # part to control the middleware -- mw private IPs : machine4 - 10.0.0.8 , machine5- 10.0.0.9 (+4 from machine number -- coincidental)
                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    screen -d -m -S mw bash -c "java -jar ${remoteHome}/${dirNameMw}/dist/middleware-ccikis.jar -l 10.0.0.$((${IDmw} + 4)) -p ${middlewarePort} -t ${t} -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort}"
                    # wait until middlewares are safely initialized
                    sleep ${mwStartSafetyTime}

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait


                # part to control the clients
                for IDc in "${IDclients[@]}"; do
                (
                    ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                    screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${pingFileName}.${pingFileExtension}"

                    screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${reportFileName}.${reportFileExtension}"
                    
                    sleep $((${testTime}+${testSafetyTime}))

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait
                
                # close middlewares
                for IDmw in "${IDmws[@]}"; do
                (
                    { echo "shutdown"; } | telnet ${prefix}${IDmw}${suffix} ${middlewarePort}
                    # wait for logs to be produced
                    sleep ${mwLoggingSafetyTime}
                ) &
                done
                wait


                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}
                    mv ${remoteHome}/${mwQueueFileName}.${mwQueueFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwQueueFileName}.${mwQueueFileExtension}
                    mv ${remoteHome}/${mwRequestFileName}.${mwRequestFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwRequestFileName}.${mwRequestFileExtension}
                    

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait
            done
        done
    done
done



experimentName="experiment2"
partName="part2"

IDservers=(6)
IDmws=(4 5)
IDclients=(1)

memtierThreadCount=1
virtualClientCount=(1 8 16 24 32 64 96)
workerThreadCount=(8 16 32 64)

serverPort=11211
middlewarePort=16399

sharded="false"


for c in "${virtualClientCount[@]}"; do
    for t in "${workerThreadCount[@]}"; do
        for modeIndex in {0..1}; do
            for r in $(seq 1 $repeatCount); do
                # part to control the middleware -- mw private IPs : machine4 - 10.0.0.8 , machine5- 10.0.0.9 (+4 from machine number -- coincidental)
                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    screen -d -m -S mw bash -c "java -jar ${remoteHome}/${dirNameMw}/dist/middleware-ccikis.jar -l 10.0.0.$((${IDmw} + 4)) -p ${middlewarePort} -t ${t} -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort}"
                    # wait until middlewares are safely initialized
                    sleep ${mwStartSafetyTime}

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait

               
                # part to control the clients
                for IDc in "${IDclients[@]}"; do
                (
                    ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                    screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${pingFileName}.${pingFileExtension}"
                    screen -d -m -S pinger_${IDmws[1]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[1]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${r}_${pingFileName}.${pingFileExtension}"

                    screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${reportFileName}.${reportFileExtension}"
                    screen -d -m -S memtier_${IDmws[1]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[1]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${r}_${reportFileName}.${reportFileExtension}"
                    
                    sleep $((${testTime}+${testSafetyTime}))

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait


                # close middlewares
                for IDmw in "${IDmws[@]}"; do
                (
                    { echo "shutdown"; } | telnet ${prefix}${IDmw}${suffix} ${middlewarePort}
                    # wait for logs to be produced
                    sleep ${mwLoggingSafetyTime}
                ) &
                done
                wait


                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}
                    mv ${remoteHome}/${mwQueueFileName}.${mwQueueFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwQueueFileName}.${mwQueueFileExtension}
                    mv ${remoteHome}/${mwRequestFileName}.${mwRequestFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwRequestFileName}.${mwRequestFileExtension}
                    

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &
                done
                wait
            done
        done
    done
done



#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################

# THROUGHPUT FOR WRITES


experimentName="experiment3"
partName="part1"

IDservers=(6 7 8)
IDmws=(4 5)
IDclients=(1 2 3)

memtierThreadCount=1
virtualClientCount=(1 8 16 24 32 64 96)
workerThreadCount=(8 16 32 64)

serverPort=11211
middlewarePort=16399

sharded="false"

modeName=("writeonly")
modeRatio=("1:0")



for c in "${virtualClientCount[@]}"; do
    for t in "${workerThreadCount[@]}"; do
        for modeIndex in {0..0}; do
            for r in $(seq 1 $repeatCount); do
                # part to control the middleware -- mw private IPs : machine4 - 10.0.0.8 , machine5- 10.0.0.9 (+4 from machine number -- coincidental)
                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    screen -d -m -S mw bash -c "java -jar ${remoteHome}/${dirNameMw}/dist/middleware-ccikis.jar -l 10.0.0.$((${IDmw} + 4)) -p ${middlewarePort} -t ${t} -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort} ${prefix}${IDservers[1]}${suffix}:${serverPort} ${prefix}${IDservers[2]}${suffix}:${serverPort}"
                    # wait until middlewares are safely initialized
                    sleep ${mwStartSafetyTime}
# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait


                # part to control the clients
                for IDc in "${IDclients[@]}"; do
                (
                    ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                    screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${pingFileName}.${pingFileExtension}"
                    screen -d -m -S pinger_${IDmws[1]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[1]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${r}_${pingFileName}.${pingFileExtension}"

                    screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${reportFileName}.${reportFileExtension}"
                    screen -d -m -S memtier_${IDmws[1]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[1]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${r}_${reportFileName}.${reportFileExtension}"
                    
                    sleep $((${testTime}+${testSafetyTime}))

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait
                

                # close middlewares
                for IDmw in "${IDmws[@]}"; do
                (
                    { echo "shutdown"; } | telnet ${prefix}${IDmw}${suffix} ${middlewarePort}
                    # wait for logs to be produced
                    sleep ${mwLoggingSafetyTime}
                ) &
                done
                wait

                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}
                    
                    mv ${remoteHome}/${mwQueueFileName}.${mwQueueFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwQueueFileName}.${mwQueueFileExtension}

                    mv ${remoteHome}/${mwRequestFileName}.${mwRequestFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwRequestFileName}.${mwRequestFileExtension}
                    

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &             
                done
                wait
            done
        done
    done
done



#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################

# GETS AND MULTI-GETS


experimentName="experiment4"
partName="part1"

IDservers=(6 7 8)
IDmws=(4 5)
IDclients=(1 2 3)

memtierThreadCount=1
virtualClientCount=(1 8 16 24 32 64 96)
workerThreadCount=(64)

serverPort=11211
middlewarePort=16399

sharded="true"

modeName=("mixed")
modeRatio=("1:10")

multiGetMaxSize=(1 3 6 9)


for c in "${virtualClientCount[@]}"; do
    for t in "${workerThreadCount[@]}"; do
        for modeIndex in {0..0}; do
            for mgms in "${multiGetMaxSize[@]}"; do
                for r in $(seq 1 $repeatCount); do
                    # part to control the middleware -- mw private IPs : machine4 - 10.0.0.8 , machine5- 10.0.0.9 (+4 from machine number -- coincidental)
                    for IDmw in "${IDmws[@]}"; do
                    (
                        ssh ${prefix}${IDmw}${suffix} << EOSSH 
                        screen -d -m -S mw bash -c "java -jar ${remoteHome}/${dirNameMw}/dist/middleware-ccikis.jar -l 10.0.0.$((${IDmw} + 4)) -p ${middlewarePort} -t ${t} -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort} ${prefix}${IDservers[1]}${suffix}:${serverPort} ${prefix}${IDservers[2]}${suffix}:${serverPort}"
                        # wait until middlewares are safely initialized
                        sleep ${mwStartSafetyTime}
# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &
                    done
                    wait
                    

                    # part to control the clients
                    for IDc in "${IDclients[@]}"; do
                    (
                        ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                        mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                        screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${mgms}_${r}_${pingFileName}.${pingFileExtension}"
                        screen -d -m -S pinger_${IDmws[1]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[1]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${mgms}_${r}_${pingFileName}.${pingFileExtension}"

                        screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --multi-key-get=${mgms} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${mgms}_${r}_${reportFileName}.${reportFileExtension}"
                        screen -d -m -S memtier_${IDmws[1]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[1]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --multi-key-get=${mgms} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${mgms}_${r}_${reportFileName}.${reportFileExtension}"
                        
                        sleep $((${testTime}+${testSafetyTime}))
# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                    ) &
                    done
                    wait


                    # close middlewares
                    for IDmw in "${IDmws[@]}"; do
                    (
                        { echo "shutdown"; } | telnet ${prefix}${IDmw}${suffix} ${middlewarePort}
                        # wait for logs to be produced
                        sleep ${mwLoggingSafetyTime}
                    ) &
                    done
                    wait
                    

                    for IDmw in "${IDmws[@]}"; do
                    (
                        ssh ${prefix}${IDmw}${suffix} << EOSSH 
                        mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}
                        
                        mv ${remoteHome}/${mwQueueFileName}.${mwQueueFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${mgms}_${r}_${mwQueueFileName}.${mwQueueFileExtension}

                        mv ${remoteHome}/${mwRequestFileName}.${mwRequestFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${mgms}_${r}_${mwRequestFileName}.${mwRequestFileExtension}
                        

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &                 done
                    wait
                done
            done
        done
    done
done



experimentName="experiment4"
partName="part2"

IDservers=(6 7 8)
IDmws=(4 5)
IDclients=(1 2 3)

memtierThreadCount=1
virtualClientCount=(1 8 16 24 32 64 96)
workerThreadCount=(64)

serverPort=11211
middlewarePort=16399

sharded="false"

modeName=("mixed")
modeRatio=("1:10")

multiGetMaxSize=(1 3 6 9)


for c in "${virtualClientCount[@]}"; do
    for t in "${workerThreadCount[@]}"; do
        for modeIndex in {0..0}; do
            for mgms in "${multiGetMaxSize[@]}"; do
                for r in $(seq 1 $repeatCount); do
                    # part to control the middleware -- mw private IPs : machine4 - 10.0.0.8 , machine5- 10.0.0.9 (+4 from machine number -- coincidental)
                    for IDmw in "${IDmws[@]}"; do
                    (
                        ssh ${prefix}${IDmw}${suffix} << EOSSH 
                        screen -d -m -S mw bash -c "java -jar ${remoteHome}/${dirNameMw}/dist/middleware-ccikis.jar -l 10.0.0.$((${IDmw} + 4)) -p ${middlewarePort} -t ${t} -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort} ${prefix}${IDservers[1]}${suffix}:${serverPort} ${prefix}${IDservers[2]}${suffix}:${serverPort}"
                        # wait until middlewares are safely initialized
                        sleep ${mwStartSafetyTime}

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &
                    done
                    wait

                    
                    # part to control the clients
                    for IDc in "${IDclients[@]}"; do
                    (
                        ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                        mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                        screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${mgms}_${r}_${pingFileName}.${pingFileExtension}"
                        screen -d -m -S pinger_${IDmws[1]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[1]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${mgms}_${r}_${pingFileName}.${pingFileExtension}"

                        screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --multi-key-get=${mgms} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${mgms}_${r}_${reportFileName}.${reportFileExtension}"
                        screen -d -m -S memtier_${IDmws[1]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[1]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --multi-key-get=${mgms} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${mgms}_${r}_${reportFileName}.${reportFileExtension}"
                        
                        sleep $((${testTime}+${testSafetyTime}))

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                    ) &
                    done
                    wait
                   


                    # close middlewares
                    for IDmw in "${IDmws[@]}"; do
                    (
                        { echo "shutdown"; } | telnet ${prefix}${IDmw}${suffix} ${middlewarePort}
                        # wait for logs to be produced
                        sleep ${mwLoggingSafetyTime}
                    ) &
                    done
                    wait


                    for IDmw in "${IDmws[@]}"; do
                    (
                        ssh ${prefix}${IDmw}${suffix} << EOSSH 
                        mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}
                        
                        mv ${remoteHome}/${mwQueueFileName}.${mwQueueFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${mgms}_${r}_${mwQueueFileName}.${mwQueueFileExtension}

                        mv ${remoteHome}/${mwRequestFileName}.${mwRequestFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${mgms}_${r}_${mwRequestFileName}.${mwRequestFileExtension}
                        

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &                 done
                    wait
                done
            done
        done
    done
done






#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################
#################################################################################################################################################

# 2K Analysis


experimentName="experiment5"
partName="part1_2s_1mw"

IDservers=(6 7)
IDmws=(4)
IDclients=(1 2 3)

memtierThreadCount=1
virtualClientCount=(32)     # 64 clients per machine
workerThreadCount=(8 32)

serverPort=11211
middlewarePort=16399

sharded="false"

modeName=("writeonly", "readonly", "50-50")
modeRatio=("1:0", "0:1", "1:1")


for c in "${virtualClientCount[@]}"; do
    for t in "${workerThreadCount[@]}"; do
        for modeIndex in {0..2}; do
            for r in $(seq 1 $repeatCount); do
                # part to control the middleware -- mw private IPs : machine4 - 10.0.0.8 , machine5- 10.0.0.9 (+4 from machine number -- coincidental)
                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    screen -d -m -S mw bash -c "java -jar ${remoteHome}/${dirNameMw}/dist/middleware-ccikis.jar -l 10.0.0.$((${IDmw} + 4)) -p ${middlewarePort} -t ${t} -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort} ${prefix}${IDservers[1]}${suffix}:${serverPort}"
                    # wait until middlewares are safely initialized
                    sleep ${mwStartSafetyTime}
# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait


                # part to control the clients
                for IDc in "${IDclients[@]}"; do
                (
                    ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                    screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${pingFileName}.${pingFileExtension}"

                    screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${reportFileName}.${reportFileExtension}"
                    
                    sleep $((${testTime}+${testSafetyTime}))

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait
                

                # close middlewares
                for IDmw in "${IDmws[@]}"; do
                (
                    { echo "shutdown"; } | telnet ${prefix}${IDmw}${suffix} ${middlewarePort}
                    # wait for logs to be produced
                    sleep ${mwLoggingSafetyTime}
                ) &
                done
                wait

                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}
                    
                    mv ${remoteHome}/${mwQueueFileName}.${mwQueueFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwQueueFileName}.${mwQueueFileExtension}

                    mv ${remoteHome}/${mwRequestFileName}.${mwRequestFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwRequestFileName}.${mwRequestFileExtension}
                    

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &             
                done
                wait
            done
        done
    done
done




experimentName="experiment5"
partName="part2_2s_2mw"

IDservers=(6 7)
IDmws=(4 5)
IDclients=(1 2 3)

memtierThreadCount=1
virtualClientCount=(32)     # 64 clients per machine
workerThreadCount=(8 32)

serverPort=11211
middlewarePort=16399

sharded="false"

modeName=("writeonly", "readonly", "50-50")
modeRatio=("1:0", "0:1", "1:1")



for c in "${virtualClientCount[@]}"; do
    for t in "${workerThreadCount[@]}"; do
        for modeIndex in {0..2}; do
            for r in $(seq 1 $repeatCount); do
                # part to control the middleware -- mw private IPs : machine4 - 10.0.0.8 , machine5- 10.0.0.9 (+4 from machine number -- coincidental)
                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    screen -d -m -S mw bash -c "java -jar ${remoteHome}/${dirNameMw}/dist/middleware-ccikis.jar -l 10.0.0.$((${IDmw} + 4)) -p ${middlewarePort} -t ${t} -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort} ${prefix}${IDservers[1]}${suffix}:${serverPort}"
                    # wait until middlewares are safely initialized
                    sleep ${mwStartSafetyTime}
# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait


                # part to control the clients
                for IDc in "${IDclients[@]}"; do
                (
                    ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                    screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${pingFileName}.${pingFileExtension}"
                    screen -d -m -S pinger_${IDmws[1]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[1]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${r}_${pingFileName}.${pingFileExtension}"

                    screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${reportFileName}.${reportFileExtension}"
                    screen -d -m -S memtier_${IDmws[1]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[1]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${r}_${reportFileName}.${reportFileExtension}"
                    
                    sleep $((${testTime}+${testSafetyTime}))

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait
                

                # close middlewares
                for IDmw in "${IDmws[@]}"; do
                (
                    { echo "shutdown"; } | telnet ${prefix}${IDmw}${suffix} ${middlewarePort}
                    # wait for logs to be produced
                    sleep ${mwLoggingSafetyTime}
                ) &
                done
                wait

                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}
                    
                    mv ${remoteHome}/${mwQueueFileName}.${mwQueueFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwQueueFileName}.${mwQueueFileExtension}

                    mv ${remoteHome}/${mwRequestFileName}.${mwRequestFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwRequestFileName}.${mwRequestFileExtension}
                    

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &             
                done
                wait
            done
        done
    done
done




experimentName="experiment5"
partName="part3_3s_1mw"

IDservers=(6 7 8)
IDmws=(4)
IDclients=(1 2 3)

memtierThreadCount=1
virtualClientCount=(32)     # 64 clients per machine
workerThreadCount=(8 32)

serverPort=11211
middlewarePort=16399

sharded="false"

modeName=("writeonly", "readonly", "50-50")
modeRatio=("1:0", "0:1", "1:1")



for c in "${virtualClientCount[@]}"; do
    for t in "${workerThreadCount[@]}"; do
        for modeIndex in {0..2}; do
            for r in $(seq 1 $repeatCount); do
                # part to control the middleware -- mw private IPs : machine4 - 10.0.0.8 , machine5- 10.0.0.9 (+4 from machine number -- coincidental)
                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    screen -d -m -S mw bash -c "java -jar ${remoteHome}/${dirNameMw}/dist/middleware-ccikis.jar -l 10.0.0.$((${IDmw} + 4)) -p ${middlewarePort} -t ${t} -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort} ${prefix}${IDservers[1]}${suffix}:${serverPort} ${prefix}${IDservers[2]}${suffix}:${serverPort}"
                    # wait until middlewares are safely initialized
                    sleep ${mwStartSafetyTime}
# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait


                # part to control the clients
                for IDc in "${IDclients[@]}"; do
                (
                    ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                    screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${pingFileName}.${pingFileExtension}"

                    screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${reportFileName}.${reportFileExtension}"
                    
                    sleep $((${testTime}+${testSafetyTime}))

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait
                

                # close middlewares
                for IDmw in "${IDmws[@]}"; do
                (
                    { echo "shutdown"; } | telnet ${prefix}${IDmw}${suffix} ${middlewarePort}
                    # wait for logs to be produced
                    sleep ${mwLoggingSafetyTime}
                ) &
                done
                wait

                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}
                    
                    mv ${remoteHome}/${mwQueueFileName}.${mwQueueFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwQueueFileName}.${mwQueueFileExtension}

                    mv ${remoteHome}/${mwRequestFileName}.${mwRequestFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwRequestFileName}.${mwRequestFileExtension}
                    

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &             
                done
                wait
            done
        done
    done
done




experimentName="experiment5"
partName="part4_3s_2mw"

IDservers=(6 7 8)
IDmws=(4 5)
IDclients=(1 2 3)

memtierThreadCount=1
virtualClientCount=(32)     # 64 clients per machine
workerThreadCount=(8 32)

serverPort=11211
middlewarePort=16399

sharded="false"

modeName=("writeonly", "readonly", "50-50")
modeRatio=("1:0", "0:1", "1:1")



for c in "${virtualClientCount[@]}"; do
    for t in "${workerThreadCount[@]}"; do
        for modeIndex in {0..2}; do
            for r in $(seq 1 $repeatCount); do
                # part to control the middleware -- mw private IPs : machine4 - 10.0.0.8 , machine5- 10.0.0.9 (+4 from machine number -- coincidental)
                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    screen -d -m -S mw bash -c "java -jar ${remoteHome}/${dirNameMw}/dist/middleware-ccikis.jar -l 10.0.0.$((${IDmw} + 4)) -p ${middlewarePort} -t ${t} -s ${sharded} -m ${prefix}${IDservers[0]}${suffix}:${serverPort} ${prefix}${IDservers[1]}${suffix}:${serverPort} ${prefix}${IDservers[2]}${suffix}:${serverPort}"
                    # wait until middlewares are safely initialized
                    sleep ${mwStartSafetyTime}
# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait


                # part to control the clients
                for IDc in "${IDclients[@]}"; do
                (
                    ssh -T ${prefix}${IDc}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}

                    screen -d -m -S pinger_${IDmws[0]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[0]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${pingFileName}.${pingFileExtension}"
                    screen -d -m -S pinger_${IDmws[1]} bash -c "{ ping -w $((${testTime}+${pingSafetyTime})) -i ${pingInterval} ${prefix}${IDmws[1]}${suffix}; } > ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${r}_${pingFileName}.${pingFileExtension}"

                    screen -d -m -S memtier_${IDmws[0]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[0]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[0]}_${r}_${reportFileName}.${reportFileExtension}"
                    screen -d -m -S memtier_${IDmws[1]} bash -c "${remoteHome}/memtier_benchmark-master/memtier_benchmark --server=${prefix}${IDmws[1]}${suffix} --port=${middlewarePort} --protocol=memcache_text --threads=${memtierThreadCount} --clients=${c} --test-time=${testTime} --ratio=${modeRatio[$modeIndex]} --expiry-range=${expiryRange} --key-maximum=${keyMaximum} --hide-histogram --out-file=${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDc}_${IDmws[1]}_${r}_${reportFileName}.${reportFileExtension}"
                    
                    sleep $((${testTime}+${testSafetyTime}))

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
                ) &
                done
                wait
                

                # close middlewares
                for IDmw in "${IDmws[@]}"; do
                (
                    { echo "shutdown"; } | telnet ${prefix}${IDmw}${suffix} ${middlewarePort}
                    # wait for logs to be produced
                    sleep ${mwLoggingSafetyTime}
                ) &
                done
                wait

                for IDmw in "${IDmws[@]}"; do
                (
                    ssh ${prefix}${IDmw}${suffix} << EOSSH 
                    mkdir -p ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}
                    
                    mv ${remoteHome}/${mwQueueFileName}.${mwQueueFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwQueueFileName}.${mwQueueFileExtension}

                    mv ${remoteHome}/${mwRequestFileName}.${mwRequestFileExtension} ${remoteHome}/${dirName}/${experimentName}/${partName}/${modeName[$modeIndex]}/${c}_${t}_${IDmw}_${r}_${mwRequestFileName}.${mwRequestFileExtension}
                    

# EOSHH - heredoc tag should be on a seperate line by itself(without any leading or trailing spaces)
EOSSH
) &             
                done
                wait
            done
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















remoteHome="/home/can"
localpchome="/home/can/asl-experiments"

prefix="canforaslvms"
suffix=".westeurope.cloudapp.azure.com"

dirName="asl-experiments"

IDservers=(6 7 8)
IDmws=(4 5)
IDclients=(1 2 3)


# rsync - trailing "/" copies the ocntents of the folder
# GET CLIENT LOGS
for IDc in "${IDclients[@]}"; do
    rsync -avzhe ssh can@${prefix}${IDc}${suffix}:${remoteHome}/${dirName}/ ${localpchome}        # –remove-source-files
done
wait

# GET MW LOGS
for IDmw in "${IDmws[@]}"; do
    rsync -avzhe ssh can@${prefix}${IDmw}${suffix}:${remoteHome}/${dirName}/ ${localpchome}
done
wait

# GET SERVER LOGS
for IDs in "${IDservers[@]}"; do
    rsync -avzhe ssh can@${prefix}${IDs}${suffix}:${remoteHome}/${dirName}/ ${localpchome}
done
wait












remoteHome="/home/can"

prefix="canforaslvms"
suffix=".westeurope.cloudapp.azure.com"

dirName="asl-experiments"

IDall=(1 2 3 4 5 6 7 8)

# REMOVE ALL LOGS
for IDa in "${IDall[@]}"; do
(
    ssh ${prefix}${IDa}${suffix} << EOSSH 
    rm -rf ${remoteHome}/${dirName}/

EOSSH
) &
done
wait











