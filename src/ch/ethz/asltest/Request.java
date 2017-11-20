package ch.ethz.asltest;

import java.nio.channels.SocketChannel;

public class Request {

    private boolean shutdown;   // if this is a special type of request called "Shutdown"
    private int clientID;       // id of the client who made the request
    private String message;
    private String requestType; // SET or GET operation
    private String payload;     // data of the SET operation
    private long receiveTime;    // the time request was received
    private SocketChannel channel;  // channel the request came through

    public Request() {

    }

    // constructor for GET operations
    public Request(int clientID, String message, String requestType, SocketChannel channel, long receiveTime) {
        this.shutdown = false;
        this.clientID = clientID;
        this.message = message;
        this.requestType = requestType;
        this.payload = null;        // get requests doesn't have a payload
        this.receiveTime = receiveTime;
        this.channel = channel;
    }

    // constructor for SET operations
    public Request(int clientID, String message, String requestType, String payload, SocketChannel channel, long receiveTime) {
        this.shutdown = false;
        this.clientID = clientID;
        this.message = message;
        this.requestType = requestType;
        this.payload = payload;
        this.receiveTime = receiveTime;
        this.channel = channel;
    }

    public int getClientID () {
        return this.clientID;
    }
    public String getMessage () {
        return  this.message;
    }
    public String getRequestType () {
        return this.requestType;
    }
    public String getPayload () {
        return this.payload;
    }
    public long getReceiveTime() {
        return receiveTime;
    }
    public SocketChannel getChannel() {
        return channel;
    }

    // constructor for Shutdown request
    public Request(String str) {
        if (str.startsWith("shutdown")) {
            this.shutdown = true;
        }
    }

    public boolean isShutdown () {
        return this.shutdown;
    }

}