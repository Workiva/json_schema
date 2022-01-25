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

import 'dart:convert';

import 'package:json_schema/json_schema.dart';

main() {
  final referencedSchema = {
    r"$id": "https://example.com/geographical-location.schema.json",
    r"$schema": "http://json-schema.org/draft-06/schema#",
    "title": "Longitude and Latitude",
    "description": "A geographical coordinate on a planet (most commonly Earth).",
    "required": ["latitude", "longitude"],
    "type": "object",
    "properties": {
      "name": {"type": "string"},
      "latitude": {"type": "number", "minimum": -90, "maximum": 90},
      "longitude": {"type": "number", "minimum": -180, "maximum": 180}
    }
  };

  final RefProvider refProvider = RefProvider.sync((String ref) {
    final Map references = {
      'https://example.com/geographical-location.schema.json': referencedSchema,
    };

    if (references.containsKey(ref)) {
      return references[ref];
    }

    return null;
  });

  final schema = JsonSchema.create({
    'type': 'array',
    'items': {r'$ref': 'https://example.com/geographical-location.schema.json'}
  }, refProvider: refProvider);

  final workivaLocations = [
    {
      'name': 'Ames',
      'latitude': 41.9956731,
      'longitude': -93.6403663,
    },
    {
      'name': 'Scottsdale',
      'latitude': 33.4634707,
      'longitude': -111.9266617,
    }
  ];

  final badLocations = [
    {
      'name': 'Bad Badlands',
      'latitude': 181,
      'longitude': 92,
    },
    {
      'name': 'Nowhereville',
      'latitude': -2000,
      'longitude': 7836,
    }
  ];

  print('${json.encode(workivaLocations)} => ${schema.validateWithResults(workivaLocations)}');
  print('${json.encode(badLocations)} => ${schema.validateWithResults(badLocations)}');
}
