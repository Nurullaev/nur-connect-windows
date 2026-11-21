import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// Keep GLOBAL internal: it still owns picks when global routing is active.
/// Rule routing presents the subscription groups, with GLOBAL as flat fallback.
List<Group> nurConnectServerGroups(List<Group> groups, Mode mode) {
  final global = groups.where((g) => g.name == GroupName.GLOBAL.name).toList();
  if (mode == Mode.global && global.isNotEmpty) return global;
  final subscription = groups
      .where((g) => g.name != GroupName.GLOBAL.name)
      .toList();
  return subscription.isNotEmpty ? subscription : groups;
}
