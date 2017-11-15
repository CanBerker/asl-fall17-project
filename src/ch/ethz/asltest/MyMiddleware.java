package ch.ethz.asltest;

import java.io.*;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
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

    protected static NetworkThread netThread;
    protected static BlockingQueue<Request> requestsQueue;
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

        this.netThread = new NetworkThread(myIp, networkPort);
        this.requestsQueue = new LinkedBlockingQueue<>();
        this.workerThreads = new ArrayList<>();
    }

    public void run() {
        try {
            netThread.start();
            startWorkerThreads();

        } catch (Exception e) {

            e.printStackTrace();
        } finally {

        }
    }


    private static class NetworkThread extends Thread {
        private String myIP;
        private int networkPort;
        private Selector selector;
        ServerSocketChannel networkSocket;
        private boolean shutdownReceived;

        public NetworkThread(String myIP, int networkPort)
        {
            this.myIP = myIP;
            this.networkPort = networkPort;
            this.shutdownReceived = false;
        }

        public void run() {
            try {
                selector =  Selector.open();
                networkSocket = ServerSocketChannel.open();
                networkSocket.bind(new InetSocketAddress(myIP, networkPort));
                networkSocket.configureBlocking(false);
                networkSocket.register(selector, SelectionKey.OP_ACCEPT);
                ByteBuffer buffer = ByteBuffer.allocate(2048);  // israf vol 1 :D

                // Charset charset = Charset.forName("ISO-8859-1");
                // Charset charset = Charset.forName("UTF-8");

                int clientIndex = 0;
                String inputLine = "";

                System.out.println("Network Thread: Listening ...");
                while (shutdownReceived == false) {
                    int readyChannels = selector.select();
                    if (readyChannels == 0) {
                        continue;
                    }
                    else {
                        Set selectedKeys = selector.selectedKeys();
                        Iterator iter = selectedKeys.iterator();
                        while (iter.hasNext()) {
                            SelectionKey key = (SelectionKey) iter.next();      // casting to selection key for syntax correctness

                            // check if key is valid first to account for key cancelling.
                            if (!key.isValid()) {
                                continue;
                            }
                            else if (key.isAcceptable()) {
                                SocketChannel client = networkSocket.accept();
                                client.configureBlocking(false);
                                client.register(selector, SelectionKey.OP_READ, clientIndex++);     // attach a client index integer as an object
                            }
                            else if (key.isReadable()) {
                                SocketChannel client = (SocketChannel) key.channel();
                                int clientID = (int) key.attachment();      // get the client ID from attachment of the key
                                int numBytesRead = client.read(buffer);

                                // if end of stream is received, bytes read is set to -1 meaning socket has been closed(shouldn't happen in a normal run)
                                if (numBytesRead != -1) {
                                    inputLine += new String(buffer.array(), 0, numBytesRead, Charset.forName("UTF-8"));

                                    // keep reading if the shutdown isn't sent and full packet ending in \r\n hasn't been received yet
                                    while (!inputLine.startsWith("shutdown") && !inputLine.substring(inputLine.length()-2, inputLine.length()).equals("\r\n")) {
                                        numBytesRead = client.read(buffer);
                                        inputLine += new String(buffer.array(), 0, numBytesRead, Charset.forName("UTF-8"));
                                    }

                                    if(inputLine.startsWith("shutdown")) {
                                        Thread.sleep(1000);
                                        // TODO: Initialize Logging
                                        // TODO: Filewriter header column "WorkerIndex, QueueTime, DequeueTime, ClientResponseTime\n"

                                        shutdownReceived = true;
                                        String fileName = "requestLog.txt";
                                        BufferedWriter writer = new BufferedWriter(new FileWriter(fileName));

                                        for (int i = 0; i < workerThreads.size(); i++) {
                                            WorkerThread wt = workerThreads.get(i);
                                            writer.write("WorkerIndex, QueueTime, DequeueTime, ClientResponseTime\n");
                                            writer.append(wt.getFinalLogString());     // write to file
                                            wt.closeThread();           // close worker thread
                                            wt.interrupt();
                                        }

                                        writer.flush();
                                        writer.close();

                                        break;
                                    }
                                    else if(inputLine.substring(inputLine.length()-2, inputLine.length()).equals("\r\n")) {
                                        inputLine = inputLine.trim();       // remove leading and trailing whitespaces and newlines
                                        String[] requestParts = inputLine.split(" ");       // split the request and get the requestType
                                        String requestType = requestParts[0];

                                        Request request;
                                        if (requestType.equals("get")){
                                            request = new Request(clientID, inputLine, "GET");
                                        } else {
                                            // read the payload line
                                            String[] setParts = inputLine.split(Pattern.quote("\\r\\n"));   // with telnet split at \\ instead of \ before r and n
                                            String message = setParts[0];
                                            String payload = setParts[1];
                                            request = new Request(clientID, message, "SET", payload);
                                        }

                                        requestsQueue.add(request);
                                        inputLine = "";     // reset the inputline
                                    }
                                    else {
                                        System.out.println("LOG: NetworkThread: Fragmented packet couldn't be recovered");
                                    }
                                }
                                else {
                                    key.cancel();
                                    client.close();
                                }

                                buffer.clear();
                            }
                            iter.remove();
                        }
                    }
                }
            } catch (IOException e) {
                System.out.println("LOG: NetworkThread: Server socket failed to accept connection.");
                e.printStackTrace();
            } catch (StringIndexOutOfBoundsException e) {
                System.out.println("LOG: NetworkThread: String operation failed due to indexing error.");
                e.printStackTrace();
            } catch (Exception e) {
                System.out.println("LOG: NetworkThread: Exception.");
                e.printStackTrace();
            } finally {
                closeThread();
            }
        }

        public void sendServerResponse(int clientID, String serverResponse) {
            try {
                ByteBuffer buffer;
                Iterator iter = selector.keys().iterator();
                while (iter.hasNext()) {
                    SelectionKey key = (SelectionKey) iter.next();      // casting to selection key for syntax correctness
                    if (key.attachment() != null && (int) key.attachment() == clientID) {
                        SocketChannel client = (SocketChannel) key.channel();
                        buffer = ByteBuffer.wrap(serverResponse.getBytes());

                        client.write(buffer);
                    }
                    else {
                        continue;
                    }
                }
            } catch (IOException e) {
                System.out.println("LOG: NetworkThread: Middleware failed to send the server response.");
                e.printStackTrace();
            } catch (Exception e) {
                System.out.println("LOG: NetworkThread: Exception.");
                e.printStackTrace();
            }
        }

        private void closeThread () {
            try {
                networkSocket.close();
                selector.close();
            } catch (IOException e) {
                System.out.println("LOG: NetworkThread: Error while closing sockets.");
                e.printStackTrace();
            }
        }
    }

    private void startWorkerThreads() {
        for(int threadCount = 0; threadCount < numThreadsPTP; threadCount++) {
            WorkerThread wt = new WorkerThread();
            workerThreads.add(wt);
            wt.start();
        }
    }

    private static class WorkerThread extends Thread {
        private List<Socket> serverSockets;             // keep server sockets, writers and readers in seperate lists
        private List<PrintWriter> serverWriters;
        private List<BufferedReader> serverReaders;
        private static int currentIndex= -1;
        private int workerIndex;
        private StringBuilder logBuilder;

        public int getWorkerIndex(){
            return this.workerIndex;
        }

        public void appendLogString(String str) {
            this.logBuilder.append(str);
        }

        public String getFinalLogString() {
            return this.logBuilder.toString();
        }

        public WorkerThread() {
            try
            {
                this.workerIndex = ++this.currentIndex;
                this.logBuilder = new StringBuilder();

                this.serverSockets = new ArrayList<>();
                this.serverWriters = new ArrayList<>();
                this.serverReaders = new ArrayList<>();
                for (String address : mcAddresses) {
                    String[] addressParts = address.split(":", 2);       // split the IP and port values at the first ":" (limit:2)
                    String ip = addressParts[0];
                    int port = Integer.parseInt(addressParts[1]);           // cast port to integer

                    System.out.println(ip + " " + port);

                    Socket serverSocket = new Socket(ip,port);
                    this.serverSockets.add(serverSocket);

                    this.serverWriters.add(new PrintWriter(serverSocket.getOutputStream(), true));
                    this.serverReaders.add(new BufferedReader(new InputStreamReader(serverSocket.getInputStream())));
                }
            }
            catch (IOException e) {
                System.out.println("LOG: Worker Thread: Error while creating sockets to servers.");
                e.printStackTrace();
            }
        }


        // SET -- forwarded to all servers
        public String setOperation(String message, String payload) {
            try {
                // Forward the SET request to all servers
                for (int serverIndex = 0; serverIndex < mcAddresses.size(); serverIndex++) {
                    serverWriters.get(serverIndex).println(message + "\r\n" + payload + "\r");  // forward message to server (\r is used instead of \r\n due to println function)
                }
                for (int serverIndex = 0; serverIndex < mcAddresses.size(); serverIndex++) {
                    String serverResponse = serverReaders.get(serverIndex).readLine();          // read server's response
                    // if a server has failed to store the value
                    if (!serverResponse.equals("STORED")) {
                        return serverResponse;
                    }
                }
                // if execution reaches here, values were stored successfully
                return "STORED";
            }  catch (IOException e) {
                System.out.println("LOG: Worker Thread - Set Operation : Error occurred during read/write operation with server socket.");
                e.printStackTrace();
                return "EXCEPTION";
            }
        }

        // GET -- sent to only one server if (sharding == false)
        public String getOperation(String message, int roundRobinServerIndex) {
            try {
                // Forward the GET request to the server with the given round robin index
                serverWriters.get(roundRobinServerIndex).println(message + "\r");      // forward request to server, println adds the "\n"
                String serverResponse;
                StringBuilder builder = new StringBuilder();
                while ((serverResponse = serverReaders.get(roundRobinServerIndex).readLine()) != null) {
                    builder.append(serverResponse);
                    // append responses until "END" message is received
                    if (!serverResponse.equals("END")) {
                        builder.append("\r\n");
                    }
                    else {
                        break;
                    }
                }
                return builder.toString();
            }  catch (IOException e) {
                System.out.println("LOG: Worker Thread - Get Operation : Error occurred during read/write operation with server socket.");
                e.printStackTrace();
                return "EXCEPTION";
            }
        }

        // sharded multi-GET case -- shard the get command into multiple requests to different servers, collect the results and evaluate together
        // since all servers get one request each, does not have an effect on roundRobinServerIndex outside the scope of the function
        public String shardedMultiGetOperation(String message, int roundRobinServerIndex, String[] keys) {
            try {
                int serverCount = mcAddresses.size();
                int totalKeyCount = keys.length;
                int keysPerServer = (int)Math.floor(keys.length/serverCount);
                int remainingkeyCount = totalKeyCount % serverCount;
                int totalKeyIndex = 0;       // index used while iterating over the keys array

                // assign the ~same number of keys to each server(rounded) up and send the requests
                for (int serverIndex = 0; serverIndex < serverCount; serverIndex++) {
                    int serverKeyCount = keysPerServer;
                    if (remainingkeyCount != 0) {
                        serverKeyCount += 1;
                        remainingkeyCount -= 1;
                    }

                    StringBuilder builder = new StringBuilder("get ");
                    for (int keyIndex = 0; keyIndex < serverKeyCount; keyIndex++) {
                        builder.append(keys[totalKeyIndex]);
                        builder.append(" ");        // tested: last " " before the "\r" doesn't cause any issues
                        totalKeyIndex++;
                    }

                    int selectedServer = (roundRobinServerIndex+serverIndex) % serverCount;     // roundRobin pointer goes to first server after using the last server

                    // Forward the GET request to the server with the given round robin index
                    serverWriters.get(selectedServer).println(builder.toString() + "\r");
                }

                StringBuilder builder = new StringBuilder();
                for (int serverIndex = 0; serverIndex < serverCount; serverIndex++) {
                    int selectedServer = (roundRobinServerIndex+serverIndex) % serverCount;     // roundRobin pointer goes to first server after using the last server
                    String serverResponse;
                    while ((serverResponse = serverReaders.get(selectedServer).readLine()) != null) {
                        // append responses until "END" message is received
                        if (!serverResponse.equals("END")) {
                            builder.append(serverResponse);
                            builder.append("\r\n");
                        }
                        else {
                            break;  // do nothing
                        }
                    }
                }
                builder.append("END");
                return builder.toString();
            }  catch (IOException e) {
                System.out.println("LOG: Worker Thread - Get Operation : Error occurred during read/write operation with server socket.");
                e.printStackTrace();
                return "EXCEPTION";
            }
        }


        public void run() {
            try {
                Request request;
                int roundRobinServerIndex = 0;      // server index for round robin load balancing
                while ((request = requestsQueue.take()) != null)     // read the next request from the requests queue
                {
                    appendLogString(Integer.toString(this.workerIndex) + ", ");           // log WorkerIndex
                    appendLogString(Long.toString(request.getReceiveTime()) + ", ");      // log QueueTime
                    appendLogString(Long.toString(System.currentTimeMillis()) + ", ");    // log DequeueTime

                    int clientID = request.getClientID();       // get the ID of the client who has sent the request
                    String message = request.getMessage();      // get the original request of memtier (client)
                    String requestType = request.getRequestType();

                    String serverResponse = "";

                    // use requestType to determine the action to take
                    if (requestType.equals("SET")) {
                        serverResponse = setOperation(message, request.getPayload());
                    } else if (requestType.equals("GET")) {
                        if (readSharded == false) {
                            serverResponse = getOperation(message, roundRobinServerIndex);
                        } else {
                            String[] messageParts = message.split(" ", 2);        // split the message at the first space
                            String keys = messageParts[1];                                    // second half are keys
                            String[] keysArray = keys.split(" ");                       // split keys on " " and take action based on number of keys
                            if (keysArray.length == 1) {
                                serverResponse = getOperation(message, roundRobinServerIndex);
                            } else {
                                serverResponse = shardedMultiGetOperation(message, roundRobinServerIndex, keysArray);
                            }
                        }
                    } else {
                        // refuse unrecognized requestType
                        System.out.println("Unrecognized Command. Waiting for a newline to reinitialize.");
                        // TODO: Log the unrecognized command. Discard all input until a newline arrives.
                    }

                    // if a proper client request command is found and an according response is received from the server (either succesfull or failed)
                    if (!serverResponse.equals("")) {
                        // TODO: Log to output string

                        // TODO: Handle the return of "EXCEPTION" as serverResponse
                        if(serverResponse.equals("EXCEPTION")) {
                            // do nothing
                            appendLogString("-999\n");          // log ClientResponseTime - in the case of exception log a negative value
                        }
                        else {
                            appendLogString(Long.toString(System.currentTimeMillis()) + "\n");  // log ClientResponseTime
                            netThread.sendServerResponse(clientID, serverResponse + "\r\n");
                        }

                        // increment the round robin index and take modulo with number of servers
                        roundRobinServerIndex = (roundRobinServerIndex + 1) % mcAddresses.size();
                    }
                }
            } catch (InterruptedException e) {
                System.out.println("LOG: Worker Thread: Error while reading from the requests queue.");
                e.printStackTrace();
            } finally {
                closeThread();
            }
        }

        private void closeThread () {
            try {
                for (int arrayIndex = 0; arrayIndex < serverSockets.size(); arrayIndex++) {
                    serverReaders.get(arrayIndex).close();
                    serverWriters.get(arrayIndex).close();
                    serverSockets.get(arrayIndex).close();
                }
            } catch (IOException e) {
                System.out.println("LOG: WorkerThread: Error while closing readers, writers or sockets.");
                e.printStackTrace();
            }
        }
    }

}
