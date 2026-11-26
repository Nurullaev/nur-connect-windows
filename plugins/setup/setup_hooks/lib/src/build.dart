import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'build_cache.dart';
import 'fingerprint.dart';
import 'go_builder.dart';
import 'options.dart';
import 'rust_builder.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('setup_hooks');

class BuildRequest {
  const BuildRequest({
    required this.rootDir,
    required this.target,
    this.harnessDir,
  });

  final String rootDir;
  final Target target;

  final String? harnessDir;
}

class BuildReport {
  const BuildReport({
    required this.inputs,
    required this.outputs,
    required this.rebuilt,
    this.sourceDirectories = const [],
  });

  final List<String> inputs;

  /// A source file added beside the others changes no file the hook read.
  final List<String> sourceDirectories;
  final List<String> outputs;
  final bool rebuilt;

  /// A directory dependency hashes child names, not content, so a deleted
  /// artifact still reruns the hook without rereading the Core.
  List<String> get outputDirectories =>
      {for (final output in outputs) p.dirname(output)}.toList()..sort();
}

/// The Helper embeds the Core's SHA256, so the Core is built first.
Future<BuildReport> buildPlatform(BuildRequest request) async {
  if (request.target.goos != 'darwin') return _buildTarget(request);
  final reports = <BuildReport>[];
  final cores = <String>[];
  final config = BuildConfig.load(rootDir: request.rootDir, platform: 'darwin');
  for (final target in Target.forPlatform('macos')) {
    final report = await _buildTarget(
      BuildRequest(
        rootDir: request.rootDir,
        target: target,
        harnessDir: request.harnessDir,
      ),
    );
    reports.add(report);
    cores.add(
      p.join(
        request.rootDir,
        config.outputDir,
        'macos',
        target.goarch,
        config.coreName,
      ),
    );
  }
  final destination = p.join(
    request.rootDir,
    config.outputDir,
    'macos',
    config.coreName,
  );
  // Never replace a working universal Core with an incomplete slice.
  final staged = '$destination.universal-$pid';
  try {
    await runCommandStream('/usr/bin/lipo', [
      '-create',
      ...cores,
      '-output',
      staged,
    ]);
    for (final arch in ['arm64', 'x86_64']) {
      await runCommandStream('/usr/bin/lipo', [staged, '-verify_arch', arch]);
    }
    replaceFile(staged, destination);
  } finally {
    final file = File(staged);
    if (file.existsSync()) file.deleteSync();
  }
  return BuildReport(
    inputs: {for (final report in reports) ...report.inputs}.toList()..sort(),
    outputs: {
      destination,
      for (final report in reports) ...report.outputs,
    }.toList()..sort(),
    sourceDirectories: {
      for (final report in reports) ...report.sourceDirectories,
    }.toList()..sort(),
    rebuilt: reports.any((report) => report.rebuilt),
  );
}

Future<BuildReport> _buildTarget(BuildRequest request) async {
  final stopwatch = Stopwatch()..start();
  final target = request.target;
  final rootDir = request.rootDir;
  final config = BuildConfig.load(rootDir: rootDir, platform: target.goos);
  // Its values reach the fingerprints, which the hook only checks once it runs.
  final configFile = File(p.join(rootDir, 'build_config.yaml'));
  final configInputs = [if (configFile.existsSync()) configFile.path];
  final cache = BuildCache(rootDir: rootDir);
  final notice = BuildNotice();
  final harnessInputs = switch (request.harnessDir) {
    null => const <String>[],
    final dir => collectPackageInputs(dir),
  };

  final core = await GoBuilder(
    rootDir: rootDir,
    config: config,
    cache: cache,
    notice: notice,
    harnessInputs: harnessInputs,
  ).build(target);
  if (!target.hasHelper) {
    _log.info('Done in ${stopwatch.elapsed}: ${core.primaryOutput}');
    return _report([core], extraInputs: configInputs);
  }

  final coreSha256 = await calcSha256(core.primaryOutput);
  final helper = await RustBuilder(
    rootDir: rootDir,
    config: config,
    cache: cache,
    notice: notice,
    harnessInputs: harnessInputs,
  ).build(target, coreSha256);
  final manifestPath = p.join(
    rootDir,
    config.outputDir,
    target.platformDir,
    coreManifestName,
  );
  writeCoreManifest(path: manifestPath, coreSha256: coreSha256);

  _log.info(
    'Done in ${stopwatch.elapsed}: ${core.primaryOutput}, '
    '${helper.primaryOutput}',
  );
  return _report(
    [core, helper],
    extraInputs: configInputs,
    extraOutputs: [manifestPath],
  );
}

BuildReport _report(
  List<BuildExecution> results, {
  List<String> extraInputs = const [],
  List<String> extraOutputs = const [],
}) {
  final sources = <String>{};
  final outputs = <String>{};
  for (final result in results) {
    sources.addAll(result.inputs);
    outputs.addAll(result.outputs);
  }
  final inputs = {...sources, ...extraInputs};
  outputs.addAll(extraOutputs);
  return BuildReport(
    inputs: inputs.toList()..sort(),
    outputs: outputs.toList()..sort(),
    rebuilt: results.any((result) => result.rebuilt),
    sourceDirectories: {
      for (final source in sources) p.dirname(source),
    }.toList()..sort(),
  );
}
