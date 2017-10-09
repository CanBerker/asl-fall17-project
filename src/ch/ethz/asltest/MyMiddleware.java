package ch.ethz.asltest;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.List;

public class MyMiddleware{

    private ServerSocket mySocket;

    private String myIp;
    private int myPort;
    private List<String> mcAddresses;
    private int numThreadsPTP;
    private boolean readSharded;


    // private List<ClientHandler> clientHandlerList;

    public MyMiddleware() {
        // clientHandlerList = new ArrayList<>();
    }

    public MyMiddleware(String myIp, int myPort, List<String> mcAddresses, int numThreadsPTP, boolean readSharded)
    {
        this.myIp = myIp;
        this.myPort = myPort;
        this.mcAddresses = mcAddresses;
        this.numThreadsPTP = numThreadsPTP;
        this.readSharded = readSharded;
    }

    public void run() {
        try {
            mySocket = new ServerSocket(myPort);
            System.out.println("Listening ...");
            while (true) {
                /*
                    TODO: Uncomment if/when notification is necessary
                    ClientHandler newClientHandler = new ClientHandler(serverSocket.accept());
                    clientHandlerList.add(newClientHandler);
                    newClientHandler.start();
                */
                new ClientHandler(mySocket.accept()).start();
            }
        } catch (IOException e) {
            System.out.println("Oh crap.");
            e.printStackTrace();
        } finally {
            stop();
        }
    }

    public void stop() {
        try {
            mySocket.close();
        } catch (IOException e) {
            e.printStackTrace();
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
