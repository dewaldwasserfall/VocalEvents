@IsTest
private class RouteMatrixBodyBuilderTest {

    @IsTest
    static void testBuildBody() {
        // 1. Setup Test Data (Use sample coordinates)
        RouteMatrixBodyBuilder.FlowInputs testInputs = new RouteMatrixBodyBuilder.FlowInputs();
        
        // Origin: Paris, France (Decimal coordinates)
        testInputs.originLatitude = 48.8584;
        testInputs.originLongitude = 2.2945;
        
        // Destination: London, UK (Decimal coordinates)
        testInputs.destLatitude = 51.5007;
        testInputs.destLongitude = 0.1246;

        // The @InvocableMethod expects a List<InputType>
        List<RouteMatrixBodyBuilder.FlowInputs> inputList = 
            new List<RouteMatrixBodyBuilder.FlowInputs>{ testInputs };

        // 2. Call the Method
        Test.startTest();
        List<String> resultList = RouteMatrixBodyBuilder.buildBody(inputList);
        Test.stopTest();

        // 3. Assertions
        System.assert(resultList != null, 'The result list should not be null.');
        System.assertEquals(1, resultList.size(), 'The result list should contain exactly one JSON string.');

        String jsonBody = resultList[0];
        System.assert(jsonBody.startsWith('{'), 'The result should be a JSON string starting with {.');
        
        // Assert that the key coordinate values are present in the final JSON string
        // Note: Using String.valueOf() to ensure decimal precision matches the Apex class output
        System.assert(jsonBody.contains(String.valueOf(testInputs.originLatitude)), 
                      'JSON body should contain the origin latitude.');
        System.assert(jsonBody.contains(String.valueOf(testInputs.originLongitude)), 
                      'JSON body should contain the origin longitude.');
        System.assert(jsonBody.contains(String.valueOf(testInputs.destLatitude)), 
                      'JSON body should contain the destination latitude.');
        System.assert(jsonBody.contains(String.valueOf(testInputs.destLongitude)), 
                      'JSON body should contain the destination longitude.');
                      
        // Assert the expected static parts of the JSON body
        System.assert(jsonBody.contains('"travelMode": "DRIVE"}'), 
                      'JSON body should contain the required travel mode.');
    }
}