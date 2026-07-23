// Mock class for HTTP callout
@isTest
public class AddressParserMock implements HttpCalloutMock {
    // Method to respond to HTTP request
    public HTTPResponse respond(HTTPRequest req) {
        // Create mock response
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"resourceSets":[{"resources":[{"address":{"addressLine":"123 Main St","locality":"Springfield","postalCode":"62701","countryRegion":"IL"}}]}]}');
        return res;
    }
}