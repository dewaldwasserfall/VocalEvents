@isTest
private class AddressParserTest {
    // Test method to verify the parsing of address
    @isTest
    static void testParseAddress() {
        // Create test data
        List<AddressParser.AddressInput> inputAddresses = new List<AddressParser.AddressInput>();
        AddressParser.AddressInput input = new AddressParser.AddressInput();
        input.address = '123 Main St, Springfield, IL, 62701';
        inputAddresses.add(input);
        
        // Mock callout response
        HttpCalloutMock mock = new AddressParserMock();
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Call the parseAddress method
        Test.startTest();
        List<AddressParser.AddressOutput> result = AddressParser.parseAddress(inputAddresses);
        Test.stopTest();
        
        // Verify the result
        System.assertEquals('123 Main St', result[0].street);
        System.assertEquals('Springfield', result[0].city);
        System.assertEquals('62701', result[0].postalCode);
        System.assertEquals('IL', result[0].country);
    }
}