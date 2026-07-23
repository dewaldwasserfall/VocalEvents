@IsTest
public class BingMapsServiceTest {
    @IsTest
    static void testGetDrivingDistance() {
        // Define test data
        BingMapsService.DrivingDistanceInput input = new BingMapsService.DrivingDistanceInput();
        input.originLat = 37.7749;
        input.originLng = -122.4194;
        input.destLat = 34.0522;
        input.destLng = -118.2437;

        List<BingMapsService.DrivingDistanceInput> inputs = new List<BingMapsService.DrivingDistanceInput>();
        inputs.add(input);

        // Mock HTTP callout
        Test.setMock(HttpCalloutMock.class, new BingMapsServiceMock());

        // Call the method to test
        List<BingMapsService.DrivingDistanceOutput> outputs = BingMapsService.getDrivingDistance(inputs);

        
    }
}