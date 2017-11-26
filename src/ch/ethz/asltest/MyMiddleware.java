package ch.ethz.asltest;

import java.io.*;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.nio.channels.ServerSocketChannel;
import java.nio.channels.SocketChannel;
import java.nio.charset.Charset;
import java.util.*;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.regex.Pattern;


public class MyMiddleware {

    // Variables are defined as protected to be used in subclasses
    protected String myIp;
    protected int networkPort;
    protected static List<String> mcAddresses;
    protected int numThreadsPTP;
    protected static boolean readSharded;
    protected static boolean shutdownReceived;
    protected static long timestampSimplifier;
    protected static boolean braceYourselvesRequestsAreComing;

    protected static NetworkThread netThread;
    protected static BlockingQueue<Request> requestsQueue;
    protected static QueueLengthLogger queueLengthLogger;
    protected static List<WorkerThread> workerThreads;


    public MyMiddleware() {
    }

    public MyMiddleware(String myIp, int networkPort, List<String> mcAddresses, int numThreadsPTP, boolean readSharded)
    {
        this.myIp = myIp;
        this.networkPort = networkPort;
        this.mcAddresses = mcAddresses;
        this.numThreadsPTP = numThreadsPTP;
        this.readSharded = readSharded;
        this.shutdownReceived = false;
        this.timestampSimplifier = 0;       // simplifier is subtracted from all timestamps in the program to shorten the numbers that have higher accuracy than neeeded

        this.netThread = new NetworkThread(myIp, networkPort);
        this.queueLengthLogger = new QueueLengthLogger("queueLengthLog.csv", 1000);
        this.requestsQueue = new LinkedBlockingQueue<>();
        this.workerThreads = new ArrayList<>();
    }

    public void run() {
        try {
            // TODO: log hit/miss ratio for gets

            logStartTime("startTime.txt");
            netThread.start();
            queueLengthLogger.start();
            startWorkerThreads();

        } catch(Exception e) {
            e.printStackTrace();
        } finally {

        }
    }

    /**
     * Initializes the timestamp simplifier
     * Logs the starting time of the program     *
     * Logging is currently disabled as start time can be inferred from queuelengthlogger's first entry
     * @param fileName      File to log
     */
    private void logStartTime(String fileName) {

        long startTime = System.currentTimeMillis();
        this.timestampSimplifier = getSimplifier(startTime);
        /*
        try {
            BufferedWriter writer = new BufferedWriter(new FileWriter(fileName));
            long startTime = System.currentTimeMillis();
            this.timestampSimplifier = getSimplifier(startTime);
            writer.write(Long.toString(getTimeStamp()));

            //writer.append("");

            writer.flush();
            writer.close();
        } catch(IOException e) {
            System.out.println("LOG: logStartTime: Couldn't open log file.");
            e.printStackTrace();
        }
        */
    }

    /**
     * This function calculates the timestamp simplifier which is used to shorten the numbers returned by System.currentTimeMillis()
     * The static method System.currentTimeMillis() returns the time since January 1st 1970 in milliseconds.
     * An average experiment lasts around 60 seconds, so saving the results in the precision of 1000 seconds = 10000000 milliseconds is sufficient
     * Setting this number as the simplification rate, the number is rounded.
     *      Rounding down to neaest 100 -> i = i/100 * 100
     * This simplifier is then subtracted from all the other timestamps in the program
     *
     * @return long simplifier
     */
    private long getSimplifier(long startTime) {

        int simplificationStep = 1000000;
        long simplifier = (startTime / simplificationStep) * simplificationStep;
        return simplifier;
    }

    /**
     * Get current timestamp in the system simplified to the accuracy of 100 seconds
     * @return  long timestamp
     */
    private static long getTimeStamp() {
        return System.currentTimeMillis() - timestampSimplifier;
    }


    /**
     * Seperate thread running periodic checks to log the queuelength
     */
    private static class QueueLengthLogger extends Thread {
        BufferedWriter writer;          // file to log the file
        long periodInMs;                // period in miliseconds

        /**
         * Constructor Function
         * @param fileName      name of the log file
         * @param periodInMs    period between two logging instances in milliseconds
         */
        public QueueLengthLogger(String fileName, long periodInMs)
        {
            try {
                this.writer = new BufferedWriter(new FileWriter(fileName));
                writer.write("Timestamp, QueueLength, Active\n");
                this.periodInMs = periodInMs;
            } catch(IOException e) {
                System.out.println("LOG: QueueLengthLogger: Couldn't open log file.");
                e.printStackTrace();
            }
        }

        public void run() {
            try {
                while (shutdownReceived == false) {
                    String queueLog;
                    if(braceYourselvesRequestsAreComing == false) {
                        queueLog = Long.toString(getTimeStamp()) + ", " + Integer.toString(requestsQueue.size()) + ", false" + "\n";
                    }
                    else {
                        queueLog = Long.toString(getTimeStamp()) + ", " + Integer.toString(requestsQueue.size()) + ", true" + "\n";
                    }
                    writer.append(queueLog);
                    Thread.sleep(periodInMs);
                }
            } catch (IOException e) {
                System.out.println("LOG: QueueLengthLogger: Couldn't write to log file.");
                e.printStackTrace();
            } catch (InterruptedException e) {
                e.printStackTrace();
            } finally {
                closeThread();
            }

        }

        private void closeThread() {
            try {
                writer.flush();
                writer.close();
            } catch(IOException e) {
                System.out.println("LOG: NetworkThread: Error while closing sockets.");
                e.printStackTrace();
            }
        }
    }

    /**
     * The thread that receives all connections over input port
     */
    private static class NetworkThread extends Thread {
        private String myIP;
        private int networkPort;
        private Selector selector;
        ServerSocketChannel networkSocket;

        /**
         * Default constructor
         * @param myIP      ip of the machine running the middlware
         * @param networkPort       the port that the middleware listens on
         */
        public NetworkThread(String myIP, int networkPort) {
            this.myIP = myIP;
            this.networkPort = networkPort;
        }

        public void run() {
            try {
                selector =  Selector.open();
                networkSocket = ServerSocketChannel.open();
                InetAddress IP = InetAddress.getByName(myIP);
                networkSocket.bind(new InetSocketAddress(IP, networkPort));
                networkSocket.configureBlocking(false);
                networkSocket.register(selector, SelectionKey.OP_ACCEPT);
                ByteBuffer buffer = ByteBuffer.allocate(2048);  // israf vol 1 :D

                // Charset charset = Charset.forName("ISO-8859-1");
                // Charset charset = Charset.forName("UTF-8");

                int clientIndex = 0;
                String inputLine = "";

                int readyChannels = 0;

                System.out.println("Network Thread: Listening ...");
                while(shutdownReceived == false) {
                    if (selector.isOpen()) {
                        readyChannels = selector.select();
                        if (readyChannels == 0) {
                            continue;
                        } else {
                            Set selectedKeys = selector.selectedKeys();
                            Iterator iter = selectedKeys.iterator();
                            while (iter.hasNext()) {
                                SelectionKey key = (SelectionKey) iter.next();      // casting to selection key for syntax correctness

                                // check if key is valid first to account for key cancelling.
                                if (!key.isValid()) {
                                    continue;
                                } else if (key.isAcceptable()) {
                                    SocketChannel client = networkSocket.accept();
                                    client.configureBlocking(false);
                                    client.register(selector, SelectionKey.OP_READ, clientIndex++);     // attach a client index integer as an object
                                } else if (key.isReadable()) {
                                    SocketChannel client = (SocketChannel) key.channel();
                                    int clientID = (int) key.attachment();      // get the client ID from attachment of the key
                                    int numBytesRead = client.read(buffer);

                                    // if end of stream is received, bytes read is set to -1 meaning socket has been closed(shouldn't happen in a normal run)
                                    if (numBytesRead != -1) {
                                        inputLine += new String(buffer.array(), 0, numBytesRead, Charset.forName("UTF-8"));

                                        // keep reading if the shutdown isn't sent and full packet ending in \r\n hasn't been received yet
                                        while (!inputLine.startsWith("shutdown") && !inputLine.substring(inputLine.length() - 2, inputLine.length()).equals("\r\n")) {
                                            numBytesRead = client.read(buffer);
                                            inputLine += new String(buffer.array(), 0, numBytesRead, Charset.forName("UTF-8"));
                                        }

                                        if (inputLine.startsWith("shutdown")) {
                                            Thread.sleep(3000);     // let other threads finish their jobs

                                            shutdownReceived = true;
                                            String fileName = "requestLog.csv";
                                            BufferedWriter writer = new BufferedWriter(new FileWriter(fileName));
                                            writer.write("RequestType, WorkerIndex, RequestSize, ResponseSize, QueueTime, DequeueTime, SendTime, ReceiveTime, ClientResponseTime\n");

                                            for (int i = 0; i < workerThreads.size(); i++) {
                                                WorkerThread wt = workerThreads.get(i);
                                                writer.append(wt.logBuilder.toString());     // write to file

                                                requestsQueue.add(new Request("shutdown"));     // add a shutdown command for each worker thread
                                            }

                                            writer.flush();
                                            writer.close();

                                            break;
                                        } else if (inputLine.substring(inputLine.length() - 2, inputLine.length()).equals("\r\n")) {
                                            inputLine = inputLine.trim();       // remove leading and trailing whitespaces and newlines
                                            String[] requestParts = inputLine.split(" ");       // split the request and get the requestType
                                            String requestType = requestParts[0];

                                            Request request;
                                            if (requestType.equals("get")) {
                                                request = new Request(clientID, inputLine, "GET", client, getTimeStamp());
                                            } else {
                                                // read the payload line
                                                String[] setParts = inputLine.split(Pattern.quote("\r\n"));   // with telnet split at \\ instead of \ before r and n
                                                String message = setParts[0];
                                                String payload = setParts[1];
                                                request = new Request(clientID, message, "SET", payload, client, getTimeStamp());
                                            }

                                            requestsQueue.add(request);
                                            inputLine = "";     // reset the inputline
                                        } else {
                                            System.out.println("LOG: NetworkThread: Fragmented packet couldn't be recovered");
                                        }
                                    } else {
                                        key.cancel();
                                        client.close();
                                    }

                                    buffer.clear();
                                }
                                iter.remove();
                            }
                        }
                    }
                }
            } catch(IOException e) {
                System.out.println("LOG: NetworkThread: Server socket failed to accept connection.");
                e.printStackTrace();
            } catch(StringIndexOutOfBoundsException e) {
                System.out.println("LOG: NetworkThread: String operation failed due to indexing error.");
                e.printStackTrace();
            } catch(Exception e) {
                System.out.println("LOG: NetworkThread: Exception.");
                e.printStackTrace();
            } finally {
                closeThread();
            }
        }

        /**
         * Network socket and selector is closed
         */
        private void closeThread() {
            try {
                networkSocket.close();
                selector.close();
            } catch(IOException e) {
                System.out.println("LOG: NetworkThread: Error while closing sockets.");
                e.printStackTrace();
            }
        }
    }

    /**
     * starts the parametrized number of worker threads
     */
    private void startWorkerThreads() {
        for(int threadCount = 0; threadCount < numThreadsPTP; threadCount++) {
            WorkerThread wt = new WorkerThread();
            workerThreads.add(wt);
            wt.start();
        }
    }

    /**
     * The threads that handle the making of requests and forwarding of responses for SET, GET, MULTI-GET operations
     * Also LOGGING is implemented during request processing
     */
    private static class WorkerThread extends Thread {
        private List<Socket> serverSockets;             // keep server sockets, writers and readers in seperate lists
        private List<PrintWriter> serverWriters;
        private List<BufferedReader> serverReaders;
        private static int currentIndex= -1;
        private int workerIndex;
        private StringBuilder logBuilder;
        private StringBuilder rowBuilder;

        /**
         * Returns the index assigned to the worker thread
         * @return
         */
        public int getWorkerIndex(){
            return this.workerIndex;
        }

        /**
         * Preprend the given string to the current log row
         * @param str   string to prepend
         */
        public void prependLogString(String str) {
            this.rowBuilder.insert(0, str);
        }

        /**
         * Append the given string to the current log row
         * @param str   string to append
         */
        public void appendLogString(String str) {
            this.rowBuilder.append(str);
        }

        /**
         * Inserts the given string at the index (seperated by commas)
         * @param str   string to be inserted
         * @param index index of the field to insert (for zero, use prepend function)
         */
        public void insertLogString(String str, int index) {
            int commaIndex = nthIndexOf(this.rowBuilder.toString(), ",", index);      // get the index of nth ","
            this.rowBuilder.insert(commaIndex+2, str);  // skip over the comma and the space with (+2)
        }

        /**
         * Default constructor
         * Assigns worker index, creates log builders, initializes read-write connections between the middleware and the servers
         */
        public WorkerThread() {
            try
            {
                this.workerIndex = ++this.currentIndex;
                this.logBuilder = new StringBuilder();
                this.rowBuilder = new StringBuilder();

                this.serverSockets = new ArrayList<>();
                this.serverWriters = new ArrayList<>();
                this.serverReaders = new ArrayList<>();
                for(String address : mcAddresses) {
                    String[] addressParts = address.split(":", 2);       // split the IP and port values at the first ":"(limit:2)
                    String ip = addressParts[0];
                    int port = Integer.parseInt(addressParts[1]);           // cast port to integer

                    // System.out.println(ip + " " + port);

                    Socket serverSocket = new Socket(ip,port);
                    this.serverSockets.add(serverSocket);

                    this.serverWriters.add(new PrintWriter(serverSocket.getOutputStream(), true));
                    this.serverReaders.add(new BufferedReader(new InputStreamReader(serverSocket.getInputStream())));
                }
            }
            catch(IOException e) {
                System.out.println("LOG: Worker Thread: Error while creating sockets to servers.");
                e.printStackTrace();
            }
        }

        /**
         * SET operation is forwarded to all servers
         * @param message   full message of the request
         * @param payload   payload data of the request
         * @return          response of the server
         */
        public String setOperation(String message, String payload) {
            try {
                int serverCount = mcAddresses.size();
                long sendTimeAverage = 0;
                // Forward the SET request to all servers
                for(int serverIndex = 0; serverIndex < serverCount; serverIndex++) {
                    serverWriters.get(serverIndex).println(message + "\r\n" + payload + "\r");  // forward message to server(\r is used instead of \r\n due to println function)
                    sendTimeAverage += getTimeStamp();
                }
                appendLogString(Long.toString(sendTimeAverage/serverCount) + ", ");    // log averaged send time

                long receiveTimeAverage = 0;
                String finalServerResponse = "STORED";
                String serverResponse = "";
                for(int serverIndex = 0; serverIndex < serverCount; serverIndex++) {
                    receiveTimeAverage += getTimeStamp();
                    serverResponse = serverReaders.get(serverIndex).readLine();          // read server's response(single and short message)
                    // if a server has failed to store the value
                    if(!serverResponse.equals("STORED")) {
                        finalServerResponse = serverResponse;
                    }
                }
                appendLogString(Long.toString(receiveTimeAverage/serverCount) + ", ");    // log averaged receive time

                /*
                if(finalServerResponse.equals("STORED")) {
                    insertLogString(Integer.toString(0) + ", ", 2);
                } else {
                    insertLogString(Integer.toString(1) + ", ", 2);             // log if there is an error
                }
                */

                // if finalServerResponse weren't changed values were stored successfully
                return finalServerResponse;
            }  catch(IOException e) {
                System.out.println("LOG: Worker Thread - Set Operation : Error occurred during read/write operation with server socket.");
                e.printStackTrace();
                return "EXCEPTION";
            }
        }

        /**
         * GET request if forwarded to only one server if sharding is not enabled or number of keys is 1
         * @param message       full message of the request
         * @param roundRobinServerIndex     server index to give the request to
         * @return              response of the server
         */
        public String getOperation(String message, int roundRobinServerIndex) {
            try {
                // Forward the GET request to the server with the given round robin index
                serverWriters.get(roundRobinServerIndex).println(message + "\r");      // forward request to server, println adds the "\n"
                appendLogString(Long.toString(getTimeStamp()) + ", ");      // get is sent to a single server, directly log the send time

                String serverResponse;
                StringBuilder builder = new StringBuilder();
                while((serverResponse = serverReaders.get(roundRobinServerIndex).readLine()) != null) {
                    builder.append(serverResponse);
                    // append responses until "END" message is received
                    if(!serverResponse.equals("END")) {
                        builder.append("\r\n");
                    }
                    else {
                        break;
                    }
                }
                appendLogString(Long.toString(getTimeStamp()) + ", ");      // once the whole get operation from the server is completed, log the receive time.
                return builder.toString();
            }  catch(IOException e) {
                System.out.println("LOG: Worker Thread - Get Operation : Error occurred during read/write operation with server socket.");
                e.printStackTrace();
                return "EXCEPTION";
            }
        }

        /**
         * MULTI-GET(sharded) shard the get command into multiple requests to different servers, collect the results and evaluate together
         * since all servers get one request each, roundRobinServerIndex is not updated globally
         * @param message       full message of the request
         * @param roundRobinServerIndex     server index to give the first request to
         * @return              response of the server
         */
        public String shardedMultiGetOperation(String message, int roundRobinServerIndex) {
            try {

                String[] messageParts = message.split(" ", 2);          // split the message at the first space
                String keyParts = messageParts[1];                                 // second half are keys
                String[] keys = keyParts.split(" ");                         // split keys on " " and take action based on number of keys and sharding option

                int serverCount = mcAddresses.size();
                int totalKeyCount = keys.length;
                int keysPerServer =(int)Math.floor(keys.length/serverCount);
                int remainingkeyCount = totalKeyCount % serverCount;
                int totalKeyIndex = 0;       // index used while iterating over the keys array

                long sendTimeAverage = 0;
                // assign the ~same number of keys to each server(rounded) up and send the requests
                for(int serverIndex = 0; serverIndex < serverCount; serverIndex++) {
                    int serverKeyCount = keysPerServer;
                    if(remainingkeyCount != 0) {
                        serverKeyCount += 1;
                        remainingkeyCount -= 1;
                    }

                    StringBuilder builder = new StringBuilder("get ");
                    for(int keyIndex = 0; keyIndex < serverKeyCount; keyIndex++) {
                        builder.append(keys[totalKeyIndex]);
                        builder.append(" ");        // tested: last " " before the "\r" doesn't cause any issues
                        totalKeyIndex++;
                    }

                    int selectedServer =(roundRobinServerIndex+serverIndex) % serverCount;     // roundRobin pointer goes to first server after using the last server

                    // Forward the GET request to the server with the given round robin index
                    serverWriters.get(selectedServer).println(builder.toString() + "\r");
                    sendTimeAverage += getTimeStamp();
                }
                appendLogString(Long.toString(sendTimeAverage/serverCount) + ", ");    // log averaged send time

                long receiveTimeAverage = 0;
                StringBuilder builder = new StringBuilder();
                for(int serverIndex = 0; serverIndex < serverCount; serverIndex++) {
                    int selectedServer =(roundRobinServerIndex+serverIndex) % serverCount;     // roundRobin pointer goes to first server after using the last server
                    String serverResponse;
                    while((serverResponse = serverReaders.get(selectedServer).readLine()) != null) {
                        // append responses until "END" message is received
                        if(!serverResponse.equals("END")) {
                            builder.append(serverResponse);
                            builder.append("\r\n");
                        }
                        else {
                            break;  // do nothing
                        }
                    }
                    receiveTimeAverage += getTimeStamp();           // once the whole get operation from a server is completed, log the receive time.
                }
                appendLogString(Long.toString(receiveTimeAverage/serverCount) + ", ");    // log averaged receive time
                builder.append("END");
                return builder.toString();
            }  catch(IOException e) {
                System.out.println("LOG: Worker Thread - Get Operation : Error occurred during read/write operation with server socket.");
                e.printStackTrace();
                return "EXCEPTION";
            }
        }


        public void run() {
            try {
                Request request;
                int roundRobinServerIndex = 0;      // server index for round robin load balancing
                while(shutdownReceived == false &&(request = requestsQueue.take()) != null)     // read the next request from the requests queue
                {
                    if (braceYourselvesRequestsAreComing == false)
                    {
                        braceYourselvesRequestsAreComing = true;
                    }

                    if(request.isShutdown() == true) {
                        continue;
                    }
                    else {
                        this.rowBuilder.setLength(0);   // reset rowbuilder

                        appendLogString(Integer.toString(this.workerIndex) + ", ");           // log WorkerIndex
                        appendLogString(Long.toString(request.getReceiveTime()) + ", ");      // log QueueTime
                        appendLogString(Long.toString(getTimeStamp()) + ", ");    // log DequeueTime

                        int clientID = request.getClientID();       // get the ID of the client who has sent the request
                        String message = request.getMessage();      // get the original request of memtier(client)
                        String requestType = request.getRequestType();

                        String serverResponse = "";
                        int requestKeyCount;

                        // use requestType to determine the action to take
                        // SET Format: set memtier-696 0 10000 32\r\nxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\r\n
                        // GET Format: get memtier-696 memtier-670\r\n
                        if(requestType.equals("SET")) {
                            prependLogString(Integer.toString(0) + ", ");           // log requestType
                            insertLogString(Integer.toString(0) + ", ", 2);          // log request keyCount, 0 for sets
                            serverResponse = setOperation(message, request.getPayload());
                        } else if(requestType.equals("GET")) {
                            requestKeyCount = count(message, " ");              // number of spaces in request = number of keys in request
                            if(readSharded == false || requestKeyCount == 1) {
                                prependLogString(Integer.toString(1) + ", ");           // log requestType
                                insertLogString(Integer.toString(requestKeyCount) + ", ", 2);           // log request key count
                                serverResponse = getOperation(message, roundRobinServerIndex);
                            } else {
                                prependLogString(Integer.toString(2) + ", ");           // log requestType
                                insertLogString(Integer.toString(requestKeyCount) + ", ", 2);           // log request key count
                                serverResponse = shardedMultiGetOperation(message, roundRobinServerIndex);
                            }
                        } else {
                            // refuse unrecognized requestType
                            System.out.println("Unrecognized Command. Waiting for a newline to reinitialize.");
                            // TODO: Log the unrecognized command. Discard all input until a newline arrives.
                        }

                        // if a proper client request command is found and an according response is received from the server(either succesfull or failed)
                        if(!serverResponse.equals("")) {
                            // TODO: Handle the return of "EXCEPTION" as serverResponse
                            if(serverResponse.equals("EXCEPTION")) {
                                // do nothing
                                appendLogString("-999\n");          // log ClientResponseTime - in the case of exception log a negative value
                            }
                            else {

                                // responses to set requests are 1 liners - no "\r\n
                                // responses to gets/multi-gets contain 2 rows for each key and a row with only "END" at the end
                                int responseKeyCount = (count(serverResponse, "\r\n")) / 2;
                                insertLogString(Integer.toString(responseKeyCount) + ", ", 3);

                                appendLogString(Long.toString(getTimeStamp()) + "\n");  // log ClientResponseTime

                                // forward the server response to client
                                serverResponse = serverResponse + "\r\n";
                                ByteBuffer buffer = ByteBuffer.wrap(serverResponse.getBytes());
                                SocketChannel channel = request.getChannel();
                                try {
                                    channel.write(buffer);
                                } catch (IOException e) {
                                    e.printStackTrace();
                                }

                                this.logBuilder.append(this.rowBuilder.toString());     // add the line to the total log
                            }

                            // increment the round robin index and take modulo with number of servers
                            roundRobinServerIndex =(roundRobinServerIndex + 1) % mcAddresses.size();
                        }
                    }
                }
            } catch(InterruptedException e) {
                System.out.println("LOG: Worker Thread: Error while reading from the requests queue.");
                e.printStackTrace();
            } finally {
                closeThread();
            }
        }

        /**
         * Middlware - Server sockets are closed
         */
        private void closeThread() {
            try {
                for(int arrayIndex = 0; arrayIndex < serverSockets.size(); arrayIndex++) {
                    serverReaders.get(arrayIndex).close();
                    serverWriters.get(arrayIndex).close();
                    serverSockets.get(arrayIndex).close();
                }
            } catch(IOException e) {
                System.out.println("LOG: WorkerThread: Error while closing readers, writers or sockets.");
                e.printStackTrace();
            }
        }
    }

    /**
     * Return the <i>nth</i> index of the given token occurring in the given string.
     *
     * @param string     String to search.
     * @param token      Token to match.
     * @param index      <i>Nth</i> index.
     * @return           Index of <i>nth</i> item or -1.
     */
    public static int nthIndexOf(final String string, final String token, final int index) {
        int j = 0;
        for (int i = 0; i < index; i++)
        {
            j = string.indexOf(token, j + 1);
            if (j == -1) break;
        }
        return j;
    }

    /**
     * Count the number of instances of substring within a string.
     *
     * @param string     String to look for substring in.
     * @param substring  Sub-string to look for.
     * @return           Count of substrings in string.
     */
    public static int count(final String string, final String substring)
    {
        int count = 0;
        int idx = 0;

        while ((idx = string.indexOf(substring, idx)) != -1)
        {
            idx++;
            count++;
        }

        return count;
    }

}
