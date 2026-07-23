// ContentDocumentController.cls
public with sharing class ContentDocumentController {

    @AuraEnabled(cacheable=true)
    public static ContentDocument getCallsheetImageDocument(Id bookingFormId) {
        // Query ContentDocumentLink related to the Booking_Form__c record
        List<ContentDocumentLink> docLinks = [
            SELECT ContentDocument.Title, ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :bookingFormId
        ];

        // Loop through to find the ContentDocument where the title is 'callsheetimage'
        for (ContentDocumentLink link : docLinks) {
            if (link.ContentDocument.Title == 'callsheetimage') {
                // Return the found ContentDocument
                return [
                    SELECT Id, Title, FileType, LatestPublishedVersionId 
                    FROM ContentDocument 
                    WHERE Id = :link.ContentDocumentId
                    LIMIT 1
                ];
            }
        }
        return null;
    }
}