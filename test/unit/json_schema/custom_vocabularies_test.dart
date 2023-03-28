// Copyright 2013-2022 Workiva Inc.
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

import 'package:json_schema/json_schema.dart';
import 'package:json_schema/src/json_schema/utils/format_exceptions.dart';
import 'package:json_schema/src/json_schema/utils/type_validators.dart';
import 'package:test/test.dart';

main() {
  var customVocabularies = [
    CustomVocabulary(
      Uri.parse("http://localhost:4321/vocab/min-date"),
      {"minDate": CustomKeyword(_minDateSetter, _validateMinDate)},
    ),
  ];
  group("Custom Vocabulary Tests", () {
    test('Should process custom vocabularies and validate', () async {
      final schema = await JsonSchema.createAsync(
        {
          r'$schema': 'http://localhost:4321/date-keyword-meta-schema.json',
          r'$id': 'http://localhost:4321/date-keword-schema',
          'properties': {
            'publishedOn': {'minDate': '2020-12-01'},
            'baz': {'type': 'string'}
          },
          'required': ['baz', 'publishedOn']
        },
        schemaVersion: SchemaVersion.draft2020_12,
        customVocabularies: customVocabularies,
      );

      // ignore: deprecated_member_use_from_same_package
      expect(schema.properties['publishedOn']!.customAttributeValidators.keys.contains('minDate'), isTrue);

      expect(schema.validate({'baz': 'foo', 'publishedOn': '2970-01-01'})!.isValid, isTrue);
      expect(schema.validate({'baz': 'foo', 'publishedOn': '1970-01-01'})!.isValid, isFalse);
    });

    test('throws an exception with a bad schema', () async {
      await expectLater(
          JsonSchema.createAsync(
            {
              r'$schema': 'http://localhost:4321/date-keyword-meta-schema.json',
              r'$id': 'http://localhost:4321/date-keword-schema',
              'properties': {
                "publishedOn": {"minDate": 42}
              }
            },
            schemaVersion: SchemaVersion.draft2020_12,
            customVocabularies: customVocabularies,
          ),
          throwsFormatException);
    });

    test('throws an exception with an unknown vocabulary', () async {
      await expectLater(
          JsonSchema.createAsync(
            {
              r'$schema': 'http://localhost:4321/date-keyword-meta-schema.json',
              r'$id': 'http://localhost:4321/date-keword-schema',
              'properties': {
                'publishedOn': {'minDate': '2022-06-21'}
              }
            },
            schemaVersion: SchemaVersion.draft2020_12,
          ),
          throwsFormatException);
    });
  });
}

Object _minDateSetter(JsonSchema? s, Object? value) {
  var valueStr = TypeValidators.nonEmptyString("minDate", value);
  try {
    return DateTime.parse(valueStr);
  } catch (e) {
    throw FormatExceptions.error("minDate must parse as a date: ${value}");
  }
}

ValidationContext _validateMinDate(ValidationContext context, Object schema, Object? instance) {
  if (schema is! DateTime) {
    context.addError('schema is not a date time object.');
  }
  DateTime minDate = schema as DateTime;
  if (instance is! String) {
    context.addError('Data is not stringy');
  }
  String instanceString = instance as String;
  try {
    var testDate = DateTime.parse(instanceString);
    if (minDate.isAfter(testDate)) {
      context.addError('min date is after given date');
    }
  } catch (e) {
    context.addError('unable to parse date');
  }
  return context;
}
