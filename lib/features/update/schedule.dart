/// Throttles automatic checks across startup, timer ticks and window resumes.
/// The UI owns the timer; this class never leaves a background timer behind.
class UpdateCheckSchedule {
  UpdateCheckSchedule({
    DateTime Function()? now,
    this.interval = const Duration(hours: 6),
    this.retryInterval = const Duration(minutes: 30),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration interval;
  final Duration retryInterval;
  DateTime? _nextCheck;
  bool _checking = false;

  Future<void> run(Future<void> Function() check) async {
    if (_checking || (_nextCheck?.isAfter(_now()) ?? false)) return;
    _checking = true;
    try {
      await check();
      _nextCheck = _now().add(interval);
    } catch (_) {
      _nextCheck = _now().add(retryInterval);
      rethrow;
    } finally {
      _checking = false;
    }
  }
}
