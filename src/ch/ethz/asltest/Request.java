package ch.ethz.asltest;

public class Request {

    private int clientID;
    private String message;

    public Request() {

    }

    public Request(int clientID, String message) {
        this.clientID = clientID;
        this.message = message;
    }

    public int getClientID () {
        return this.clientID;
    }

    public String getMessage () {
        return  this.message;
    }


}
