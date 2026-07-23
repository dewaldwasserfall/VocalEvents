@isTest
public class BingMapsServiceMock implements HttpCalloutMock {
    // Implement the mock HTTP response
    public HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"resourceSets":[{"resources":[{"travelDistance":389.1}]}]}');
        res.setStatusCode(200);
        return res;
    }
}