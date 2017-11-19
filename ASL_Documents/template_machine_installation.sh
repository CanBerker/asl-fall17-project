sudo add-apt-repository ppa:openjdk-r/ppa  
sudo apt-get update
sudo apt-get install git unzip ant openjdk-7-jdk 
# removed memcached
wget https://github.com/RedisLabs/memtier_benchmark/archive/master.zip 
unzip master.zip 
cd  memtier_benchmark-master 
sudo apt-get install build-essential autoconf automake libpcre3-dev libevent-dev pkg-config zlib1g-dev 
autoreconf -ivf 
./configure 
make 
# sudo service memcached stop

mkdir -p memcached_install
cd memcached_install
wget http://www.memcached.org/files/memcached-1.5.2.tar.gz
tar -zxvf memcached-1.5.2.tar.gz
cd memcached-1.5.2
./configure && make && make test && sudo make install

