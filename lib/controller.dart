Future<void> _scheduleRecap() async {
  try {
    tzdata.initializeTimeZones();

    final tzRes = await FlutterTimezone.getLocalTimezone();
    String tzName;

    if (tzRes is String) {
      tzName = tzRes;
    } else {
      tzName = (tzRes as dynamic).value ??
          (tzRes as dynamic).timezone ??
          (tzRes as dynamic).timeZone ??
          (tzRes as dynamic).location ??
          tzRes.toString();
    }

    tz.setLocalLocation(tz.getLocation(tzName));

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    var days = (8 - now.weekday) % 7;
    if (days == 0 && !now.isBefore(next)) days = 7;
    next = next.add(Duration(days: days));

    await _notifs.zonedSchedule(
      1001,
      'Your week in music 🎵',
      'You played $weekPlays tracks this week. Tap for your mix.',
      next,
      const NotificationDetails(android: AndroidNotificationDetails('recap', 'Weekly recap')),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  } catch (e) {
    debugPrint('Recap schedule failed: $e');
  }
}
