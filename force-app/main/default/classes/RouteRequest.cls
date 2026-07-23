public class RouteRequest {

    // Top-level request object
    public class Request {
        @InvocableVariable(required=true)
        public List<OriginOrDestination> origins;

        @InvocableVariable(required=true)
        public List<OriginOrDestination> destinations;

        @InvocableVariable(required=true)
        public String travelMode;
    }

    // Parent object for each origin/destination
    public class OriginOrDestination {
        @InvocableVariable(required=true)
        public Waypoint waypoint;
    }

    // Waypoint wrapper
    public class Waypoint {
        @InvocableVariable(required=true)
        public Location location;
    }

    // Location wrapper
    public class Location {
        @InvocableVariable(required=true)
        public LatLng latLng;
    }

    // Lat/Lng
    public class LatLng {
        @InvocableVariable(required=true)
        public Double latitude;

        @InvocableVariable(required=true)
        public Double longitude;
    }
}