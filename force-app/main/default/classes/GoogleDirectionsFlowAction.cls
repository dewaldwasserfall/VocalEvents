public with sharing class GoogleDirectionsFlowAction {
  // Wrapper for Flow input
  public class DirectionsRequest {
    @InvocableVariable(label='Origin (lat,lng or address)')
    public String origin;

    @InvocableVariable(label='Destination (lat,lng or address)')
    public String destination;

    @InvocableVariable(
      label='Travel mode (driving, walking, bicycling, transit)'
    )
    public String mode = 'driving';
  }

  // Wrapper for Flow output
  public class DirectionsResponse {
    @InvocableVariable(label='Distance in meters')
    public Integer distanceMeters;

    @InvocableVariable(label='Distance text')
    public String distanceText;

    @InvocableVariable(label='Duration in seconds')
    public Integer durationSeconds;

    @InvocableVariable(label='Duration text')
    public String durationText;

    @InvocableVariable(label='Status')
    public String status;
  }

  // Invocable method callable from Flow
  @InvocableMethod(
    label='Get Google Directions Distance & Duration'
    description='Calls Google Directions API and returns distance and duration for Flow'
  )
  public static List<DirectionsResponse> getDirections(
    List<DirectionsRequest> requests
  ) {
    List<DirectionsResponse> results = new List<DirectionsResponse>();

    for (DirectionsRequest req : requests) {
      DirectionsResponse res = new DirectionsResponse();
      try {
        // Construct Google Directions API path (no key here — the Named
        // Credential's External Credential injects the API key as an
        // Authorization header automatically on callout).
        String path =
          '/maps/api/directions/json' +
          '?origin=' +
          EncodingUtil.urlEncode(req.origin, 'UTF-8') +
          '&destination=' +
          EncodingUtil.urlEncode(req.destination, 'UTF-8') +
          '&mode=' +
          EncodingUtil.urlEncode(req.mode, 'UTF-8');

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:GoogleMapsNamedCredential' + path);
        request.setMethod('GET');

        HttpResponse response = http.send(request);

        if (response.getStatusCode() == 200) {
          Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
          );

          res.status = (String) jsonMap.get('status');

          if (res.status == 'OK') {
            List<Object> routes = (List<Object>) jsonMap.get('routes');
            if (!routes.isEmpty()) {
              Map<String, Object> firstRoute = (Map<String, Object>) routes[0];
              List<Object> legs = (List<Object>) firstRoute.get('legs');
              if (!legs.isEmpty()) {
                Map<String, Object> firstLeg = (Map<String, Object>) legs[0];

                Map<String, Object> distance = (Map<String, Object>) firstLeg.get(
                  'distance'
                );
                Map<String, Object> duration = (Map<String, Object>) firstLeg.get(
                  'duration'
                );

                res.distanceMeters = ((Decimal) distance.get('value'))
                  .intValue();
                res.durationSeconds = ((Decimal) duration.get('value'))
                  .intValue();
              }
            }
          }
        } else {
          res.status =
            'HTTP ' +
            response.getStatusCode() +
            ': ' +
            response.getStatus();
        }
      } catch (Exception e) {
        res.status = 'Error: ' + e.getMessage();
      }

      results.add(res);
    }

    return results;
  }
}
