@isTest
private class FlowRecordLookupControllerTest {
  @testSetup
  static void setup() {
    insert new List<Contact>{
      new Contact(
        FirstName = 'Anna',
        LastName = 'Botha',
        Email = 'anna.botha@example.com',
        Organizer__c = true
      ),
      new Contact(
        FirstName = 'Anton',
        LastName = 'Botha',
        Email = 'anton.botha@example.com',
        Organizer__c = true
      ),
      new Contact(
        FirstName = 'Zola',
        LastName = 'Dube',
        Email = 'zola.dube@example.com',
        Organizer__c = true
      )
    };

    insert new List<Venue__c>{
      new Venue__c(Name = 'City Hall', Address__City__s = 'Pretoria'),
      new Venue__c(Name = 'City Bowl', Address__City__s = 'Cape Town')
    };
  }

  @isTest
  static void testSearchReturnsMatchingRecords_UserMode() {
    Test.startTest();
    List<SObject> results = FlowRecordLookupController.search(
      'Contact',
      'FirstName,LastName',
      'FirstName,LastName,Email',
      'Botha',
      null,
      null,
      'User Mode',
      10
    );
    Test.stopTest();

    System.assertEquals(
      2,
      results.size(),
      'Expected both Botha contacts to be returned'
    );
  }

  @isTest
  static void testSearchReturnsMatchingRecords_SystemMode() {
    Test.startTest();
    List<SObject> results = FlowRecordLookupController.search(
      'Venue__c',
      'Name,Address__City__s',
      'Name,Address__City__s',
      'City',
      null,
      null,
      'System Mode',
      10
    );
    Test.stopTest();

    System.assertEquals(
      2,
      results.size(),
      'Expected both venues matching "City" to be returned'
    );
  }

  @isTest
  static void testSearchWithFilterField() {
    Test.startTest();
    List<SObject> results = FlowRecordLookupController.search(
      'Venue__c',
      'Name',
      'Name,Address__City__s',
      'City',
      'Address__City__s',
      'Pretoria',
      'User Mode',
      10
    );
    Test.stopTest();

    System.assertEquals(
      1,
      results.size(),
      'Expected only the Pretoria venue to match the filter'
    );
    System.assertEquals(
      'Pretoria',
      (String) results[0].get('Address__City__s')
    );
  }

  @isTest
  static void testSearchRespectsMaxResultsCap() {
    Test.startTest();
    List<SObject> results = FlowRecordLookupController.search(
      'Contact',
      'LastName',
      'FirstName,LastName',
      '',
      null,
      null,
      'User Mode',
      1
    );
    Test.stopTest();

    System.assertEquals(
      1,
      results.size(),
      'Expected the result count to be capped by maxResults'
    );
  }

  @isTest
  static void testSearchRejectsUnknownObject() {
    Boolean threw = false;
    Test.startTest();
    try {
      FlowRecordLookupController.search(
        'NotARealObject__x',
        'Name',
        'Name',
        'test',
        null,
        null,
        'User Mode',
        10
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    System.assert(
      threw,
      'Expected an AuraHandledException for an unknown object API name'
    );
  }

  @isTest
  static void testSearchRejectsUnknownSearchField() {
    Boolean threw = false;
    Test.startTest();
    try {
      FlowRecordLookupController.search(
        'Contact',
        'NotARealField__x',
        'Name',
        'test',
        null,
        null,
        'User Mode',
        10
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    System.assert(
      threw,
      'Expected an AuraHandledException for an unknown search field'
    );
  }

  @isTest
  static void testSearchRejectsUnknownFilterField() {
    Boolean threw = false;
    Test.startTest();
    try {
      FlowRecordLookupController.search(
        'Contact',
        'LastName',
        'Name',
        'test',
        'NotARealField__x',
        'value',
        'User Mode',
        10
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    System.assert(
      threw,
      'Expected an AuraHandledException for an unknown filter field'
    );
  }

  @isTest
  static void testSearchRequiresAtLeastOneSearchField() {
    Boolean threw = false;
    Test.startTest();
    try {
      FlowRecordLookupController.search(
        'Contact',
        '',
        'Name',
        'test',
        null,
        null,
        'User Mode',
        10
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    System.assert(
      threw,
      'Expected an AuraHandledException when no search fields are supplied'
    );
  }
}
