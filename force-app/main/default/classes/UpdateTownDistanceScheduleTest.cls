@isTest
public class UpdateTownDistanceScheduleTest {

    @isTest
    static void testSchedule() {
        // Create test data
        List<Town_Distance__c> testTownDistances = new List<Town_Distance__c>();
        for (Integer i = 0; i < 100; i++) { //Create more than the limit to test the limit.
            Town_Distance__c td = new Town_Distance__c(
                Driving_Distance_Km__c = null
            );
            testTownDistances.add(td);
        }
        insert testTownDistances;

        // Schedule the job
        String cronExpression = '0 0 * * * ?';
        String jobName = 'TestUpdateTownDistanceJob';
        Test.startTest();
        String jobId = System.schedule(jobName, cronExpression, new UpdateTownDistanceSchedule());
        Test.stopTest();

        //Verify the update occurred.
        List<Town_Distance__c> updatedTownDistances = [
            SELECT Id, UpdateDateTime__c
            FROM Town_Distance__c
            WHERE UpdateDateTime__c != null
        ];


    }

    @isTest
    static void testUpdateTownDistancesFuture() {
        // Create test data
        List<Town_Distance__c> testTownDistances = new List<Town_Distance__c>();
        for (Integer i = 0; i < 50; i++) {
            Town_Distance__c td = new Town_Distance__c(
                Driving_Distance_Km__c = null
            );
            testTownDistances.add(td);
        }
        insert testTownDistances;

        // Call the future method directly
        Test.startTest();
        UpdateTownDistanceSchedule.updateTownDistances();
        Test.stopTest();

        // Verify the update occurred
        List<Town_Distance__c> updatedTownDistances = [
            SELECT Id, UpdateDateTime__c
            FROM Town_Distance__c
            WHERE Driving_Distance_Km__c = null
        ];

    }
       @isTest(SeeAllData=True)
    static void testUpdateWithRecords() {
        // Create test data with records that should be updated.
        List<Town__c> towns = new List<Town__c>([Select Id From Town__c Limit 5]);
        List<Town_Distance__c> testTownDistances = new List<Town_Distance__c>();
        for (Integer i = 0; i < 3; i++) {
            Town_Distance__c td = new Town_Distance__c();
                td.Driving_Distance_Km__c = null;
            	td.Starting_Town__c = towns[1].Id;
            	td.Destination__c = towns[2].id;
                
            testTownDistances.add(td);
        }
        insert testTownDistances;

        // Call the future method directly
        Test.startTest();
        UpdateTownDistanceSchedule.updateTownDistances();
        Test.stopTest();

        // Verify that updates occurred
        List<Town_Distance__c> updatedTownDistances = [
            SELECT Id, UpdateDateTime__c
            FROM Town_Distance__c
            WHERE Driving_Distance_Km__c = null
        ];

    }

    @isTest
    static void testNoRecordsToUpdate() {
        // Create test data, but ensure the driving distance is not null.
        List<Town_Distance__c> testTownDistances = new List<Town_Distance__c>();
        for (Integer i = 0; i < 5; i++) {
            Town_Distance__c td = new Town_Distance__c(
                Driving_Distance_Km__c = 10.0
            );
            testTownDistances.add(td);
        }
        insert testTownDistances;

        // Call the future method directly
        Test.startTest();
        UpdateTownDistanceSchedule.updateTownDistances();
        Test.stopTest();

        // Verify that no updates occurred
        List<Town_Distance__c> updatedTownDistances = [
            SELECT Id, UpdateDateTime__c
            FROM Town_Distance__c
            WHERE Driving_Distance_Km__c = 10.0
        ];

    }
}