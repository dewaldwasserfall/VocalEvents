public class BingMapsService {
    // Bing Maps API Key
    private static final String BING_MAPS_API_KEY = 'AvPF_6t43Fi26jlqspksaMzSYlxa1vQYjivUJHavj1JO3E3UiAM1kaQ8PKzj2S5s';

    @InvocableMethod(label='Get Driving Distance' description='Calculates driving distance between two coordinates using Bing Maps API')
    public static List<DrivingDistanceOutput> getDrivingDistance(List<DrivingDistanceInput> inputs) {
        List<DrivingDistanceOutput> outputs = new List<DrivingDistanceOutput>();

        for (DrivingDistanceInput input : inputs) {
            Decimal distance = calculateDistance(input.originLat, input.originLng, input.destLat, input.destLng);
            DrivingDistanceOutput output = new DrivingDistanceOutput();
            output.distance = distance;
            outputs.add(output);
        }

        return outputs;
    }

    private static Decimal calculateDistance(Decimal originLat, Decimal originLng, Decimal destLat, Decimal destLng) {
        // Callout to Bing Maps API to calculate the driving distance
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://dev.virtualearth.net/REST/v1/Routes/Driving?wp.0=' + originLat + ',' + originLng + '&wp.1=' + destLat + ',' + destLng + '&distanceUnit=km&key=' + BING_MAPS_API_KEY);
        request.setMethod('GET');
        HttpResponse response = http.send(request);

        Decimal distance = 0;
        if (response.getStatusCode() == 200) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            if (responseBody.containsKey('resourceSets')) {
                List<Object> resourceSets = (List<Object>) responseBody.get('resourceSets');
                if (!resourceSets.isEmpty()) {
                    Map<String, Object> resourceSet = (Map<String, Object>) resourceSets[0];
                    if (resourceSet.containsKey('resources')) {
                        List<Object> resources = (List<Object>) resourceSet.get('resources');
                        if (!resources.isEmpty()) {
                            Map<String, Object> resource = (Map<String, Object>) resources[0];
                            if (resource.containsKey('travelDistance')) {
                                distance = Decimal.valueOf((Double) resource.get('travelDistance'));
                            }
                        }
                    }
                }
            }
        }

        return distance;
    }

    public class DrivingDistanceInput {
        @InvocableVariable(label='Origin Latitude' description='Latitude of the origin coordinate' required=true)
        public Decimal originLat;
        @InvocableVariable(label='Origin Longitude' description='Longitude of the origin coordinate' required=true)
        public Decimal originLng;
        @InvocableVariable(label='Destination Latitude' description='Latitude of the destination coordinate' required=true)
        public Decimal destLat;
        @InvocableVariable(label='Destination Longitude' description='Longitude of the destination coordinate' required=true)
        public Decimal destLng;
    }

    public class DrivingDistanceOutput {
        @InvocableVariable(label='Driving Distance (km)' description='Driving distance between the origin and destination coordinates')
        public Decimal distance;
    }
}