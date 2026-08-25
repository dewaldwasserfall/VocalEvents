/**
 * Invocable action called from Booking_Form_RT_Sync_Google_Calendar (RecordAfterSave) whenever a
 * Booking Form is created, or its Stage, Town, Date of Performance, End Date, or Artist changes.
 *
 * Only enqueues a job per id - the actual Google Calendar callout happens later, in
 * GoogleCalendarSyncQueueable's own transaction, so this is safe to call synchronously from Flow
 * even though the triggering DML hasn't committed a new transaction yet.
 */
public with sharing class GoogleCalendarSyncAction {
  @InvocableMethod(
    label='Sync Booking Form to Google Calendar'
    description='Queues a Google Calendar sync for each Booking Form id.'
  )
  public static void syncBookings(List<Id> bookingFormIds) {
    if (GoogleCalendarSyncControl.bypassAutomaticSync) {
      return;
    }
    for (Id bookingFormId : bookingFormIds) {
      System.enqueueJob(new GoogleCalendarSyncQueueable(bookingFormId));
    }
  }
}
