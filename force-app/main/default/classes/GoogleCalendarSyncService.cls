/**
 * Syncs Booking_Form__c records to their Artist's Google Calendar (one-way: Salesforce -> Google).
 *
 * - New / not yet Confirmed  -> all-day event titled "{Town} - TBC"
 * - Confirmed or Completed   -> event title becomes just "{Town}"
 * - Cancelled                -> event is deleted
 *
 * Shared by the real-time trigger path (GoogleCalendarSyncQueueable, called from Flow via
 * GoogleCalendarSyncAction) and the one-time/on-demand backfill (GoogleCalendarInitialSyncBatch),
 * so both create/update/delete events identically and both keep Artist__c's sync-status fields
 * (Google_Calendar_Last_Synced__c / Google_Calendar_Failing_Bookings__c) up to date.
 *
 * Never throws on a callout failure — records the error on
 * Booking_Form__c.Google_Calendar_Sync_Error__c instead, so a bad sync never blocks a save and is
 * always visible on the record (and triggers Booking_Form_RT_Notify_Google_Calendar_Sync_Failure).
 *
 * syncAll() does every booking's callout first, then all the DML at the end - Salesforce forbids
 * a callout after any DML in the same transaction, so processing several bookings as
 * callout-DML-callout-DML (as an earlier version of this class did, one booking at a time) throws
 * "You have uncommitted work pending" from the second record onward. sync() is a thin
 * single-record convenience wrapper around syncAll() for the real-time path, where there's only
 * ever one record and so no interleaving risk.
 */
public with sharing class GoogleCalendarSyncService {
  private static final Set<String> CONFIRMED_STAGES = new Set<String>{
    'Confirmed',
    'Completed'
  };
  private static final String CANCELLED_STAGE = 'Cancelled';

  public static void sync(Id bookingFormId) {
    syncAll(new List<Id>{ bookingFormId });
  }

  public static void syncAll(List<Id> bookingFormIds) {
    List<Booking_Form__c> bookings = [
      SELECT
        Id,
        Stage__c,
        Town_Name__c,
        Date_of_Performance__c,
        End_Date__c,
        Google_Calendar_Event_Id__c,
        Artist__c,
        Artist__r.Name,
        Artist__r.Google_Calendar_Id__c,
        Artist__r.Google_Calendar_Named_Credential__c
      FROM Booking_Form__c
      WHERE Id IN :bookingFormIds
    ];

    // Phase 1: every callout, no DML yet.
    List<Booking_Form__c> bookingsToUpdate = new List<Booking_Form__c>();
    Set<Id> artistIdsSynced = new Set<Id>();
    Set<Id> artistIdsSyncedSuccessfully = new Set<Id>();

    for (Booking_Form__c booking : bookings) {
      if (
        booking.Artist__c == null ||
        String.isBlank(booking.Artist__r.Google_Calendar_Id__c) ||
        String.isBlank(booking.Artist__r.Google_Calendar_Named_Credential__c)
      ) {
        // This artist's calendar isn't connected yet - nothing to sync to.
        continue;
      }

      String error = null;
      try {
        if (booking.Stage__c == CANCELLED_STAGE) {
          deleteEvent(booking);
        } else {
          upsertEvent(booking);
        }
      } catch (Exception e) {
        error = e.getMessage();
      }

      booking.Google_Calendar_Sync_Error__c = error;
      // Google_Calendar_Sync_Error__c is a Long Text Area, which SOQL can't filter on below -
      // this checkbox is the filterable mirror of "is there currently an error".
      booking.Google_Calendar_Sync_Failed__c = error != null;
      bookingsToUpdate.add(booking);

      artistIdsSynced.add(booking.Artist__c);
      if (error == null) {
        artistIdsSyncedSuccessfully.add(booking.Artist__c);
      }
    }

    if (bookingsToUpdate.isEmpty()) {
      return;
    }

    // Phase 2: all DML, no more callouts after this point.
    update bookingsToUpdate;
    updateArtistSyncStatus(artistIdsSynced, artistIdsSyncedSuccessfully);
  }

  private static void upsertEvent(Booking_Form__c booking) {
    Boolean confirmedOrLater = CONFIRMED_STAGES.contains(booking.Stage__c);
    String title = confirmedOrLater
      ? booking.Town_Name__c
      : booking.Town_Name__c + ' - TBC';

    Date startDate = booking.Date_of_Performance__c;
    Date endDateExclusive = (booking.End_Date__c != null
        ? booking.End_Date__c
        : startDate)
      .addDays(1);

    // String.valueOf(Date) always yields locale-independent ISO 8601 "yyyy-MM-dd" -
    // Date.format() must NOT be used here, it's locale-dependent per the running user.
    Map<String, Object> body = new Map<String, Object>{
      'summary' => title,
      'start' => new Map<String, Object>{ 'date' => String.valueOf(startDate) },
      'end' => new Map<String, Object>{
        'date' => String.valueOf(endDateExclusive)
      }
    };

    if (String.isBlank(booking.Google_Calendar_Event_Id__c)) {
      HttpResponse res = calloutJson(
        booking.Artist__r.Google_Calendar_Named_Credential__c,
        'POST',
        '/calendars/' +
          EncodingUtil.urlEncode(
            booking.Artist__r.Google_Calendar_Id__c,
            'UTF-8'
          ) +
          '/events',
        body
      );
      requireSuccess(res);
      Map<String, Object> created = (Map<String, Object>) JSON.deserializeUntyped(
        res.getBody()
      );
      booking.Google_Calendar_Event_Id__c = (String) created.get('id');
    } else {
      HttpResponse res = calloutJson(
        booking.Artist__r.Google_Calendar_Named_Credential__c,
        'PATCH',
        '/calendars/' +
          EncodingUtil.urlEncode(
            booking.Artist__r.Google_Calendar_Id__c,
            'UTF-8'
          ) +
          '/events/' +
          EncodingUtil.urlEncode(booking.Google_Calendar_Event_Id__c, 'UTF-8'),
        body
      );
      if (res.getStatusCode() == 404) {
        // The event was removed on the Google side (e.g. deleted by hand) - recreate it.
        booking.Google_Calendar_Event_Id__c = null;
        upsertEvent(booking);
        return;
      }
      requireSuccess(res);
    }
  }

  private static void deleteEvent(Booking_Form__c booking) {
    if (String.isBlank(booking.Google_Calendar_Event_Id__c)) {
      return; // Never synced (or already deleted) - nothing to do.
    }

    HttpResponse res = calloutJson(
      booking.Artist__r.Google_Calendar_Named_Credential__c,
      'DELETE',
      '/calendars/' +
        EncodingUtil.urlEncode(
          booking.Artist__r.Google_Calendar_Id__c,
          'UTF-8'
        ) +
        '/events/' +
        EncodingUtil.urlEncode(booking.Google_Calendar_Event_Id__c, 'UTF-8'),
      null
    );
    // 404/410 just means it's already gone on the Google side - treat as success.
    if (
      res.getStatusCode() != 404 &&
      res.getStatusCode() != 410 &&
      res.getStatusCode() != 204
    ) {
      requireSuccess(res);
    }
    booking.Google_Calendar_Event_Id__c = null;
  }

  private static HttpResponse calloutJson(
    String namedCredentialName,
    String method,
    String path,
    Map<String, Object> body
  ) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:' + namedCredentialName + path);
    req.setMethod(method);
    if (body != null) {
      req.setHeader('Content-Type', 'application/json');
      req.setBody(JSON.serialize(body));
    }
    return new Http().send(req);
  }

  private static void requireSuccess(HttpResponse res) {
    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
      throw new GoogleCalendarSyncException(
        'HTTP ' + res.getStatusCode() + ': ' + res.getBody()
      );
    }
  }

  /**
   * Recomputes each synced Artist's rollup status fields: last-synced timestamp (bumped only for
   * artists with at least one success in this run) and current count of failing bookings
   * (recomputed fresh for every artist touched in this run, since a success here can clear a
   * previously-failing booking just as easily as a failure can add one).
   */
  private static void updateArtistSyncStatus(
    Set<Id> artistIdsSynced,
    Set<Id> artistIdsSyncedSuccessfully
  ) {
    Map<Id, Integer> failingCountByArtistId = new Map<Id, Integer>();
    for (Id artistId : artistIdsSynced) {
      failingCountByArtistId.put(artistId, 0);
    }
    for (AggregateResult ar : [
      SELECT Artist__c artistId, COUNT(Id) failingCount
      FROM Booking_Form__c
      WHERE
        Artist__c IN :artistIdsSynced
        AND Google_Calendar_Sync_Failed__c = TRUE
      GROUP BY Artist__c
    ]) {
      failingCountByArtistId.put(
        (Id) ar.get('artistId'),
        (Integer) ar.get('failingCount')
      );
    }

    List<Artist__c> artistsToUpdate = new List<Artist__c>();
    for (Id artistId : artistIdsSynced) {
      Artist__c artist = new Artist__c(Id = artistId);
      artist.Google_Calendar_Failing_Bookings__c = failingCountByArtistId.get(
        artistId
      );
      if (artistIdsSyncedSuccessfully.contains(artistId)) {
        artist.Google_Calendar_Last_Synced__c = System.now();
      }
      artistsToUpdate.add(artist);
    }
    update artistsToUpdate;
  }

  public class GoogleCalendarSyncException extends Exception {
  }
}
