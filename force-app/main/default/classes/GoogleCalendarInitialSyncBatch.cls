/**
 * One-time (or on-demand) backfill: syncs every existing, non-cancelled Booking_Form__c to its
 * Artist's Google Calendar, using the exact same create/update logic as the real-time path
 * (GoogleCalendarSyncService), so nothing drifts between "new booking today" and "booking from
 * six months ago that never had an event".
 *
 * Not wired to any button/UI - it's an admin operation, run as needed via anonymous Apex:
 *
 *   Database.executeBatch(new GoogleCalendarInitialSyncBatch(), 25);                    // everyone
 *   Database.executeBatch(new GoogleCalendarInitialSyncBatch(artistId), 25);            // one artist
 *   Database.executeBatch(new GoogleCalendarInitialSyncBatch(null, true), 25);          // retry every currently-failing booking
 */
public with sharing class GoogleCalendarInitialSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
  private final Id artistId;
  private final Boolean onlyRetryFailed;

  public GoogleCalendarInitialSyncBatch() {
    this(null, false);
  }

  public GoogleCalendarInitialSyncBatch(Id artistId) {
    this(artistId, false);
  }

  public GoogleCalendarInitialSyncBatch(Id artistId, Boolean onlyRetryFailed) {
    this.artistId = artistId;
    this.onlyRetryFailed = onlyRetryFailed == true;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    String query =
      'SELECT Id FROM Booking_Form__c ' +
      'WHERE Stage__c != \'Cancelled\' AND Artist__r.Google_Calendar_Id__c != null';
    if (artistId != null) {
      query += ' AND Artist__c = :artistId';
    }
    if (onlyRetryFailed) {
      query += ' AND Google_Calendar_Sync_Failed__c = true';
    }
    return Database.getQueryLocator(query);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    // One syncAll() call per chunk, not one sync() call per record - Salesforce forbids a
    // callout after any DML in the same transaction, and processing bookings one at a time
    // (callout, DML, callout, DML...) would fail on the second record onward.
    List<Id> bookingFormIds = new List<Id>();
    for (SObject record : scope) {
      bookingFormIds.add(record.Id);
    }
    GoogleCalendarSyncService.syncAll(bookingFormIds);
  }

  public void finish(Database.BatchableContext context) {
  }
}
