package ch.ethz.asltest;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;


public class MyMiddleware {

    // Variables are defined as protected to be used in subclasses
    protected String myIp;
    protected int networkPort;
    protected static List<String> mcAddresses;
    protected int numThreadsPTP;
    protected static boolean readSharded;

    protected static NetworkThread netThread;
    protected static List<ClientHandler> clientHandlers;
    protected static BlockingQueue<Request> requestsQueue;
    protected List<WorkerThread> workerThreads;


    public MyMiddleware() {
    }

    public MyMiddleware(String myIp, int networkPort, List<String> mcAddresses, int numThreadsPTP, boolean readSharded)
    {
        this.myIp = myIp;
        this.networkPort = networkPort;
        this.mcAddresses = mcAddresses;
        this.numThreadsPTP = numThreadsPTP;
        this.readSharded = readSharded;

        this.netThread = new NetworkThread(networkPort);
        this.clientHandlers = new ArrayList<>();
        this.requestsQueue = new LinkedBlockingQueue<>();
        this.workerThreads = new ArrayList<>();
    }

    public void run() {
        try {
            netThread.start();
            // TODO: Implement responseThread
            startWorkerThreads();

        } catch (Exception e) {

            e.printStackTrace();
        } finally {

        }
    }

    private static class NetworkThread extends Thread {

        private int networkPort;
        private ServerSocket networkSocket;

        public NetworkThread(int networkPort)
        {
            this.networkPort = networkPort;
        }

        public void run() {
            try {
                networkSocket = new ServerSocket(networkPort);
                System.out.println("Network Thread: Listening ...");
                while (true) {
                    ClientHandler newClientHandler = new ClientHandler(networkSocket.accept());
                    clientHandlers.add(newClientHandler);
                    newClientHandler.start();
                }
            } catch (IOException e) {
                System.out.println("LOG: NetworkThread: Server socket failed to accept connection.");
                e.printStackTrace();
            } finally {
                closeThread();
            }
        }

        private void closeThread () {
            try {
                networkSocket.close();
            } catch (IOException e) {
                System.out.println("LOG: NetworkThread: Error while closing sockets.");
                e.printStackTrace();
            }
        }
    }

    private static class ClientHandler extends Thread {
        private Socket clientSocket;
        // private PrintWriter out;
        private BufferedReader in;
        private static int activeUserCount = 0;
        private int clientID = 0;

        public ClientHandler(Socket socket) {
            this.clientSocket = socket;
            System.out.println(getClientIP());
        }

        public void incrementUserCount() {
            activeUserCount += 1;
        }

        public void decrementUserCount() {
            activeUserCount -= 1;
        }

        public String getClientIP () {
            return this.clientSocket.getInetAddress().toString();
        }

        public void run() {

            System.out.println("Client Handler: Client connected!");
            clientID = activeUserCount;
            incrementUserCount();

            try {
                // out = new PrintWriter(clientSocket.getOutputStream(), true);        // define the output of socket to send serverResponse in the workerThread
                in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));      // define input of socket to read the request of the client
                String inputLine;
                while ((inputLine = in.readLine()) != null) {
                    // SET format   -- sends a MESSAGE(multiple fields seperated by whitespace) and a PAYLOAD
                    // <command name> <key> <flags> <exptime> <bytes> [noreply]\r\n
                    // <data block>\r\n

                    // GET format   -- sends a MESSAGE(single key or multiple seperated by whitespace)
                    // get <key>*\r\n

                    String[] requestParts = inputLine.split(" ");       // split the request and get the requestType
                    String requestType = requestParts[0];

                    Request request;
                    if (requestType.equals("get")){
                        request = new Request(clientID, inputLine, "GET");
                    } else {
                        // read the payload line
                        String payload = in.readLine();
                        request = new Request(clientID, inputLine, "SET", payload);
                    }

                    requestsQueue.add(request);
                }
            } catch (IOException e) {
                System.out.println("LOG: ClientHandler: Reading from socket stream failed.");
                e.printStackTrace();
            } catch (IllegalStateException e) {
                System.out.println("LOG: ClientHandler: Insertion to request queue failed.");
                e.printStackTrace();
            } finally {
                closeThread();
            }
        }

        private void closeThread () {
            try {
                in.close();
                // out.close();
                clientSocket.close();
            } catch (IOException e) {
                System.out.println("LOG: ClientHandler: Error while closing readers, writers or sockets.");
                e.printStackTrace();
            }
        }
    }


    private void startWorkerThreads() {
        for(int threadCount = 0; threadCount < numThreadsPTP; threadCount++) {
            WorkerThread wt = new WorkerThread();
            wt.start();
        }
    }

    private static class WorkerThread extends Thread {
        private List<Socket> serverSockets;             // keep server sockets, writers and readers in seperate lists
        private List<PrintWriter> serverWriters;
        private List<BufferedReader> serverReaders;

        public WorkerThread() {
            try
            {
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
                serverWriters.get(roundRobinServerIndex).println(message + "\r");      // forward request to server
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

        // TODO: Test sharded multi-GET operation
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
                        // TODO: Log the unrecognized command
                        // TODO: Discard all input until a newline arrives.
                    }

                    // if a proper client request command is found and an according response is received from the server
                    if (!serverResponse.equals("")) {
                        // TODO: Handle the return of "EXCEPTION" as serverResponse
                        // TODO: Use responseThread connection
                        // clientHandlers.get(clientID).out.println(serverResponse + "\r");

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


//    private static class ClientHandler extends Thread {
//        private Socket clientSocket;
//        private PrintWriter out;
//        private BufferedReader in;
//        private static int activeUserCount = 0;
//
//        public ClientHandler(Socket socket) {
//            this.clientSocket = socket;
//        }
//
//        public void incrementUserCount() {
//            activeUserCount += 1;
//        }
//
//        public void decrementUserCount() {
//            activeUserCount -= 1;
//        }
//
//        public void run() {
//
//            System.out.println("Client connected!");
//            incrementUserCount();
//
//            try {
//                out = new PrintWriter(clientSocket.getOutputStream(), true);
//                in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
//                String inputLine;
//                while ((inputLine = in.readLine()) != null) {
//                    // Log the client text
//                    System.out.println("A client said the following:" + "\t" + inputLine);
//                    out.println(String.format("Server[%d]: \"%s\"", activeUserCount, inputLine));
//
//                    if (".".equals(inputLine)) {
//                        System.out.println("Bye, friend.");
//                        decrementUserCount();
//                        clientSocket.close(); // may be redundant
//                        break;
//                    }
//                }
//
//                System.out.println("Closing socket things then");
//                in.close();
//                out.close();
//                clientSocket.close();
//
//            } catch (IOException e) {
//                e.printStackTrace();
//            }
//        }
//    }



}
