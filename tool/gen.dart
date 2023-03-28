// This is a command line utility generate Dart code that wraps all JSON
// defined in JSON-Schema-Test-Suite. It should be run from the root directory
// (one up from here). The `gen-fixtures` command in the Makefile will do the right thing.

import 'dart:io';
import 'package:collection/collection.dart' show IterableExtension;

final String remotesDirectory = 'test/JSON-Schema-Test-Suite/remotes';
final String remotesOutputFile = 'test/unit/specification_remotes.dart';
final String additionalRemotesDirectory = 'test/additional_remotes';
final String additionalRemotesOutputFile = 'test/unit/additional_remotes.dart';

final String testsDirectory = 'test/JSON-Schema-Test-Suite/tests';
final String customTestsDirectory = 'test/custom/valid_schemas';
final String testsOutputFile = 'test/unit/specification_tests.dart';

/// Generate Dart code containing a Map of JSON files,
/// reflecting example remote schemas in the
/// test/JSON-Schema-Test-Suite/remotes and test/additional_remotes directory.
/// These can be used to avoid using a real HTTP server in tests and mock responses instead.
bool generateFileMapFromDirectory(
  List<String> directories,
  String outputFile, {
  String host = '',
  String variableName = 'files',
  String rootType = 'String',
  List<String> skipFiles = const [],
}) {
  Map<String, String> schemaFiles = {};
  for (var directory in directories) {
    for (var file in _jsonFiles(directory)) {
      schemaFiles[file.path.replaceFirst(directory, host)] = file.readAsStringSync();
    }
  }

  final generatedFile = File(outputFile);
  final String oldGeneratedContents = generatedFile.readAsStringSync();

  final fileContents = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
Map<String, $rootType> ${variableName} = {
  ${_generateRemoteEntries(schemaFiles, skipFiles: skipFiles)}
};
''';

  generatedFile.writeAsStringSync(fileContents);
  return oldGeneratedContents != fileContents;
}

// Schema File map entry generator.
String _generateRemoteEntries(Map<String, String> schemaFiles,
    {List<String> skipFiles = const [], String fileType = 'String'}) {
  final List<String> entries = [];
  bool isFirst = true;
  schemaFiles.forEach((String path, String fileContents) {
    if (skipFiles.firstWhereOrNull((fileName) => path.endsWith(fileName))?.isNotEmpty == true) {
      return;
    }
    entries.add(
      """${isFirst ? '' : '\n  '}"${path}": ${fileType == 'String' ? 'r"""$fileContents"""' : fileContents.replaceAll(r'$', r'\$').replaceAll('\n', '\n  ')}""",
    );
    isFirst = false;
  });

  return entries.join(',');
}

/// Return all JSON files in a directory recursively.
List<File> _jsonFiles(String rootDir) {
  final dir = Directory(rootDir);

  List<File> files = List<File>.from(dir.listSync(recursive: true).where((f) {
    return f is File && f.path.endsWith('.json');
  }));

  return files..sort((f1, f2) => f1.path.compareTo(f2.path));
}

void main([List<String>? args]) {
  final originalArgs = List.unmodifiable(args ?? []);
  final argsMutableCopy = List.from(args ?? []);
  bool shouldCheck = argsMutableCopy.contains('--check');
  argsMutableCopy.removeWhere((arg) => arg == '--check');

  if (argsMutableCopy.isEmpty || argsMutableCopy[0] == 'specification_remotes') {
    final bool didChange = generateFileMapFromDirectory(
      [remotesDirectory],
      remotesOutputFile,
      host: 'http://localhost:1234',
      variableName: 'specificationRemotes',
    );
    if (didChange) {
      print('Generation changed specification_remotes.dart. Please check in latest changes.');
      if (shouldCheck) exit(1);
    } else {
      print('No formatting changes were made for specification_remotes.');
    }
  }

  if (argsMutableCopy.isEmpty || argsMutableCopy[0] == 'additional_remotes') {
    final bool didChange = generateFileMapFromDirectory(
      [additionalRemotesDirectory],
      additionalRemotesOutputFile,
      host: 'http://localhost:4321',
      variableName: 'additionalRemotes',
    );
    if (didChange) {
      print('Generation changed additional_remotes.dart. Please check in latest changes.');
      if (shouldCheck) exit(1);
    } else {
      print('No formatting changes were made for additional_remotes.');
    }
  }

  if (argsMutableCopy.isEmpty || originalArgs[0] == 'tests') {
    final bool didChange = generateFileMapFromDirectory(
      [testsDirectory, customTestsDirectory],
      testsOutputFile,
      host: '',
      variableName: 'specificationTests',
    );
    if (didChange) {
      print('Generation changed additional_remotes.dart. Please check in latest changes.');
      if (shouldCheck) exit(1);
    } else {
      print('No formatting changes were made for additional_remotes.');
    }
  }
}
