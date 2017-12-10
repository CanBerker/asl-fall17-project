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

testTime=60
pingInterval=1

mwStartSafetyTime=8
pingSafetyTime=2
testSafetyTime=2
mwLoggingSafetyTime=6



experimentName="experiment2"
partName="part3"

IDservers=(6)
IDmws=(4 5)
IDclients=(1 2)

memtierThreadCount=1
virtualClientCount=(1 8 16 24 32 64 96)
workerThreadCount=(8 16 32 64)

serverPort=11211
middlewarePort=16399

sharded="false"


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





# close memcached at servers
for IDs in "${IDservers[@]}"; do
(
    { echo "shutdown"; } | telnet ${prefix}${IDs}${suffix} 11211
) &
done
wait





remoteHome="/home/can"
localpchome="/home/can/can-test"

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




