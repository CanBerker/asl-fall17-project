package ch.ethz.asltest;

public class Request {

    private int clientID;       // id of the client who made the request
    private String message;
    private String requestType; // SET or GET operation
    private String payload;     // data of the SET operation

    public Request() {

    }

    // constructor for GET operations
    public Request(int clientID, String message, String requestType) {
        this.clientID = clientID;
        this.message = message;
        this.requestType = requestType;
        this.payload = null;        // get requests doesn't have a payload
    }

    // constructor for SET operations
    public Request(int clientID, String message, String requestType, String payload) {
        this.clientID = clientID;
        this.message = message;
        this.requestType = requestType;
        this.payload = payload;
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

}
