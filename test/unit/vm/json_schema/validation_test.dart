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

library json_schema.test_validation;

import 'dart:convert' as convert;
import 'dart:io';
import 'package:json_schema/json_schema.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// custom <additional imports>
// end <additional imports>

final Logger _logger = new Logger('test_validation');

// custom <library test_validation>
// end <library test_validation>

void main([List<String> args]) {
  if (args?.isEmpty ?? false) {
    Logger.root.onRecord.listen((LogRecord r) => print("${r.loggerName} [${r.level}]:\t${r.message}"));
    Logger.root.level = Level.OFF;
  }
// custom <main>

  ////////////////////////////////////////////////////////////////////////
  // Uncomment to see logging of exceptions
  // Logger.root.onRecord.listen((LogRecord r) =>
  //   print("${r.loggerName} [${r.level}]:\t${r.message}"));

  Logger.root.level = Level.OFF;

  Directory testSuiteFolder = new Directory("./test/JSON-Schema-Test-Suite/tests/draft4/invalidSchemas");

  testSuiteFolder = new Directory("./test/JSON-Schema-Test-Suite/tests/draft4");

  var optionals = new Directory(path.joinAll([testSuiteFolder.path, 'optional']));

  var all = testSuiteFolder.listSync()..addAll(optionals.listSync());

  all.forEach((testEntry) {
    if (testEntry is File) {
      group("Validations ${path.basename(testEntry.path)}", () {
        // TODO: add these back or get replacements
        // Skip these for now - reason shown
        if ([
          'refRemote.json', // seems to require webserver running to vend files
        ].contains(path.basename(testEntry.path))) return;

        List tests = convert.jsonDecode((testEntry as File).readAsStringSync());
        tests.forEach((testEntry) {
          var schemaData = testEntry["schema"];
          var description = testEntry["description"];
          List validationTests = testEntry["tests"];

          validationTests.forEach((validationTest) {
            String validationDescription = validationTest["description"];
            test("${description} : ${validationDescription}", () {
              var instance = validationTest["data"];
              bool validationResult;
              bool expectedResult = validationTest["valid"];
              var checkResult = expectAsync0(() => expect(validationResult, expectedResult));
              Schema.createSchema(schemaData).then((schema) {
                validationResult = schema.validate(instance);
                checkResult();
              });
            });
          });
        });
      });
    }
  });

  test("Schema self validation", () {
    // Pull in the official schema, verify description and then ensure
    // that the schema satisfies the schema for schemas
    String url = "http://json-schema.org/draft-04/schema";
    Schema.createSchemaFromUrl(url).then((schema) {
      expect(schema.schemaMap["description"], "Core schema meta-schema");
      expect(schema.validate(schema.schemaMap), true);
    });
  });

// end <main>
}
