package ch.ethz.asltest;

public class Request {

    private boolean shutdown;   // if this is a special type of request called "Shutdown"
    private int clientID;       // id of the client who made the request
    private String message;
    private String requestType; // SET or GET operation
    private String payload;     // data of the SET operation
    private long receiveTime;    // the time request was received

    public Request() {

    }

    // constructor for GET operations
    public Request(int clientID, String message, String requestType) {
        this.shutdown = false;
        this.clientID = clientID;
        this.message = message;
        this.requestType = requestType;
        this.payload = null;        // get requests doesn't have a payload
        this.receiveTime = System.currentTimeMillis();
    }

    // constructor for SET operations
    public Request(int clientID, String message, String requestType, String payload) {
        this.shutdown = false;
        this.clientID = clientID;
        this.message = message;
        this.requestType = requestType;
        this.payload = payload;
        this.receiveTime = System.currentTimeMillis();
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