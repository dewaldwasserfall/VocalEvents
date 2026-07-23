@isTest
public class ContentDocumentControllerTest {

    @isTest(SeeAllData=true)
    static void testGetCallsheetImageDocument_Found() {
        // Create required records if they do not already exist
        Contact testAgent = [SELECT Id FROM Contact WHERE Agent__c = true LIMIT 1];
        if (testAgent == null) {
            testAgent = new Contact(FirstName = 'Test', LastName = 'Agent', Agent__c = true);
            insert testAgent;
        }

        // Create a test Artist__c record
        Artist__c testArtist = [SELECT Id FROM Artist__c LIMIT 1];

        // Create and insert a test Booking_Form__c record
        Booking_Form__c testBookingForm = new Booking_Form__c(
            Name = 'Test Booking Form',
            Agent__c = testAgent.Id,
            Artist__c = testArtist.Id,
            Date_of_Performance__c = Date.today()
        );
        insert testBookingForm;

        // Create and insert a ContentVersion with title 'callsheetimage'
        ContentVersion callsheetVersion = new ContentVersion(
            Title = 'callsheetimage',
            PathOnClient = 'callsheet.png',
            VersionData = Blob.valueOf('Test content for callsheet image'),
            IsMajorVersion = true
        );
        insert callsheetVersion;

        // Query the ContentVersion to get ContentDocumentId
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :callsheetVersion.Id LIMIT 1];

        // Create and insert a ContentDocumentLink for the 'callsheetimage'
        ContentDocumentLink callsheetLink = new ContentDocumentLink(
            LinkedEntityId = testBookingForm.Id, 
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'I'
        );
        insert callsheetLink;

        // Execute the method to test
        Test.startTest();
        ContentDocument result = ContentDocumentController.getCallsheetImageDocument(testBookingForm.Id);
        Test.stopTest();

        // Assert that the document was found and its title is 'callsheetimage'
        System.assertNotEquals(null, result, 'Expected to find a ContentDocument with the title "callsheetimage".');
        System.assertEquals('callsheetimage', result.Title, 'The document title should be "callsheetimage".');
    }

    @isTest(SeeAllData=true)
    static void testGetCallsheetImageDocument_NotFound() {
        // Create required records if they do not already exist
        Contact testAgent = [SELECT Id FROM Contact WHERE Agent__c = true LIMIT 1];
        if (testAgent == null) {
            testAgent = new Contact(FirstName = 'Test', LastName = 'Agent', Agent__c = true);
            insert testAgent;
        }

        // Create a test Artist__c record
        Artist__c testArtist = [SELECT Id FROM Artist__c LIMIT 1];

        // Create and insert a test Booking_Form__c record
        Booking_Form__c noImageBookingForm = new Booking_Form__c(
            Name = 'No Image Booking Form',
            Agent__c = testAgent.Id,
            Artist__c = testArtist.Id,
            Date_of_Performance__c = Date.today()
        );
        insert noImageBookingForm;

        // Ensure no ContentDocument with title 'callsheetimage' is linked to this record
        // Execute the method to test
        Test.startTest();
        ContentDocument result = ContentDocumentController.getCallsheetImageDocument(noImageBookingForm.Id);
        Test.stopTest();

        // Assert that no document was found
        System.assertEquals(null, result, 'Expected no ContentDocument to be found for this Booking_Form__c.');
    }
}