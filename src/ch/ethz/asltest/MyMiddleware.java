package ch.ethz.asltest;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;
import java.util.List;


public class MyMiddleware {

    private ServerSocket networkSocket;

    private String myIp;
    private int networkPort;
    private List<String> mcAddresses;
    private int numThreadsPTP;
    private boolean readSharded;


    public MyMiddleware() {
    }

    public MyMiddleware(String myIp, int networkPort, List<String> mcAddresses, int numThreadsPTP, boolean readSharded)
    {
        this.myIp = myIp;
        this.networkPort = networkPort;
        this.mcAddresses = mcAddresses;
        this.numThreadsPTP = numThreadsPTP;
        this.readSharded = readSharded;
    }

    public void run() {
        try {
            new NetworkThread(networkPort).start();
            // startWorkerThreads(numThreadsPTP);


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
                System.out.println("Oh crap.");
                e.printStackTrace();
            } finally {
                closeSocket();
            }
        }

        public void closeSocket() {
            try {
                networkSocket.close();
            } catch (IOException e) {
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

            System.out.println("Oh, new blood!");
            incrementUserCount();

            try {
                out = new PrintWriter(clientSocket.getOutputStream(), true);
                in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
                String inputLine;
                while ((inputLine = in.readLine()) != null) {
                    // Log the client text
                    System.out.println("A client said the following:" + "\t" + inputLine);
                    out.println(String.format("Server[%d]: \"%s\"", activeUserCount, inputLine));

                    if (".".equals(inputLine)) {
                        System.out.println("Bye, friend.");
                        decrementUserCount();
                        clientSocket.close(); // may be redundant
                        break;
                    }
                }

                System.out.println("Closing socket things then");
                in.close();
                out.close();
                clientSocket.close();

            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }



}
