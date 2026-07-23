global class UpdateTownDistanceSchedule implements Schedulable {

    global void execute(SchedulableContext sc) {
        updateTownDistances();
    }

    @future
    public static void updateTownDistances() {
        List<Town_Distance__c> townDistancesToUpdate = [
            SELECT Id, UpdateDateTime__c
            FROM Town_Distance__c
            WHERE Driving_Distance_Km__c = null
            AND Start_End__c = false
            LIMIT 100
        ];

        if (!townDistancesToUpdate.isEmpty()) {
            for (Town_Distance__c td : townDistancesToUpdate) {
                td.UpdateDateTime__c = System.now();
            }
            update townDistancesToUpdate;
        }
    }
}