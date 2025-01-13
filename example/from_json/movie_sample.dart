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

main() {
  //////////////////////////////////////////////////////////////////////
  // Define schema in code
  //////////////////////////////////////////////////////////////////////
  final movieSchema = {
    'title': 'movie data',
    'additionalProperties': false,
    'required': ['movies'],
    'properties': {
      'movies': {
        '\$ref': '#/definitions/movie_map',
      },
    },
    'definitions': {
      'movie': {
        'additionalProperties': false,
        'required': ['title', 'year_made', 'rating'],
        'properties': {
          'title': {'type': 'string'},
          'year_made': {
            'type': 'integer',
            'minimum': 2020,
            'maximum': 2024,
            'title': 'Product',
            'customMessage': {
              'general_message': {
                'widget_id': 'year_made',
                'recordset_id': 'movies',
              },
              'numberValidation_minimum': {
                'message':
                    "Kindly change the value to be greater than 2020 ANY MESSAGE YOU WANT",
              },
              'numberValidation_maximum': {
                'message':
                    "Kindly change the value to be less than 2024 ANY MESSAGE YOU WANT",
              },
              'numberValidation_exclusiveMaximum': {},
              'numberValidation_exclusiveMinimum': {},
              'numberValidation_multipleOf': {},
              'typeValidation': {},
              'constValidation': {},
              'enumValidation': {},
              'stringValidation_maxLength': {},
              'stringValidation_minLength': {},
              'stringValidation_pattern': {},
              'itemsValidation_additionalItems': {},
              'itemsValidation_maxItems': {},
              'itemsValidation_minItems': {},
              'itemsValidation_uniqueItems': {},
              'itemsValidation_minContains': {},
              'itemsValidation_maxContains': {},
              'itemsValidation_contains': {},
              'validateUnevaluatedItems': {},
              'validateAllOf': {},
              'validateAnyOf': {},
              'validateNot': {},
              'objectPropertyValidation': {},
              'propertyDependenciesValidation': {},
              'schemaDependenciesValidation': {},
              'objectValidation_minProperties': {},
              'objectValidation_maxProperties': {},
              'objectValidation_requiredProperties_root': {},
              'objectValidation_requiredProperties_property': {},
              'schemaBool_false': {},
              'ifThenElseValidation_then': {},
              'ifThenElseValidation_else': {},
            },
          },
          'rating': {'type': 'integer'},
        },
      },
      'movie_map': {
        'type': 'object',
        'additionalProperties': {
          '\$ref': '#/definitions/movie',
        },
        'default': {},
      },
    },
  };

  final movies = {
    'movies': {
      'the mission': {
        'title': 'The Mission',
        'year_made': 2010,
        'rating': 5,
      },
      'troll 2': {
        'title': 'Troll 2',
        'year_made': 2025,
        'rating': 2,
      },
    }
  };

  JsonSchema.createAsync(movieSchema).then((schema) {
    final validator = Validator(schema);
    final results = validator.validate(movies, reportMultipleErrors: true);
    for (var element in results.errors) {
      print(element.message);
      print(element.customMessage ?? 'no custom message');
    }
  });
}
