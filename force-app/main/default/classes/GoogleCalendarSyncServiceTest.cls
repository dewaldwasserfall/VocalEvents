/**
 * Covers GoogleCalendarSyncService directly, plus the thin wrappers around it
 * (GoogleCalendarSyncQueueable, GoogleCalendarSyncAction, GoogleCalendarInitialSyncBatch).
 *
 * NOTE: Booking_Form__c already carries a lot of unrelated Record-Triggered Flow automation in
 * this org (travel distance lookups, PDF Butler naming, callsheet emails, etc.). These tests
 * insert the minimum required fields for a valid Booking Form and don't attempt to bypass that
 * other automation. If running this test class surfaces a failure that traces back to one of
 * those unrelated flows rather than to GoogleCalendarSyncService, the fix is to seed whatever
 * supporting record that flow expects (or bypass it) - not a sign this feature's logic is wrong.
 */
@IsTest
public class GoogleCalendarSyncServiceTest {
  private static final String NAMED_CREDENTIAL = 'GoogleCal_RicusNel_NamedCred';

  /**
   * Configurable HttpCalloutMock standing in for the Google Calendar API: POST "creates" an
   * event (returns createdEventId), PATCH "updates" one (unless patchStatusCode says otherwise -
   * used to simulate the event having been removed on the Google side), DELETE "removes" one.
   */
  private class CalendarApiMock implements HttpCalloutMock {
    public Integer postStatusCode = 200;
    public Integer patchStatusCode = 200;
    public Integer deleteStatusCode = 204;
    public String createdEventId = 'evt-created-1';
    public List<HttpRequest> requestLog = new List<HttpRequest>();

    public HttpResponse respond(HttpRequest req) {
      requestLog.add(req);
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (req.getMethod() == 'POST') {
        res.setStatusCode(postStatusCode);
        res.setBody(
          postStatusCode == 200
            ? '{"id":"' + createdEventId + '"}'
            : '{"error":"mock post failure"}'
        );
      } else if (req.getMethod() == 'PATCH') {
        res.setStatusCode(patchStatusCode);
        res.setBody(
          patchStatusCode == 200
            ? '{"id":"existing-evt"}'
            : '{"error":"mock patch failure"}'
        );
      } else if (req.getMethod() == 'DELETE') {
        res.setStatusCode(deleteStatusCode);
        res.setBody('');
      }
      return res;
    }
  }

  private static Artist__c makeArtist(String name, String calendarId) {
    Town__c homeTown = makeTown(name + ' Home Town');
    Account invoiceAccount = new Account(
      Name = name + ' Invoice Account',
      Can_send_Quotes_and_Invoices__c = true
    );
    insert invoiceAccount;

    Artist__c artist = new Artist__c(
      Name = name,
      Email__c = name.replace(' ', '.').toLowerCase() + '@example.com',
      Is_Active__c = true,
      Home_Town__c = homeTown.Id,
      Invoice_Account__c = invoiceAccount.Id,
      Invoice_Type__c = 'Invoice',
      Google_Calendar_Id__c = calendarId,
      Google_Calendar_Named_Credential__c = NAMED_CREDENTIAL
    );
    insert artist;
    return artist;
  }

  private static Booking_Form__c makeBooking(
    Artist__c artist,
    Contact agent,
    Town__c town,
    String stage,
    String existingEventId
  ) {
    return makeBooking(
      artist,
      agent,
      town,
      stage,
      existingEventId,
      Date.today().addDays(30)
    );
  }

  // Overload for tests that create more than one booking for the same Artist - Booking_Form__c
  // has a duplicate rule on Artist+Date, so each needs its own Date_of_Performance__c.
  private static Booking_Form__c makeBooking(
    Artist__c artist,
    Contact agent,
    Town__c town,
    String stage,
    String existingEventId,
    Date performanceDate
  ) {
    Booking_Form__c booking = new Booking_Form__c(
      Artist__c = artist.Id,
      Agent__c = agent.Id,
      Town_or_City__c = town.Id,
      Date_of_Performance__c = performanceDate,
      Stage__c = stage,
      Google_Calendar_Event_Id__c = existingEventId
    );
    insert booking;
    return booking;
  }

  private static Contact makeAgent() {
    Contact agent = new Contact(
      LastName = 'Test Agent',
      Email = 'test.agent.gcalsync@example.com',
      Agent__c = true
    );
    insert agent;
    return agent;
  }

  private static Town__c makeTown(String name) {
    Town__c town = new Town__c(
      Name = name,
      Province__c = 'North West',
      Geolocation__Latitude__s = -26.8659,
      Geolocation__Longitude__s = 26.6666
    );
    insert town;
    return town;
  }

  @IsTest
  static void testSync_createsEventWithTbcTitleOnNewBooking() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artist = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Booking_Form__c booking = makeBooking(artist, agent, town, 'New', null);

    CalendarApiMock mock = new CalendarApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    GoogleCalendarSyncService.sync(booking.Id);
    Test.stopTest();

    Booking_Form__c result = [
      SELECT
        Google_Calendar_Event_Id__c,
        Google_Calendar_Sync_Error__c,
        Google_Calendar_Sync_Failed__c
      FROM Booking_Form__c
      WHERE Id = :booking.Id
    ];
    System.assertEquals(
      mock.createdEventId,
      result.Google_Calendar_Event_Id__c,
      'Event id returned by the create callout should be saved back onto the booking'
    );
    System.assertEquals(
      null,
      result.Google_Calendar_Sync_Error__c,
      'A successful sync should leave no error'
    );
    System.assertEquals(false, result.Google_Calendar_Sync_Failed__c);
    System.assertEquals(1, mock.requestLog.size());
    System.assertEquals('POST', mock.requestLog[0].getMethod());
    System.assert(
      mock.requestLog[0].getBody().contains('"summary":"Klerksdorp - TBC"'),
      'A New booking should create an all-day event titled "{Town} - TBC"'
    );

    Artist__c artistAfter = [
      SELECT Google_Calendar_Last_Synced__c, Google_Calendar_Failing_Bookings__c
      FROM Artist__c
      WHERE Id = :artist.Id
    ];
    System.assertNotEquals(
      null,
      artistAfter.Google_Calendar_Last_Synced__c,
      'A successful sync should stamp the artist as last-synced'
    );
    System.assertEquals(0, artistAfter.Google_Calendar_Failing_Bookings__c);
  }

  @IsTest
  static void testSync_updatesTitleToJustTownWhenConfirmed() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artist = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Booking_Form__c booking = makeBooking(
      artist,
      agent,
      town,
      'Confirmed',
      'existing-evt'
    );

    CalendarApiMock mock = new CalendarApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    GoogleCalendarSyncService.sync(booking.Id);
    Test.stopTest();

    System.assertEquals(1, mock.requestLog.size());
    System.assertEquals(
      'PATCH',
      mock.requestLog[0].getMethod(),
      'A booking that already has an event id should be updated, not re-created'
    );
    System.assert(
      mock.requestLog[0].getBody().contains('"summary":"Klerksdorp"') &&
      !mock.requestLog[0].getBody().contains('TBC'),
      'Confirmed should drop the " - TBC" suffix'
    );

    Booking_Form__c result = [
      SELECT Google_Calendar_Sync_Error__c
      FROM Booking_Form__c
      WHERE Id = :booking.Id
    ];
    System.assertEquals(null, result.Google_Calendar_Sync_Error__c);
  }

  @IsTest
  static void testSync_recreatesEventWhenGoogleSideEventIsGone() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artist = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Booking_Form__c booking = makeBooking(
      artist,
      agent,
      town,
      'Completed',
      'deleted-on-google-side'
    );

    CalendarApiMock mock = new CalendarApiMock();
    mock.patchStatusCode = 404; // simulate the event having been removed manually on Google
    mock.createdEventId = 'evt-recreated';
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    GoogleCalendarSyncService.sync(booking.Id);
    Test.stopTest();

    System.assertEquals(
      2,
      mock.requestLog.size(),
      'A 404 on PATCH should fall back to creating a new event'
    );
    System.assertEquals('PATCH', mock.requestLog[0].getMethod());
    System.assertEquals('POST', mock.requestLog[1].getMethod());

    Booking_Form__c result = [
      SELECT Google_Calendar_Event_Id__c, Google_Calendar_Sync_Error__c
      FROM Booking_Form__c
      WHERE Id = :booking.Id
    ];
    System.assertEquals('evt-recreated', result.Google_Calendar_Event_Id__c);
    System.assertEquals(null, result.Google_Calendar_Sync_Error__c);
  }

  @IsTest
  static void testSync_deletesEventWhenCancelled() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artist = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Booking_Form__c booking = makeBooking(
      artist,
      agent,
      town,
      'Cancelled',
      'existing-evt'
    );

    CalendarApiMock mock = new CalendarApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    GoogleCalendarSyncService.sync(booking.Id);
    Test.stopTest();

    System.assertEquals(1, mock.requestLog.size());
    System.assertEquals('DELETE', mock.requestLog[0].getMethod());

    Booking_Form__c result = [
      SELECT Google_Calendar_Event_Id__c, Google_Calendar_Sync_Error__c
      FROM Booking_Form__c
      WHERE Id = :booking.Id
    ];
    System.assertEquals(
      null,
      result.Google_Calendar_Event_Id__c,
      'The stored event id should be cleared once the event is deleted'
    );
    System.assertEquals(null, result.Google_Calendar_Sync_Error__c);
  }

  @IsTest
  static void testSync_cancelledWithNoExistingEventIsANoop() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artist = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Booking_Form__c booking = makeBooking(
      artist,
      agent,
      town,
      'Cancelled',
      null
    );

    CalendarApiMock mock = new CalendarApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    GoogleCalendarSyncService.sync(booking.Id);
    Test.stopTest();

    System.assertEquals(
      0,
      mock.requestLog.size(),
      'Cancelling a booking that never had an event should make no callout'
    );
  }

  @IsTest
  static void testSync_recordsErrorAndBumpsArtistFailingCountOnHttpFailure() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artist = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Booking_Form__c booking = makeBooking(artist, agent, town, 'New', null);

    CalendarApiMock mock = new CalendarApiMock();
    mock.postStatusCode = 500;
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    GoogleCalendarSyncService.sync(booking.Id);
    Test.stopTest();

    Booking_Form__c result = [
      SELECT Google_Calendar_Sync_Error__c, Google_Calendar_Sync_Failed__c
      FROM Booking_Form__c
      WHERE Id = :booking.Id
    ];
    System.assertNotEquals(null, result.Google_Calendar_Sync_Error__c);
    System.assertEquals(true, result.Google_Calendar_Sync_Failed__c);

    Artist__c artistAfter = [
      SELECT Google_Calendar_Last_Synced__c, Google_Calendar_Failing_Bookings__c
      FROM Artist__c
      WHERE Id = :artist.Id
    ];
    System.assertEquals(
      null,
      artistAfter.Google_Calendar_Last_Synced__c,
      'A failed sync should not update the last-synced timestamp'
    );
    System.assertEquals(1, artistAfter.Google_Calendar_Failing_Bookings__c);
  }

  @IsTest
  static void testSync_skipsArtistsWithNoCalendarConfigured() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artist = makeArtist('Unconnected Artist', null);
    artist.Google_Calendar_Id__c = null;
    artist.Google_Calendar_Named_Credential__c = null;
    update artist;
    Booking_Form__c booking = makeBooking(artist, agent, town, 'New', null);

    CalendarApiMock mock = new CalendarApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    GoogleCalendarSyncService.sync(booking.Id);
    Test.stopTest();

    System.assertEquals(
      0,
      mock.requestLog.size(),
      'An artist with no connected calendar should make no callout at all'
    );
  }

  @IsTest
  static void testQueueable_syncsTheBookingItWasGivenById() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artist = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Booking_Form__c booking = makeBooking(artist, agent, town, 'New', null);

    Test.setMock(HttpCalloutMock.class, new CalendarApiMock());

    Test.startTest();
    System.enqueueJob(new GoogleCalendarSyncQueueable(booking.Id));
    Test.stopTest();

    Booking_Form__c result = [
      SELECT Google_Calendar_Event_Id__c
      FROM Booking_Form__c
      WHERE Id = :booking.Id
    ];
    System.assertNotEquals(null, result.Google_Calendar_Event_Id__c);
  }

  @IsTest
  static void testAction_enqueuesOneJobPerBookingAndBothSync() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artist = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Booking_Form__c bookingA = makeBooking(artist, agent, town, 'New', null);
    Booking_Form__c bookingB = makeBooking(
      artist,
      agent,
      town,
      'New',
      null,
      Date.today().addDays(31)
    );

    Test.setMock(HttpCalloutMock.class, new CalendarApiMock());

    Test.startTest();
    // This is the one test exercising GoogleCalendarSyncAction itself (the Flow's own call
    // path), so un-suppress it for this explicit call.
    GoogleCalendarSyncControl.bypassAutomaticSync = false;
    GoogleCalendarSyncAction.syncBookings(
      new List<Id>{ bookingA.Id, bookingB.Id }
    );
    Test.stopTest();

    Map<Id, Booking_Form__c> results = new Map<Id, Booking_Form__c>(
      [
        SELECT Google_Calendar_Event_Id__c
        FROM Booking_Form__c
        WHERE Id IN (:bookingA.Id, :bookingB.Id)
      ]
    );
    System.assertNotEquals(
      null,
      results.get(bookingA.Id).Google_Calendar_Event_Id__c
    );
    System.assertNotEquals(
      null,
      results.get(bookingB.Id).Google_Calendar_Event_Id__c
    );
  }

  @IsTest
  static void testBatch_allArtistsSyncsEveryNonCancelledBooking() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artistOne = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Artist__c artistTwo = makeArtist('Dassie', 'dassie.musiek@gmail.com');
    Booking_Form__c bookingOne = makeBooking(
      artistOne,
      agent,
      town,
      'New',
      null
    );
    Booking_Form__c bookingTwo = makeBooking(
      artistTwo,
      agent,
      town,
      'New',
      null
    );
    Booking_Form__c cancelledBooking = makeBooking(
      artistOne,
      agent,
      town,
      'Cancelled',
      null,
      Date.today().addDays(31)
    );

    Test.setMock(HttpCalloutMock.class, new CalendarApiMock());

    Test.startTest();
    Database.executeBatch(new GoogleCalendarInitialSyncBatch(), 25);
    Test.stopTest();

    Map<Id, Booking_Form__c> results = new Map<Id, Booking_Form__c>(
      [
        SELECT Google_Calendar_Event_Id__c, Google_Calendar_Sync_Error__c
        FROM Booking_Form__c
        WHERE Id IN (:bookingOne.Id, :bookingTwo.Id, :cancelledBooking.Id)
      ]
    );
    System.assertNotEquals(
      null,
      results.get(bookingOne.Id).Google_Calendar_Event_Id__c,
      'bookingOne error was: ' +
      results.get(bookingOne.Id).Google_Calendar_Sync_Error__c
    );
    System.assertNotEquals(
      null,
      results.get(bookingTwo.Id).Google_Calendar_Event_Id__c,
      'bookingTwo error was: ' +
      results.get(bookingTwo.Id).Google_Calendar_Sync_Error__c
    );
    System.assertEquals(
      null,
      results.get(cancelledBooking.Id).Google_Calendar_Event_Id__c,
      'A Cancelled booking has nothing to delete and should stay untouched'
    );
  }

  @IsTest
  static void testBatch_scopedToOneArtistOnlySyncsThatArtist() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artistOne = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Artist__c artistTwo = makeArtist('Dassie', 'dassie.musiek@gmail.com');
    Booking_Form__c bookingOne = makeBooking(
      artistOne,
      agent,
      town,
      'New',
      null
    );
    Booking_Form__c bookingTwo = makeBooking(
      artistTwo,
      agent,
      town,
      'New',
      null
    );

    Test.setMock(HttpCalloutMock.class, new CalendarApiMock());

    Test.startTest();
    Database.executeBatch(new GoogleCalendarInitialSyncBatch(artistOne.Id), 25);
    Test.stopTest();

    Map<Id, Booking_Form__c> results = new Map<Id, Booking_Form__c>(
      [
        SELECT Google_Calendar_Event_Id__c
        FROM Booking_Form__c
        WHERE Id IN (:bookingOne.Id, :bookingTwo.Id)
      ]
    );
    System.assertNotEquals(
      null,
      results.get(bookingOne.Id).Google_Calendar_Event_Id__c
    );
    System.assertEquals(
      null,
      results.get(bookingTwo.Id).Google_Calendar_Event_Id__c,
      'Scoping the batch to one artist should leave other artists\' bookings alone'
    );
  }

  @IsTest
  static void testBatch_onlyRetryFailedSkipsAlreadyHealthyBookings() {
    // Booking_Form_RT_Sync_Google_Calendar is a real, active Flow in this org - without this,
    // every insert/update below would ALSO enqueue a real sync job that races against this
    // test's own explicit calls. See GoogleCalendarSyncControl.
    GoogleCalendarSyncControl.bypassAutomaticSync = true;
    Contact agent = makeAgent();
    Town__c town = makeTown('Klerksdorp');
    Artist__c artist = makeArtist('Ricus Nel', 'ricusnel7@gmail.com');
    Booking_Form__c healthyBooking = makeBooking(
      artist,
      agent,
      town,
      'New',
      'already-synced-evt'
    );
    Booking_Form__c failingBooking = makeBooking(
      artist,
      agent,
      town,
      'New',
      null,
      Date.today().addDays(31)
    );
    failingBooking.Google_Calendar_Sync_Failed__c = true;
    failingBooking.Google_Calendar_Sync_Error__c = 'HTTP 500: previous failure';
    update failingBooking;

    Test.setMock(HttpCalloutMock.class, new CalendarApiMock());

    Test.startTest();
    Database.executeBatch(new GoogleCalendarInitialSyncBatch(null, true), 25);
    Test.stopTest();

    Booking_Form__c healthyAfter = [
      SELECT Google_Calendar_Event_Id__c
      FROM Booking_Form__c
      WHERE Id = :healthyBooking.Id
    ];
    System.assertEquals(
      'already-synced-evt',
      healthyAfter.Google_Calendar_Event_Id__c,
      'A booking that was never marked failed should be left alone by a retry-only run'
    );

    Booking_Form__c failingAfter = [
      SELECT Google_Calendar_Event_Id__c, Google_Calendar_Sync_Failed__c
      FROM Booking_Form__c
      WHERE Id = :failingBooking.Id
    ];
    System.assertNotEquals(
      null,
      failingAfter.Google_Calendar_Event_Id__c,
      'The previously-failing booking should now be synced'
    );
    System.assertEquals(false, failingAfter.Google_Calendar_Sync_Failed__c);
  }
}
