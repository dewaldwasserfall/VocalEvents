public class AddressParser {
    
    @InvocableMethod(label='Parse Address' description='Parses the address string and returns address components')
    public static List<AddressOutput> parseAddress(List<AddressInput> inputAddresses) {
        List<AddressOutput> addressOutputs = new List<AddressOutput>();
        
        for (AddressInput input : inputAddresses) {
            AddressInfoWrapper addressInfo = parseSingleAddress(input.address);
            AddressOutput result = new AddressOutput();
            result.street = addressInfo.parsedStreet;
            result.city = addressInfo.parsedCity;
            result.postalCode = addressInfo.parsedPostalCode;
            result.country = addressInfo.parsedCountry;
            addressOutputs.add(result);
        }
        
        return addressOutputs;
    }

    private static AddressInfoWrapper parseSingleAddress(String address) {
        AddressInfoWrapper addressInfoWrapper = new AddressInfoWrapper();
        
        // Perform the API callout
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('http://dev.virtualearth.net/REST/v1/Locations?addressLine=' + EncodingUtil.urlEncode(address, 'UTF-8') + '&key=AvPF_6t43Fi26jlqspksaMzSYlxa1vQYjivUJHavj1JO3E3UiAM1kaQ8PKzj2S5s');
        request.setMethod('GET');
        HttpResponse response = http.send(request);
        
        // Parse the response
        if (response.getStatusCode() == 200) {
            // Parse the response body and extract the address components
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            List<Object> resourceSets = (List<Object>) responseBody.get('resourceSets');
            if (!resourceSets.isEmpty()) {
                Map<String, Object> resourceSet = (Map<String, Object>) resourceSets[0];
                List<Object> resources = (List<Object>) resourceSet.get('resources');
                if (!resources.isEmpty()) {
                    Map<String, Object> resource = (Map<String, Object>) resources[0];
                    Map<String, Object> addressInfo = (Map<String, Object>) resource.get('address');

                    addressInfoWrapper.parsedStreet = (String) addressInfo.get('addressLine');
                    addressInfoWrapper.parsedCity = (String) addressInfo.get('locality');
                    addressInfoWrapper.parsedPostalCode = (String) addressInfo.get('postalCode');
                    addressInfoWrapper.parsedCountry = (String) addressInfo.get('countryRegion');
                }
            }
        }
        
        return addressInfoWrapper;
    }

    // Inner class to hold address information
    public class AddressInfoWrapper {
        public String parsedStreet;
        public String parsedCity;
        public String parsedPostalCode;
        public String parsedCountry;

        public AddressInfoWrapper() {
            parsedStreet = '';
            parsedCity = '';
            parsedPostalCode = '';
            parsedCountry = '';
        }
    }

    // Inner class to represent input addresses
    public class AddressInput {
        @InvocableVariable(label='Address' description='The address to parse' required=true)
        public String address;
    }

    // Inner class to represent output data
    public class AddressOutput {
        @InvocableVariable(label='Street' description='Street from address')
        public String street;
        
        @InvocableVariable(label='City' description='City from address')
        public String city;
        
        @InvocableVariable(label='Postal Code' description='Postal code from address')
        public String postalCode;
        
        @InvocableVariable(label='Country' description='Country from address')
        public String country;
    }
}