/**
 * Lets test code (or a future data-load script) suppress Booking_Form_RT_Sync_Google_Calendar's
 * automatic invocation of GoogleCalendarSyncAction, the same way this org already uses
 * Booking_Form__c.BypassValidation__c/AutomationDateTime__c to bypass other automation during
 * bulk operations. Needed because Apex tests that call GoogleCalendarSyncService/Queueable/Action
 * directly would otherwise also race against the real deployed Flow firing on the same
 * insert/update, double-syncing the same booking.
 *
 * Does not affect direct calls to GoogleCalendarSyncService, GoogleCalendarSyncQueueable, or
 * GoogleCalendarSyncAction - only the Flow's own automatic path checks this flag.
 */
public class GoogleCalendarSyncControl {
  public static Boolean bypassAutomaticSync = false;
}
