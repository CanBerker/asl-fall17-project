# asl-fall17-project

ASL_Documents has the original project documents.

Get memcached from following link:
https://memcached.org/downloads

Get memtier from the following link:
https://github.com/RedisLabs/memtier_benchmark/


* Run the benchmark tool with:

	* Only gets:
	```
	memtier_benchmark --port=11211 --protocol=memcache_text --ratio=0:1 --expiry-range=9999-10000 --key-maximum=1000 --hide-histogram --server 127.0.0.1 --test-time=5 --clients=50 --threads=4
	```

	* Only sets:
	```
	memtier_benchmark --port=11211 --protocol=memcache_text --ratio=1:0 --expiry-range=9999-10000 --key-maximum=1000 --hide-histogram --server 127.0.0.1 --test-time=1 --clients=1 --threads=1
	```

	* Balanced operations with added histogram:  
	```
	memtier_benchmark --port=11211 --protocol=memcache_text --ratio=1:1 --expiry-range=9999-10000 --key-maximum=1000 --server 127.0.0.1 --test-time=1 --clients=1 --threads=1
	```



Start server with custom port and verbose mode:
```
memcached -p 11211 -vv
```

Memcached and memtier example using terminal can be found in the following link:  
https://www.kutukupret.com/2011/05/05/memcached-in-a-shell-using-nc-and-echo/



Clean and create the jar file:
```
ant clean
ant jar
```


Run the jar file with default parameters:  
```
java -jar dist/middleware-ccikis.jar  -l 127.0.0.1 -p 16399 -t 13 -s false -m 127.0.0.1:11211 127.0.0.1:11212
```


Multi-Get Demo:
```
echo -e 'set memtier-696 0 10000 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211
echo -e 'set memtier-670 0 10000 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211
echo -e 'set memtier-979 0 10000 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211
echo -e 'set memtier-824 0 10000 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211
echo -e 'set memtier-589 0 9999 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211
echo -e 'set memtier-690 0 9999 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211
echo -e 'set memtier-567 0 10000 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211
echo -e 'set memtier-687 0 10000 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211
echo -e 'set memtier-397 0 10000 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211
echo -e 'set memtier-574 0 10000 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211
echo -e 'set memtier-92 0 9999 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r' | nc localhost 11211

echo -e 'get memtier-696 memtier-670 memtier-979 memtier-824 memtier-589 memtier-690 memtier-567 memtier-687 memtier-397 memtier-574 memtier-92\r' | nc localhost 11211

```
