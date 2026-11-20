import 'dart:async';

import 'package:fl_clash/features/update/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup and resume share a six-hour check interval', () async {
    var now = DateTime.utc(2026, 11, 21);
    final schedule = UpdateCheckSchedule(now: () => now);
    var calls = 0;
    Future<void> check() async {
      calls++;
    }

    await schedule.run(check);
    await schedule.run(check);
    now = now.add(const Duration(hours: 5, minutes: 59));
    await schedule.run(check);
    expect(calls, 1);
    now = now.add(const Duration(minutes: 1));
    await schedule.run(check);
    expect(calls, 2);
  });

  test('a failed check retries after thirty minutes', () async {
    var now = DateTime.utc(2026, 11, 21);
    final schedule = UpdateCheckSchedule(now: () => now);
    var calls = 0;
    Future<void> check() async {
      calls++;
      if (calls == 1) throw StateError('offline');
    }

    await expectLater(schedule.run(check), throwsStateError);
    now = now.add(const Duration(minutes: 29));
    await schedule.run(check);
    expect(calls, 1);
    now = now.add(const Duration(minutes: 1));
    await schedule.run(check);
    expect(calls, 2);
  });

  test('timer and resume do not open concurrent checks', () async {
    final gate = Completer<void>();
    final schedule = UpdateCheckSchedule();
    var calls = 0;
    Future<void> check() {
      calls++;
      return gate.future;
    }

    final first = schedule.run(check);
    await schedule.run(check);
    expect(calls, 1);
    gate.complete();
    await first;
    await schedule.run(check);
    expect(calls, 1);
  });
}
