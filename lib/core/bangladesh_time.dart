class BangladeshTime {
  BangladeshTime._();

  static const Duration _offset = Duration(hours: 6);

  /// Bangladesh current wall-clock time (UTC+06:00).
  /// Use this for app input dates/times and locally stored business timestamps.
  static DateTime now() {
    final bd = DateTime.now().toUtc().add(_offset);
    return DateTime(
      bd.year, bd.month, bd.day, bd.hour, bd.minute, bd.second,
      bd.millisecond, bd.microsecond,
    );
  }

  static String date() {
    final value = now();
    return '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)}';
  }

  static String dateTime() {
    final value = now();
    return '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)} ${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}';
  }

  static String isoLocal() {
    final value = now();
    return '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)}T${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}.${value.millisecond.toString().padLeft(3, '0')}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
