/**
 * RouteMatrixBodyBuilder
 * * Constructs the JSON request body for the Google Routes API using Apex classes
 * and JSON.serialize() for robustness. It also returns a structured output
 * object to make the input coordinates and the generated JSON body assignable
 * as Apex-Defined Variables in a Salesforce Flow.
 */
public class RouteMatrixBodyBuilder {

    /**
     * @InvocableMethod: The main method called by a Flow.
     * @param inputs: A list containing FlowInputs (Origin and Destination coordinates).
     * @return List<FlowOutputs>: A list containing the generated JSON body and
     * the original input coordinates for Flow assignment.
     */
    @InvocableMethod(label='Build Route Matrix JSON Body' description='Constructs the JSON request body for Google Routes API and outputs structured data.')
    // FIX: Changed return type from List<String> to List<FlowOutputs>
    public static List<FlowOutputs> buildBody(List<FlowInputs> inputs) { 
        
        List<FlowOutputs> results = new List<FlowOutputs>();
        
        // Invocable methods always receive and return lists. We iterate through the inputs.
        for (FlowInputs input : inputs) {
            
            // 1. Create the nested location objects for Origin
            LatLng originLatLng = new LatLng(input.originLatitude, input.originLongitude);
            RouteItem originRouteItem = new RouteItem(new Waypoint(new Location(originLatLng)));

            // 2. Create the nested location objects for Destination
            LatLng destLatLng = new LatLng(input.destLatitude, input.destLongitude);
            RouteItem destRouteItem = new RouteItem(new Waypoint(new Location(destLatLng)));

            // 3. Create the main request body object
            RouteMatrixRequest request = new RouteMatrixRequest();
            request.origins = new List<RouteItem>{originRouteItem};
            request.destinations = new List<RouteItem>{destRouteItem};
            
            // 4. Serialize the object into a JSON string
            String jsonBody = JSON.serialize(request);
            
            // 5. Populate the structured FlowOutputs object
            FlowOutputs output = new FlowOutputs();
            output.jsonBody = jsonBody;
            output.originLatitude = input.originLatitude;
            output.originLongitude = input.originLongitude;
            output.destLatitude = input.destLatitude;
            output.destLongitude = input.destLongitude;
            
            results.add(output);
        }
        
        return results;
    }

    // --- FLOW INPUT/OUTPUT CLASSES ---

    /**
     * FlowInputs: Represents the input variables accepted from the Flow.
     */
    public class FlowInputs {
        @InvocableVariable(label='Origin Latitude')
        public Decimal originLatitude;
        
        @InvocableVariable(label='Origin Longitude')
        public Decimal originLongitude;

        @InvocableVariable(label='Destination Latitude')
        public Decimal destLatitude;
        
        @InvocableVariable(label='Destination Longitude')
        public Decimal destLongitude;
    }

    /**
     * FlowOutputs: Represents the output variables returned to the Flow, making 
     * the coordinates and the JSON body assignable to Flow variables.
     */
    public class FlowOutputs {
        @InvocableVariable(label='JSON Request Body' description='The final JSON string ready for the Google Routes API call.')
        public String jsonBody;
        
        // These fields allow the Flow to capture and use the coordinates if needed
        @InvocableVariable(label='Origin Latitude Used')
        public Decimal originLatitude;
        
        @InvocableVariable(label='Origin Longitude Used')
        public Decimal originLongitude;

        @InvocableVariable(label='Destination Latitude Used')
        public Decimal destLatitude;
        
        @InvocableVariable(label='Destination Longitude Used')
        public Decimal destLongitude;
    }

    // --- JSON MAPPING CLASSES ---

    /**
     * LatLng: Maps to the "latLng" object in the JSON.
     */
    public class LatLng {
        public Decimal latitude { get; set; }
        public Decimal longitude { get; set; }
        public LatLng(Decimal lat, Decimal lon) {
            this.latitude = lat;
            this.longitude = lon;
        }
    }

    /**
     * Location: Maps to the "location" object.
     */
    public class Location {
        public LatLng latLng { get; set; }
        public Location(LatLng ll) {
            this.latLng = ll;
        }
    }

    /**
     * Waypoint: Maps to the "waypoint" object.
     */
    public class Waypoint {
        public Location location { get; set; }
        public Waypoint(Location loc) {
            this.location = loc;
        }
    }

    /**
     * RouteItem: Maps to the array items in "origins" and "destinations".
     */
    public class RouteItem {
        public Waypoint waypoint { get; set; }
        public RouteItem(Waypoint wp) {
            this.waypoint = wp;
        }
    }

    /**
     * RouteMatrixRequest: Maps to the top-level JSON request body.
     */
    public class RouteMatrixRequest {
        public List<RouteItem> origins { get; set; }
        public List<RouteItem> destinations { get; set; }
        // Set travelMode as a property with a default value
        public String travelMode { get; set; } 
        
        // Constructor to ensure 'DRIVE' is always set
        public RouteMatrixRequest() {
            this.travelMode = 'DRIVE'; 
        }
    }
}