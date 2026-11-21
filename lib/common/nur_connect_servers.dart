import 'package:collection/collection.dart';
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

/// What GLOBAL carries when nothing was picked there, since mihomo starts it on
/// DIRECT: the panel's server group, else the subscription's first group, else
/// its first server. A plain selector is followed to the server it has chosen,
/// so the home names that server; an automatic group is kept as it is.
String? defaultGlobalTarget(List<Group> groups, [String? serverGroup]) {
  final global = groups.getGroup(GroupName.GLOBAL.name);
  if (global == null) return null;
  final members = [
    for (final proxy in global.all)
      if (!isBuiltinOutbound(proxy.name) && proxy.name != GroupName.GLOBAL.name)
        proxy.name,
  ];
  if (members.isEmpty) return null;
  final groupName =
      serverGroup != null &&
          members.contains(serverGroup) &&
          groups.getGroup(serverGroup) != null
      ? serverGroup
      : members.firstWhereOrNull((name) => groups.getGroup(name) != null);
  if (groupName == null) return members.first;
  final group = groups.getGroup(groupName)!;
  final now = group.now;
  if (group.type == GroupType.Selector &&
      now != null &&
      now.isNotEmpty &&
      !isBuiltinOutbound(now) &&
      members.contains(now)) {
    return now;
  }
  return groupName;
}

/// The servers listed for [group]. GLOBAL also carries the subscription's
/// groups: a plain selector among them only repeats servers already listed
/// and reads as one more server, so it is left out, while an automatic group
/// stays a choice of its own. [groups] is every group, hidden ones included.
List<Proxy> nurConnectServerChoices(Group group, List<Group> groups) {
  final selectors = {
    if (group.name == GroupName.GLOBAL.name)
      for (final item in groups)
        if (item.type == GroupType.Selector) item.name,
  };
  return [
    for (final proxy in group.all)
      if (!isBuiltinOutbound(proxy.name) && !selectors.contains(proxy.name))
        proxy,
  ];
}
