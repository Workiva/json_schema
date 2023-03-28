#!/usr/bin/env dart
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
// Copyright (c) 2012 Julian Berman, which is licensed under the following terms
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
//     THE SOFTWARE

import 'package:json_schema/json_schema.dart';

main() async {
  // The meta-schema is pulled in while processing the schema.
  //String metaSchemaUrl = 'date-range-meta-schema.json';
  String schemaUrl = 'example-date-range-schema.json';
  var customVocabulary = CustomVocabulary(
    // Name of the vocabulary.
    Uri.parse("http://localhost/vocab/date-range"),
    {
      'minDate': CustomKeyword(_dateSetter, _validateMinDate),
      'maxDate': CustomKeyword(_dateSetter, _validateMaxDate),
    },
  );
  var schema = await JsonSchema.createFromUrl(
    schemaUrl,
    schemaVersion: SchemaVersion.draft2020_12,
    customVocabularies: [customVocabulary],
  );

  var validSchema = {'epochDate': '2024-12-01'};
  print('''Is ${validSchema} in a time that's known to exist?
   ${schema.validate(validSchema)}''');

  var invalidSchema = {'epochDate': '1900-01-01'};
  print('''Does a time that doesn't exist validate?
   ${schema.validate(invalidSchema)}''');
}

// Function used to set a date from the schema.
// The Object returned here is passed into the validators as the `schemaProperty`
Object _dateSetter(JsonSchema? s, Object? value) {
  try {
    return DateTime.parse(value as String);
  } catch (e) {
    throw FormatException("value must parse as a date: ${value}");
  }
}

// Validate the given data against the property.
ValidationContext _validateMinDate(ValidationContext context, Object schemaProperty, Object? instanceData) {
  if (schemaProperty is! DateTime) {
    context.addError('schema is not a date time object.');
  }
  DateTime minDate = schemaProperty as DateTime;
  if (instanceData is! String) {
    context.addError('Data is not stringy');
  }
  String instanceString = instanceData as String;
  try {
    var testDate = DateTime.parse(instanceString);
    if (minDate.isAfter(testDate)) {
      context.addError('min date is after given date');
    }
  } catch (e) {
    context.addError('unable to parse date from data');
  }

  return context;
}

// Validate the given data against the property.
ValidationContext _validateMaxDate(ValidationContext context, Object schemaProperty, Object? instanceData) {
  if (schemaProperty is! DateTime) {
    context.addError('schema is not a date time object.');
  }
  DateTime maxDate = schemaProperty as DateTime;
  if (instanceData is! String) {
    context.addError('Data is not stringy');
  }
  String instanceString = instanceData as String;
  try {
    var testDate = DateTime.parse(instanceString);
    if (maxDate.isBefore(testDate)) {
      context.addError('max date is before given date');
    }
  } catch (e) {
    context.addError('unable to parse date from data');
  }
  return context;
}
