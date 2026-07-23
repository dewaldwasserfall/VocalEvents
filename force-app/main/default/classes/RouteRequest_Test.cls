@IsTest
public class RouteRequest_Test {
    @IsTest
    static void testRouteRequestStructure() {

        // --- Build LatLng for Origin ---
        RouteRequest.LatLng originLatLng = new RouteRequest.LatLng();
        originLatLng.latitude = 48.8584;
        originLatLng.longitude = 2.2945;

        RouteRequest.Location originLocation = new RouteRequest.Location();
        originLocation.latLng = originLatLng;

        RouteRequest.Waypoint originWaypoint = new RouteRequest.Waypoint();
        originWaypoint.location = originLocation;

        RouteRequest.OriginOrDestination origin = new RouteRequest.OriginOrDestination();
        origin.waypoint = originWaypoint;

        // --- Build LatLng for Destination ---
        RouteRequest.LatLng destLatLng = new RouteRequest.LatLng();
        destLatLng.latitude = 51.5007;
        destLatLng.longitude = 0.1246;

        RouteRequest.Location destLocation = new RouteRequest.Location();
        destLocation.latLng = destLatLng;

        RouteRequest.Waypoint destWaypoint = new RouteRequest.Waypoint();
        destWaypoint.location = destLocation;

        RouteRequest.OriginOrDestination dest = new RouteRequest.OriginOrDestination();
        dest.waypoint = destWaypoint;

        // --- Build Request ---
        RouteRequest.Request req = new RouteRequest.Request();
        req.origins = new List<RouteRequest.OriginOrDestination>{ origin };
        req.destinations = new List<RouteRequest.OriginOrDestination>{ dest };
        req.travelMode = 'DRIVE';

        // --- Validate fields ---
        System.assertEquals(48.8584, req.origins[0].waypoint.location.latLng.latitude);
        System.assertEquals(2.2945, req.origins[0].waypoint.location.latLng.longitude);

        System.assertEquals(51.5007, req.destinations[0].waypoint.location.latLng.latitude);
        System.assertEquals(0.1246, req.destinations[0].waypoint.location.latLng.longitude);

        System.assertEquals('DRIVE', req.travelMode);

        // --- Validate JSON serializes without errors ---
        String jsonOut = JSON.serialize(req);
        System.assert(jsonOut.contains('"travelMode":"DRIVE"'));
        System.assert(jsonOut.contains('"latitude":48.8584'));
        System.assert(jsonOut.contains('"longitude":2.2945'));
    }
}