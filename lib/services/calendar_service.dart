import 'package:device_calendar/device_calendar.dart';

class CalendarEventData {
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String? location;

  const CalendarEventData({
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.location,
  });
}

class CalendarService {
  static final CalendarService _instance = CalendarService._();
  factory CalendarService() => _instance;
  CalendarService._();

  final _plugin = DeviceCalendarPlugin();

  Future<bool> requestPermission() async {
    final result = await _plugin.requestPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  Future<List<Calendar>> getCalendars() async {
    final result = await _plugin.retrieveCalendars();
    if (!result.isSuccess) return [];
    return result.data ?? [];
  }

  Future<List<Event>> getUpcomingEvents({int days = 7}) async {
    final calendars = await getCalendars();
    final events = <Event>[];
    final now = DateTime.now();
    final end = now.add(Duration(days: days));

    for (final cal in calendars) {
      if (cal.id == null) continue;
      final result = await _plugin.retrieveEvents(
        cal.id!,
        RetrieveEventsParams(startDate: now, endDate: end),
      );
      if (result.isSuccess && result.data != null) {
        events.addAll(result.data!);
      }
    }

    events.sort((a, b) {
      final aStart = a.start?.toLocal() ?? DateTime.now();
      final bStart = b.start?.toLocal() ?? DateTime.now();
      return aStart.compareTo(bStart);
    });

    return events;
  }

  Future<String?> createEvent(CalendarEventData data) async {
    final calendars = await getCalendars();
    final writable = calendars
        .where((c) => c.id != null && c.isReadOnly != true)
        .firstOrNull;
    if (writable?.id == null) return null;

    final event = Event(
      writable!.id!,
      title: data.title,
      description: data.description,
      start: TZDateTime.from(data.start, local),
      end: TZDateTime.from(data.end, local),
      location: data.location,
    );

    final result = await _plugin.createOrUpdateEvent(event);
    return result?.isSuccess == true ? result!.data : null;
  }
}
