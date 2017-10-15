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
    protected boolean readSharded;

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
                System.out.println("Listening ...");
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
        private PrintWriter out;
        private BufferedReader in;
        private static int activeUserCount = 0;
        private int clientID = 0;

        public ClientHandler(Socket socket) {
            this.clientSocket = socket;
        }

        public void incrementUserCount() {
            activeUserCount += 1;
        }

        public void decrementUserCount() {
            activeUserCount -= 1;
        }

        public void run() {

            System.out.println("Client connected!");
            clientID = activeUserCount;
            incrementUserCount();

            try {
                out = new PrintWriter(clientSocket.getOutputStream(), true);        // define the output of socket to send serverResponse in the workerThread
                in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));      // define input of socket to read the request of the client
                String inputLine;
                while ((inputLine = in.readLine()) != null) {
                    Request request = new Request(clientID, inputLine);
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
                out.close();
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
                    String[] addressParts = address.split(":");       // split the IP and port values at ":"
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

        public void run() {
            try {

                Request request;
                int roundRobinServerIndex = 0;      // server index for round robin load balancing
                while((request = requestsQueue.take()) != null)     // read the next request from the requests queue
                {
                    int clientID = request.getClientID();       // get the ID of the client who has sent the request

                    // TODO: determine the operation with request type and parameters

                    // TODO: forward the request's message to server
                    serverWriters.get(roundRobinServerIndex).println(request.getMessage());

                    // TODO: read response from server
                    String serverResponse = serverReaders.get(roundRobinServerIndex).readLine();

                    // TODO: parse the response in the case of sharded operations


                    // TODO: forward the response to the client
                    clientHandlers.get(clientID).out.println(serverResponse);

                    roundRobinServerIndex = (roundRobinServerIndex + 1) % mcAddresses.size();      // increment the round robin index and take modulo with number of servers
                }



            } catch (IOException e) {
                System.out.println("LOG: Worker Thread: Error occurred during read/write operation with server socket.");
                e.printStackTrace();
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
