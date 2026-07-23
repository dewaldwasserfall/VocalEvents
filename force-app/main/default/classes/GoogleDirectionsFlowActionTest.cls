@IsTest
public class GoogleDirectionsFlowActionTest {

    // Mock HTTP Response for Google Directions API
    public class DirectionsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type','application/json');
            res.setStatusCode(200);

            // Sample Google Directions JSON (simplified)
            String body = '{' +
                '"status": "OK",' +
                '"routes": [' +
                '{' +
                    '"legs": [' +
                        '{' +
                            '"distance": {"text": "771 km","value": 770570},' +
                            '"duration": {"text": "8 hours 0 mins","value": 28813}' +
                        '}' +
                    ']' +
                '}' +
            ']' +
            '}';
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void testGetDirections() {
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new DirectionsMock());

        // Prepare request
        GoogleDirectionsFlowAction.DirectionsRequest req = new GoogleDirectionsFlowAction.DirectionsRequest();
        req.origin = '110 Voortrekker St, Coligny, 2725, South Africa';
        req.destination = '12 Queen St, Nxuba, 5880, South Africa';

        List<GoogleDirectionsFlowAction.DirectionsRequest> requests = new List<GoogleDirectionsFlowAction.DirectionsRequest>{req};

        // Call invocable method
        Test.startTest();
        List<GoogleDirectionsFlowAction.DirectionsResponse> results = 
            GoogleDirectionsFlowAction.getDirections(requests);
        Test.stopTest();

    }
}