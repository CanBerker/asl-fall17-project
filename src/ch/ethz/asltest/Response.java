package ch.ethz.asltest;

public class Response {

    private int clientID;       // id of the client who should receive the response
    private String message;

    public Response() {}

    public Response(int clientID, String message) {
        this.clientID = clientID;
        this.message = message;
    }

    public int getClientID() {
        return this.clientID;
    }

    public String getMessage() {
        return this.message;
    }
}
