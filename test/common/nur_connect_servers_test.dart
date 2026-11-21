import 'package:fl_clash/common/nur_connect_servers.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

const _nl = Proxy(name: 'Netherlands', type: 'vless');
const _fr = Proxy(name: 'France', type: 'vless');

Group _global(List<Proxy> all, {String now = 'DIRECT'}) =>
    Group(name: 'GLOBAL', type: GroupType.Selector, now: now, all: all);

const _direct = Proxy(name: 'DIRECT', type: 'Direct');
const _reject = Proxy(name: 'REJECT', type: 'Reject');
const _servers = Proxy(name: 'Servers', type: 'Selector');
const _auto = Proxy(name: 'Auto', type: 'URLTest');

void main() {
  group('defaultGlobalTarget', () {
    test('follows the first subscription selector to its server', () {
      final groups = [
        _global([_direct, _reject, _servers, _nl, _fr]),
        const Group(
          name: 'Servers',
          type: GroupType.Selector,
          now: 'Netherlands',
          all: [_nl, _fr],
        ),
      ];
      expect(defaultGlobalTarget(groups), 'Netherlands');
    });

    test('keeps an automatic group as the target', () {
      final groups = [
        _global([_direct, _auto, _nl]),
        const Group(
          name: 'Auto',
          type: GroupType.URLTest,
          now: 'Netherlands',
          all: [_nl],
        ),
      ];
      expect(defaultGlobalTarget(groups), 'Auto');
    });

    test('prefers the group the panel names', () {
      final groups = [
        _global([_direct, _servers, _auto, _nl, _fr]),
        const Group(
          name: 'Servers',
          type: GroupType.Selector,
          now: 'Netherlands',
          all: [_nl, _fr],
        ),
        const Group(
          name: 'Auto',
          type: GroupType.URLTest,
          now: 'France',
          all: [_fr],
        ),
      ];
      expect(defaultGlobalTarget(groups, 'Auto'), 'Auto');
      expect(defaultGlobalTarget(groups, 'Missing'), 'Netherlands');
    });

    test('takes the first server without groups and nothing without one', () {
      expect(
        defaultGlobalTarget([
          _global([_direct, _reject, _fr, _nl]),
        ]),
        'France',
      );
      expect(
        defaultGlobalTarget([
          _global([_direct, _reject]),
        ]),
        isNull,
      );
      expect(defaultGlobalTarget(const []), isNull);
    });
  });
}
