@IsTest
public class RouteRequestBuilder_Test {

    @IsTest
    static void testSingleInput() {
        // Prepare input
        RouteRequestBuilder.Input input = new RouteRequestBuilder.Input();
        input.originLatitude = 48.8584;
        input.originLongitude = 2.2945;
        input.destinationLatitude = 51.5007;
        input.destinationLongitude = 0.1246;
        input.travelMode = 'DRIVE';

        // Call the invocable method
        List<RouteRequestBuilder.Output> result = RouteRequestBuilder.build(new List<RouteRequestBuilder.Input>{ input });

        // Assertions
        System.assertEquals(1, result.size());
        String json = result[0].jsonRequest;

        System.assert(json.contains('"latitude":48.8584'), 'Origin latitude missing in JSON');
        System.assert(json.contains('"longitude":2.2945'), 'Origin longitude missing in JSON');
        System.assert(json.contains('"latitude":51.5007'), 'Destination latitude missing in JSON');
        System.assert(json.contains('"longitude":0.1246'), 'Destination longitude missing in JSON');
        System.assert(json.contains('"travelMode":"DRIVE"'), 'Travel mode missing in JSON');
    }

    @IsTest
    static void testMultipleInputs() {
        // Prepare two inputs
        RouteRequestBuilder.Input input1 = new RouteRequestBuilder.Input();
        input1.originLatitude = 10.0;
        input1.originLongitude = 20.0;
        input1.destinationLatitude = 30.0;
        input1.destinationLongitude = 40.0;
        input1.travelMode = 'DRIVE';

        RouteRequestBuilder.Input input2 = new RouteRequestBuilder.Input();
        input2.originLatitude = -10.0;
        input2.originLongitude = -20.0;
        input2.destinationLatitude = -30.0;
        input2.destinationLongitude = -40.0;
        input2.travelMode = 'WALK';

        List<RouteRequestBuilder.Output> results = RouteRequestBuilder.build(
            new List<RouteRequestBuilder.Input>{ input1, input2 }
        );

        // Assertions
        System.assertEquals(2, results.size(), 'Should return 2 outputs');

        // Validate first JSON
        System.assert(results[0].jsonRequest.contains('"latitude":10.0'));
        System.assert(results[0].jsonRequest.contains('"longitude":20.0'));
        System.assert(results[0].jsonRequest.contains('"latitude":30.0'));
        System.assert(results[0].jsonRequest.contains('"longitude":40.0'));
        System.assert(results[0].jsonRequest.contains('"travelMode":"DRIVE"'));

        // Validate second JSON
        System.assert(results[1].jsonRequest.contains('"latitude":-10.0'));
        System.assert(results[1].jsonRequest.contains('"longitude":-20.0'));
        System.assert(results[1].jsonRequest.contains('"latitude":-30.0'));
        System.assert(results[1].jsonRequest.contains('"longitude":-40.0'));
        System.assert(results[1].jsonRequest.contains('"travelMode":"WALK"'));
    }
}