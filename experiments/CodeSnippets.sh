
ssh canforaslvms9.westeurope.cloudapp.azure.com
screen -S coordinator
./RunExperiments.sh


vim RunExperiments.sh
sudo chmod +x RunExperiments.sh


10.0.0.8
10.0.0.9

java -jar asl-fall17-project/dist/middleware-ccikis.jar -l 10.0.0.8 -p 16399 -t 64 -s false -m canforaslvms6.westeurope.cloudapp.azure.com:11211
java -jar asl-fall17-project/dist/middleware-ccikis.jar -l 10.0.0.9 -p 16399 -t 64 -s false -m canforaslvms6.westeurope.cloudapp.azure.com:11211

./memtier_benchmark --port=16399 --protocol=memcache_text --ratio=1:0 --expiry-range=9999-10000 --key-maximum=1000 --hide-histogram --server canforaslvms4.westeurope.cloudapp.azure.com --test-time=10 --clients=16 --threads=2




# FETCH LOGS
remoteHome="/home/can"
localpchome="/media/sf_Ubuntu_Share/asl-experiments"

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






# REMOVE ALL LOGS
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


