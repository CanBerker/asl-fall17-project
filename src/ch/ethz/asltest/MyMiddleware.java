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
    protected static BlockingQueue<String> requestsQueue;
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

        private List<ClientHandler> clientHandlerList;

        public NetworkThread(int networkPort)
        {
            this.networkPort = networkPort;
            this.clientHandlerList = new ArrayList<>();
        }

        public void run() {
            try {
                networkSocket = new ServerSocket(networkPort);
                System.out.println("Listening ...");
                while (true) {
                    ClientHandler newClientHandler = new ClientHandler(networkSocket.accept());
                    clientHandlerList.add(newClientHandler);
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

        public List<ClientHandler> getClientHandlerList() {
            return clientHandlerList;
        }
    }

    private static class ClientHandler extends Thread {
        private Socket clientSocket;
        private PrintWriter out;
        private BufferedReader in;
        private static int activeUserCount = 0;

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
            incrementUserCount();

            try {
                in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
                String inputLine;
                while ((inputLine = in.readLine()) != null) {
                    requestsQueue.add(inputLine);
                }


            } catch (IOException e) {
                System.out.println("LOG: ClientHandlder: Reading from socket stream failed.");
                e.printStackTrace();
            } catch (IllegalStateException e) {
                System.out.println("LOG: ClientHandler: Insertion to request queue failed.");
                e.printStackTrace();
            } finally {
                closeThread();
            }
        }

        private void closeThread () {
            try
            {
                in.close();
                clientSocket.close();
            } catch (IOException e) {
                System.out.println("LOG: ClientHandler: Error while closing readers or sockets.");
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
                    String[] addressParts = address.split(":");     // split the IP and port values at ":"
                    String ip = addressParts[0];
                    int port = Integer.parseInt(addressParts[1]);       // cast port to integer

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

                String request;
                int roundRobinIndex = 0;
                while((request = requestsQueue.take()) != null)
                {
                    // TODO: forward the request to server
                    // TODO: read response from server
                    // TODO: forward the response to the client


                    // serverWriters.get(roundRobinIndex).println();

                    String inputLine;
                    while ((inputLine = serverReaders.get(roundRobinIndex).readLine()) != null) {
                        // Log the client text
                        System.out.println("A client said the following:" + "\t" + inputLine);

                    }


                    roundRobinIndex = (roundRobinIndex + 1) % mcAddresses.size();      // increment the round robin index and take modulo with number of servers
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
            try
            {
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
