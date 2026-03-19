import 'dart:typed_data';

class TimeSyncUtil {
  static Uint8List buildPacket(DateTime time) {
    int year = time.year - 2000;
    int month = time.month;
    int day = time.day;
    int hour = time.hour;
    int minute = time.minute;
    int second = time.second;
    
    // Dart: 1=Mon, 7=Sun. FSD: 0=Sun, 1=Mon...
    int dayOfWeek = time.weekday == DateTime.sunday ? 0 : time.weekday;

    int checksum = year ^ month ^ day ^ hour ^ minute ^ second ^ dayOfWeek;

    return Uint8List.fromList([
      year,
      month,
      day,
      hour,
      minute,
      second,
      dayOfWeek,
      checksum
    ]);
  }
}
