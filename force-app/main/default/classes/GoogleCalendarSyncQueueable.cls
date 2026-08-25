/**
 * Real-time path: one Booking_Form__c synced to Google Calendar in its own async transaction.
 * Enqueued (not called directly) so the callout in GoogleCalendarSyncService never runs in the
 * same transaction as the record save that triggered it - see GoogleCalendarSyncAction.
 */
public with sharing class GoogleCalendarSyncQueueable implements Queueable, Database.AllowsCallouts {
  private final Id bookingFormId;

  public GoogleCalendarSyncQueueable(Id bookingFormId) {
    this.bookingFormId = bookingFormId;
  }

  public void execute(QueueableContext context) {
    GoogleCalendarSyncService.sync(bookingFormId);
  }
}
