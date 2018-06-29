#!/usr/bin/env dart
// Copyright 2013-2018 Workiva Inc.
//
// Licensed under the Boost Software License (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.boost.org/LICENSE_1_0.txt
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This software or document includes material copied from or derived
// from JSON-Schema-Test-Suite (https://github.com/json-schema-org/JSON-Schema-Test-Suite),
// Copyright (c) 2012 Julian Berman, which is licensed under the following terms:
//
//     Copyright (c) 2012 Julian Berman
//
//     Permission is hereby granted, free of charge, to any person obtaining a copy
//     of this software and associated documentation files (the "Software"), to deal
//     in the Software without restriction, including without limitation the rights
//     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//     copies of the Software, and to permit persons to whom the Software is
//     furnished to do so, subject to the following conditions:
//
//     The above copyright notice and this permission notice shall be included in
//     all copies or substantial portions of the Software.
//
//     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//     THE SOFTWARE.

///
/// Usage: schemadot --in-uri INPUT_JSON_URI --out-file OUTPUT_FILE
///
/// Given an input uri [in-uri] processes content of uri as
/// json schema and generates input file for Graphviz dot
/// program. If [out-file] provided, output is written to
/// the file, otherwise written to stdout.
///
import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';
import 'package:args/args.dart';
import 'package:json_schema/json_schema.dart';
import 'package:json_schema/schema_dot.dart';
import 'package:logging/logging.dart';

// custom <additional imports>
// end <additional imports>
//! The parser for this script
ArgParser _parser;
//! The comment and usage associated with this script
void _usage() {
  print(r'''

Usage: schemadot --in-uri INPUT_JSON_URI --out-file OUTPUT_FILE

Given an input uri [in-uri] processes content of uri as
json schema and generates input file for Graphviz dot
program. If [out-file] provided, output is written to
the file, otherwise written to stdout.

''');
  print(_parser.usage);
}

//! Method to parse command line options.
//! The result is a map containing all options, including positional options
Map _parseArgs(List<String> args) {
  ArgResults argResults;
  Map result = {};

  _parser = new ArgParser();
  try {
    /// Fill in expectations of the parser
    _parser.addFlag('help',
        help: r'''
Display this help screen
''',
        abbr: 'h',
        defaultsTo: false);

    _parser.addOption('in-uri', help: '', defaultsTo: null, allowMultiple: false, abbr: 'i', allowed: null);
    _parser.addOption('out-file', help: '', defaultsTo: null, allowMultiple: false, abbr: 'o', allowed: null);
    _parser.addOption('log-level',
        help: r'''
Select log level from:
[ all, config, fine, finer, finest, info, levels,
  off, severe, shout, warning ]

''',
        defaultsTo: null,
        allowMultiple: false,
        abbr: null,
        allowed: null);

    /// Parse the command line options (excluding the script)
    argResults = _parser.parse(args);
    if (argResults.wasParsed('help')) {
      _usage();
      exit(0);
    }
    result['in-uri'] = argResults['in-uri'];
    result['out-file'] = argResults['out-file'];
    result['help'] = argResults['help'];
    result['log-level'] = argResults['log-level'];

    if (result['log-level'] != null) {
      const choices = const {
        'all': Level.ALL,
        'config': Level.CONFIG,
        'fine': Level.FINE,
        'finer': Level.FINER,
        'finest': Level.FINEST,
        'info': Level.INFO,
        'levels': Level.LEVELS,
        'off': Level.OFF,
        'severe': Level.SEVERE,
        'shout': Level.SHOUT,
        'warning': Level.WARNING
      };
      final selection = choices[result['log-level'].toLowerCase()];
      if (selection != null) Logger.root.level = selection;
    }

    return {'options': result, 'rest': argResults.rest};
  } catch (e) {
    _usage();
    throw e;
  }
}

final _logger = new Logger('schemadot');

main(List<String> args) {
  Logger.root.onRecord.listen((LogRecord r) => print("${r.loggerName} [${r.level}]:\t${r.message}"));
  Logger.root.level = Level.OFF;
  Map argResults = _parseArgs(args);
  Map options = argResults['options'];

  try {
    if (options["in-uri"] == null) throw new ArgumentError("option: in-uri is required");
  } on ArgumentError catch (e) {
    print(e);
    _usage();
    exit(-1);
  }
  // custom <schemadot main>

  Logger.root.level = Level.OFF;
  Completer completer = new Completer();
  Uri uri = Uri.parse(options['in-uri']);
  if (uri.scheme == 'http') {
    new HttpClient()
        .getUrl(uri)
        .then((HttpClientRequest request) => request.close())
        .then((HttpClientResponse response) => response.transform(new convert.Utf8Decoder()).join())
        .then((text) {
      completer.complete(text);
    });
  } else {
    File target = new File(uri.toString());
    if (target.existsSync()) {
      completer.complete(target.readAsStringSync());
    }
  }

  completer.future.then((schemaText) {
    Future schema = Schema.createSchema(convert.jsonDecode(schemaText));
    schema.then((schema) {
      String dot = createDot(schema);
      if (options['out-file'] != null) {
        new File(options['out-file']).writeAsStringSync(dot);
      } else {
        print(dot);
      }
    });
  });

  // end <schemadot main>
}

// custom <schemadot global>

// end <schemadot global>
