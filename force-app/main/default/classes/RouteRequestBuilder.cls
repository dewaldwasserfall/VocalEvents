public class RouteRequestBuilder {

    // Input structure for Flow
    public class Input {
        @InvocableVariable(required=true)
        public Double originLatitude;

        @InvocableVariable(required=true)
        public Double originLongitude;

        @InvocableVariable(required=true)
        public Double destinationLatitude;

        @InvocableVariable(required=true)
        public Double destinationLongitude;

        @InvocableVariable(required=true)
        public String travelMode;
    }

    // Output structure for Flow
    public class Output {
        @InvocableVariable
        public String jsonRequest;
    }

    @InvocableMethod(label='Build Route Request')
    public static List<Output> build(List<Input> inputs) {
        List<Output> results = new List<Output>();

        for (Input i : inputs) {

            // Build JSON structure using Maps
            Map<String, Object> latLngOrigin = new Map<String, Object>{
                'latitude' => i.originLatitude,
                'longitude' => i.originLongitude
            };

            Map<String, Object> latLngDest = new Map<String, Object>{
                'latitude' => i.destinationLatitude,
                'longitude' => i.destinationLongitude
            };

            Map<String, Object> origin = new Map<String, Object>{
                'waypoint' => new Map<String, Object>{
                    'location' => new Map<String, Object>{
                        'latLng' => latLngOrigin
                    }
                }
            };

            Map<String, Object> destination = new Map<String, Object>{
                'waypoint' => new Map<String, Object>{
                    'location' => new Map<String, Object>{
                        'latLng' => latLngDest
                    }
                }
            };

            Map<String, Object> request = new Map<String, Object>{
                'origins' => new List<Object>{ origin },
                'destinations' => new List<Object>{ destination },
                'travelMode' => i.travelMode
            };

            // Serialize to JSON
            Output out = new Output();
            out.jsonRequest = JSON.serialize(request);

            results.add(out);
        }
        return results;
    }
}