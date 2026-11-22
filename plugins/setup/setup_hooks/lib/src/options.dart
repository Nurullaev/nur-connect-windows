import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

final _log = Logger('options');

class BuildConfig {
  const BuildConfig({
    required this.tags,
    required this.goLdflags,
    required this.coreVersion,
    required this.coreDir,
    required this.coreName,
    required this.outputDir,
    required this.helperDir,
    required this.helperName,
  });

  final String tags;
  final String goLdflags;
  final String coreVersion;
  final String coreDir;
  final String coreName;
  final String outputDir;
  final String helperDir;
  final String helperName;

  static const _defaults = BuildConfig(
    tags: 'with_gvisor',
    goLdflags: '-w -s',
    coreVersion: '',
    coreDir: 'core',
    coreName: 'FlClashCore',
    outputDir: 'libclash',
    helperDir: 'services/helper',
    helperName: 'FlClashXHelperService',
  );

  static const _windowsDefaults = BuildConfig(
    tags: 'with_gvisor',
    goLdflags: '-w -s',
    coreVersion: '',
    coreDir: 'core',
    coreName: 'NurConnectCore',
    outputDir: 'libclash',
    helperDir: 'services/helper',
    helperName: 'NurConnectWindowsHelper',
  );

  static BuildConfig load({required String rootDir, String? platform}) {
    final defaults = platform == 'windows' ? _windowsDefaults : _defaults;
    final file = File(p.join(rootDir, 'build_config.yaml'));
    if (!file.existsSync()) {
      _log.fine('No build_config.yaml found, using defaults');
      return defaults;
    }
    final yaml = loadYaml(file.readAsStringSync()) as YamlMap?;
    if (yaml == null) return defaults;
    return BuildConfig(
      tags: yaml['tags'] as String? ?? defaults.tags,
      goLdflags: yaml['go_ldflags'] as String? ?? defaults.goLdflags,
      coreVersion: yaml['core_version'] as String? ?? defaults.coreVersion,
      coreDir: yaml['core_dir'] as String? ?? defaults.coreDir,
      coreName:
          yaml[platform == 'windows'
                  ? 'windows_core_name'
                  : platform == 'darwin' || platform == 'macos'
                  ? 'macos_core_name'
                  : 'core_name']
              as String? ??
          defaults.coreName,
      outputDir: yaml['output_dir'] as String? ?? defaults.outputDir,
      helperDir: yaml['helper_dir'] as String? ?? defaults.helperDir,
      helperName:
          yaml[platform == 'windows' ? 'windows_helper_name' : 'helper_name']
              as String? ??
          defaults.helperName,
    );
  }

  Map<String, String> toFingerprintMap() => {
    'tags': tags,
    'go_ldflags': goLdflags,
    'core_version': coreVersion,
    'core_dir': coreDir,
    'core_name': coreName,
    'output_dir': outputDir,
    'helper_dir': helperDir,
    'helper_name': helperName,
  };
}
