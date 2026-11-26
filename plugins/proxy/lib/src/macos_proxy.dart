import 'dart:io';

import 'proxy_command.dart';

class MacosProxy {
  final ProxyCommandRunner _commandRunner;

  /// Each service's own bypass list from before this run's first start.
  /// macOS keeps one list per service and a start writes ours over it, so a
  /// stop puts it back. A service whose list could not be read is kept as
  /// null, so a later start does not take ours for its own, and gets the
  /// system default.
  final Map<String, List<String>?> _savedBypass = {};

  MacosProxy({required ProxyCommandRunner commandRunner})
    : _commandRunner = commandRunner;

  Future<bool> start(int port, List<String> bypassDomain) async {
    final services = await _networkServices();
    for (final service in services) {
      if (!_savedBypass.containsKey(service)) {
        _savedBypass[service] = await _bypassDomains(service);
      }
    }
    return _commandRunner.run(
      services.expand(
        (service) => MacosProxyCommands.buildStart(service, port, bypassDomain),
      ),
    );
  }

  Future<bool> stop() async {
    final services = await _networkServices();
    final stopped = await _commandRunner.run(services.expand(_buildStop));
    if (stopped) {
      _savedBypass.clear();
    }
    return stopped;
  }

  List<ProxyCommand> _buildStop(String service) => MacosProxyCommands.buildStop(
    service,
    _savedBypass[service] ?? MacosProxyCommands.defaultBypass,
  );

  Future<bool> clearStale(Future<bool> Function(int port) isListening) async {
    final stale = <String>[];
    for (final service in await _networkServices()) {
      final enabled = await _enabledProxies(service);
      if (enabled != null && await isStaleLocalProxy(enabled, isListening)) {
        stale.add(service);
      }
    }
    if (stale.isEmpty) {
      return true;
    }
    return _commandRunner.run(stale.expand(_buildStop));
  }

  /// Null when the list could not be read.
  Future<List<String>?> _bypassDomains(String service) async {
    try {
      final result = await _commandRunner.process('/usr/sbin/networksetup', [
        '-getproxybypassdomains',
        service,
      ]);
      if (result.exitCode != 0) {
        return null;
      }
      return MacosProxyCommands.parseBypassDomains(result.stdout.toString());
    } on ProcessException {
      return null;
    }
  }

  /// Null when a setting could not be read.
  Future<List<ProxyEndpoint>?> _enabledProxies(String service) async {
    final enabled = <ProxyEndpoint>[];
    for (final query in const [
      '-getwebproxy',
      '-getsecurewebproxy',
      '-getsocksfirewallproxy',
    ]) {
      try {
        final result = await _commandRunner.process('/usr/sbin/networksetup', [
          query,
          service,
        ]);
        if (result.exitCode != 0) {
          return null;
        }
        final proxy = MacosProxyCommands.parseEnabledProxy(
          result.stdout.toString(),
        );
        if (proxy != null) {
          enabled.add(proxy);
        }
      } on ProcessException {
        return null;
      }
    }
    return enabled;
  }

  Future<List<String>> _networkServices() async {
    try {
      final result = await _commandRunner.process('/usr/sbin/networksetup', [
        '-listallnetworkservices',
      ]);
      if (result.exitCode != 0) {
        return [];
      }
      return MacosProxyCommands.parseNetworkServices(result.stdout.toString());
    } on ProcessException {
      return [];
    }
  }
}

class MacosProxyCommands {
  static List<ProxyCommand> buildStart(
    String service,
    int port,
    List<String> bypassDomain,
  ) {
    return [
      ProxyCommand('/usr/sbin/networksetup', [
        '-setwebproxy',
        service,
        proxyHost,
        '$port',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsecurewebproxy',
        service,
        proxyHost,
        '$port',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsocksfirewallproxy',
        service,
        proxyHost,
        '$port',
      ]),
      buildProxyBypass(service, bypassDomain),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setwebproxystate',
        service,
        'on',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsecurewebproxystate',
        service,
        'on',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsocksfirewallproxystate',
        service,
        'on',
      ]),
    ];
  }

  /// What System Settings puts in a new service's list.
  static const defaultBypass = ['*.local', '169.254/16'];

  /// [bypassDomain] is the list to leave behind: the service's own one.
  static List<ProxyCommand> buildStop(
    String service, [
    List<String> bypassDomain = defaultBypass,
  ]) {
    return [
      ProxyCommand('/usr/sbin/networksetup', [
        '-setwebproxystate',
        service,
        'off',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsecurewebproxystate',
        service,
        'off',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsocksfirewallproxystate',
        service,
        'off',
      ]),
      buildProxyBypass(service, bypassDomain),
    ];
  }

  static ProxyCommand buildProxyBypass(
    String service,
    List<String> bypassDomain,
  ) {
    return ProxyCommand('/usr/sbin/networksetup', [
      '-setproxybypassdomains',
      service,
      if (bypassDomain.isEmpty) 'Empty' else ...bypassDomain,
    ]);
  }

  /// The proxy a `-get…proxy` query reports, or null when it is off.
  static ProxyEndpoint? parseEnabledProxy(String stdout) {
    final fields = <String, String>{};
    for (final line in stdout.split('\n')) {
      final separator = line.indexOf(':');
      if (separator > 0) {
        fields[line.substring(0, separator).trim()] = line
            .substring(separator + 1)
            .trim();
      }
    }
    if (fields['Enabled'] != 'Yes') {
      return null;
    }
    return (
      host: fields['Server'] ?? '',
      port: int.tryParse(fields['Port'] ?? '') ?? 0,
    );
  }

  /// A `-getproxybypassdomains` answer: one entry a line, or a sentence
  /// ("There aren't any bypass domains set on …") when the list is empty.
  /// An entry never holds a space, so no message line is taken for one.
  static List<String> parseBypassDomains(String stdout) {
    return stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.contains(' '))
        .toList();
  }

  static List<String> parseNetworkServices(String stdout) {
    return stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('*'))
        .where((line) => !line.startsWith('An asterisk '))
        .toList();
  }
}
