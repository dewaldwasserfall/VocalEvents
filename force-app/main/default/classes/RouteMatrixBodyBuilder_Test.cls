@IsTest
private class RouteMatrixBodyBuilder_Test {

    @IsTest
    static void testBuildBody() {
        // --- 1. SETUP: Prepare Input Data ---
        
        // Create an instance of the Invocable Input class
        RouteMatrixBodyBuilder.FlowInputs input = new RouteMatrixBodyBuilder.FlowInputs();
        
        // Assign mock coordinates
        input.originLatitude = 37.7749;     // San Francisco (Origin)
        input.originLongitude = -122.4194;
        input.destLatitude = 34.0522;       // Los Angeles (Destination)
        input.destLongitude = -118.2437;
        
        // Create the list required for Invocable Method input
        List<RouteMatrixBodyBuilder.FlowInputs> inputs = new List<RouteMatrixBodyBuilder.FlowInputs>{input};

        // --- 2. EXECUTE: Call the method ---
        
        // Call the Invocable Method inside a Test.start/stopBlock
        Test.startTest();
        List<RouteMatrixBodyBuilder.FlowOutputs> results = RouteMatrixBodyBuilder.buildBody(inputs);
        Test.stopTest();

        // --- 3. ASSERT: Verify the Results ---
        
        // Verify that the method returned exactly one output element
        System.assertEquals(1, results.size(), 'The result list should contain exactly one element.');
        
        // Get the output for verification
        RouteMatrixBodyBuilder.FlowOutputs output = results[0];
        
        // 3a. Verify coordinates in the FlowOutputs object
        System.assertEquals(37.7749, output.originLatitude, 'Origin Latitude mismatch.');
        System.assertEquals(-118.2437, output.destLongitude, 'Destination Longitude mismatch.');
        
        // 3b. Verify the generated JSON body
        String jsonBody = output.jsonBody;

        // Check for key components to confirm structure and data are correct
        System.assert(jsonBody.contains('"latitude":37.7749'), 'JSON must contain the origin latitude.');
        System.assert(jsonBody.contains('"longitude":-122.4194'), 'JSON must contain the origin longitude.');
        System.assert(jsonBody.contains('"latitude":34.0522'), 'JSON must contain the destination latitude.');
        System.assert(jsonBody.contains('"longitude":-118.2437'), 'JSON must contain the destination longitude.');
        System.assert(jsonBody.contains('"travelMode":"DRIVE"'), 'JSON must contain the default travel mode.');

        // Simple structure check (ensures the top level keys exist)
        System.assert(jsonBody.contains('"origins":'), 'JSON must contain the "origins" array.');
        System.assert(jsonBody.contains('"destinations":'), 'JSON must contain the "destinations" array.');
    }
}