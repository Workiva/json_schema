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

class JsonSchemaValidationRegexes {
  // Spec: https://datatracker.ietf.org/doc/html/rfc3339#appendix-A
  static RegExp duration = RegExp(
      r'^P(\d{1,}W|T(\d{1,}H(\d{1,}M(\d{1,}S)?)?|\d{1,}M(\d{1,}S)?|\d{1,}S)|(\d{1,}D|\d{1,}M(\d{1,}D)?|\d{1,}Y(\d{1,}M(\d{1,}D)?)?)(T(\d{1,}H(\d{1,}M(\d{1,}S)?)?|\d{1,}M(\d{1,}S)?|\d{1,}S))?)$');

  // Spec: https://datatracker.ietf.org/doc/html/rfc4122
  static RegExp uuid =
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-5][0-9a-fA-F]{3}-[089abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');

  // From: https://emailregex.com/ (JavaScript)
  static RegExp email = RegExp(
      r'^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$');

  static RegExp ipv4 = RegExp(r'^(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.'
      r'(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.'
      r'(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.'
      r'(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))$');

  // Spec: https://datatracker.ietf.org/doc/html/rfc1034
  static RegExp hostname = RegExp(r'^(?=.{1,255}$)'
      r'[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?'
      r'(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$');

  // Spec: https://datatracker.ietf.org/doc/html/rfc1123
  static RegExp hostnameDraft2019 = RegExp(r'^(?=.{1,255}$)'
      r'[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?'
      r'(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$');

  // From: https://github.com/johno/domain-regex/blob/master/index.js
  // Spec: https://datatracker.ietf.org/doc/html/rfc1034
  static RegExp idnHostname = RegExp(r'\b((?=[a-z0-9-]{1,63}\.)(xn--)?[a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,63}\b');

  // Spec: https://datatracker.ietf.org/doc/html/rfc1123
  static RegExp idnHostnameDraft2019 =
      RegExp(r'\b((?=[a-z0-9-]{1,63}\.)(xn--)?[a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,63}\b');

  static RegExp jsonPointer = RegExp(r'^(?:\/(?:[^~/]|~0|~1)*)*$');

  // Spec: https://tools.ietf.org/html/draft-handrews-relative-json-pointer-01
  // From: https://github.com/ajv-validator/ajv-formats/blob/ec288c47a25024b36ea4117d7904f0308487d3de/src/formats.ts#L71
  static RegExp relativeJsonPointer = RegExp(r'^(?:\/(?:[^~/]|~0|~1)*)*$');

  // Spec: https://tools.ietf.org/html/rfc3339#section-5.6
  // From: https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch04s07.html
  static RegExp fullTime =
      RegExp(r'^(2[0-3]|[01][0-9]):?([0-5][0-9]):?([0-5][0-9])(Z|[+-](?:2[0-3]|[01][0-9])(?::?(?:[0-5][0-9]))?)$');

  // Spec: https://tools.ietf.org/html/rfc3339#section-5.6
  // From: https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch04s07.html
  static RegExp fullDate = RegExp(r'^([0-9]{4})(-?)(1[0-2]|0[1-9])\2(3[01]|0[1-9]|[12][0-9])$');

  // https://json-schema.org/draft/2019-09/json-schema-core.html#rfc.section.8.2.3
  static RegExp anchor = RegExp(r"^[A-Za-z][\w\-.:]+$");
}

class SchemaVersion implements Comparable<SchemaVersion> {
  const SchemaVersion._(this.value);

  static const SchemaVersion draft4 = SchemaVersion._(0);

  static const SchemaVersion draft6 = SchemaVersion._(1);

  static const SchemaVersion draft7 = SchemaVersion._(2);

  static const SchemaVersion draft2019_09 = SchemaVersion._(3);

  static List<SchemaVersion> get values => const <SchemaVersion>[draft4, draft6, draft7, draft2019_09];

  final int value;

  @override
  int get hashCode => value;

  @override
  bool operator ==(Object other) => other is SchemaVersion && other.hashCode == hashCode;

  SchemaVersion copy() => this;

  @override
  int compareTo(SchemaVersion other) => value.compareTo(other.value);

  bool operator <(Object other) => other is SchemaVersion && this.compareTo(other) < 0;
  bool operator >(Object other) => other is SchemaVersion && this.compareTo(other) > 0;
  bool operator <=(Object other) => other is SchemaVersion && this.compareTo(other) <= 0;
  bool operator >=(Object other) => other is SchemaVersion && this.compareTo(other) >= 0;

  @override
  String toString() {
    final draftToStringMap = {
      draft4: 'http://json-schema.org/draft-04/schema#',
      draft6: 'http://json-schema.org/draft-06/schema#',
      draft7: 'http://json-schema.org/draft-07/schema#',
      draft2019_09: 'https://json-schema.org/draft/2019-09/schema',
    };
    return draftToStringMap[this];
  }

  static SchemaVersion fromString(String s) {
    if (s == null) return null;
    switch (s) {
      case 'http://json-schema.org/draft-04/schema#':
        return draft4;
      case 'http://json-schema.org/draft-06/schema#':
        return draft6;
      case 'http://json-schema.org/draft-07/schema#':
        return draft7;
      case 'https://json-schema.org/draft-04/schema#':
        return draft4;
      case 'https://json-schema.org/draft-06/schema#':
        return draft6;
      case 'https://json-schema.org/draft-07/schema#':
        return draft7;
      case 'https://json-schema.org/draft/2019-09/schema':
        return draft2019_09;
      default:
        return null;
    }
  }
}

final _staticSchemaMapping = {
  parseStandardizedUri(SchemaVersion.draft4.toString()): JsonSchemaDefinitions.draft4,
  parseStandardizedUri(SchemaVersion.draft6.toString()): JsonSchemaDefinitions.draft6,
  parseStandardizedUri(SchemaVersion.draft7.toString()): JsonSchemaDefinitions.draft7,
  parseStandardizedUri(SchemaVersion.draft2019_09.toString()): JsonSchemaDefinitions.draft2019_09,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/meta/validation"): Draft2019Subschemas.validation,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/vocab/validation"): Draft2019Subschemas.validation,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/meta/format"): Draft2019Subschemas.format,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/vocab/format"): Draft2019Subschemas.format,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/meta/core"): Draft2019Subschemas.core,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/vocab/core"): Draft2019Subschemas.core,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/meta/metadata"): Draft2019Subschemas.metadata,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/vocab/metadata"): Draft2019Subschemas.metadata,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/meta/applicator"): Draft2019Subschemas.applicator,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/vocab/applicator"): Draft2019Subschemas.applicator,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/meta/content"): Draft2019Subschemas.content,
  parseStandardizedUri("https://json-schema.org/draft/2019-09/vocab/content"): Draft2019Subschemas.content,
};

Uri parseStandardizedUri(String s) => standardizeUri(Uri.parse(s));
Uri standardizeUri(Uri uri) => uri?.replace(scheme: uri.scheme == "http" ? "https" : uri.scheme, fragment: null);

Map getStaticSchema(String ref) {
  return getStaticSchemaByURI(parseStandardizedUri(ref));
}

Map getStaticSchemaByURI(Uri ref) {
  if (ref.fragment != "") return null;
  final mapped = _staticSchemaMapping[standardizeUri(ref)];
  return mapped != null ? json.decode(mapped) : null;
}

class JsonSchemaDefinitions {
  static final String draft4 = r'''
    {
    "id": "http://json-schema.org/draft-04/schema#",
    "$schema": "http://json-schema.org/draft-04/schema#",
    "description": "Core schema meta-schema",
    "definitions": {
        "schemaArray": {
            "type": "array",
            "minItems": 1,
            "items": { "$ref": "#" }
        },
        "positiveInteger": {
            "type": "integer",
            "minimum": 0
        },
        "positiveIntegerDefault0": {
            "allOf": [ { "$ref": "#/definitions/positiveInteger" }, { "default": 0 } ]
        },
        "simpleTypes": {
            "enum": [ "array", "boolean", "integer", "null", "number", "object", "string" ]
        },
        "stringArray": {
            "type": "array",
            "items": { "type": "string" },
            "minItems": 1,
            "uniqueItems": true
        }
    },
    "type": "object",
    "properties": {
        "id": {
            "type": "string"
        },
        "$schema": {
            "type": "string"
        },
        "title": {
            "type": "string"
        },
        "description": {
            "type": "string"
        },
        "default": {},
        "multipleOf": {
            "type": "number",
            "minimum": 0,
            "exclusiveMinimum": true
        },
        "maximum": {
            "type": "number"
        },
        "exclusiveMaximum": {
            "type": "boolean",
            "default": false
        },
        "minimum": {
            "type": "number"
        },
        "exclusiveMinimum": {
            "type": "boolean",
            "default": false
        },
        "maxLength": { "$ref": "#/definitions/positiveInteger" },
        "minLength": { "$ref": "#/definitions/positiveIntegerDefault0" },
        "pattern": {
            "type": "string",
            "format": "regex"
        },
        "additionalItems": {
            "anyOf": [
                { "type": "boolean" },
                { "$ref": "#" }
            ],
            "default": {}
        },
        "items": {
            "anyOf": [
                { "$ref": "#" },
                { "$ref": "#/definitions/schemaArray" }
            ],
            "default": {}
        },
        "maxItems": { "$ref": "#/definitions/positiveInteger" },
        "minItems": { "$ref": "#/definitions/positiveIntegerDefault0" },
        "uniqueItems": {
            "type": "boolean",
            "default": false
        },
        "maxProperties": { "$ref": "#/definitions/positiveInteger" },
        "minProperties": { "$ref": "#/definitions/positiveIntegerDefault0" },
        "required": { "$ref": "#/definitions/stringArray" },
        "additionalProperties": {
            "anyOf": [
                { "type": "boolean" },
                { "$ref": "#" }
            ],
            "default": {}
        },
        "definitions": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "properties": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "patternProperties": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "dependencies": {
            "type": "object",
            "additionalProperties": {
                "anyOf": [
                    { "$ref": "#" },
                    { "$ref": "#/definitions/stringArray" }
                ]
            }
        },
        "enum": {
            "type": "array",
            "minItems": 1,
            "uniqueItems": true
        },
        "type": {
            "anyOf": [
                { "$ref": "#/definitions/simpleTypes" },
                {
                    "type": "array",
                    "items": { "$ref": "#/definitions/simpleTypes" },
                    "minItems": 1,
                    "uniqueItems": true
                }
            ]
        },
        "format": { "type": "string" },
        "allOf": { "$ref": "#/definitions/schemaArray" },
        "anyOf": { "$ref": "#/definitions/schemaArray" },
        "oneOf": { "$ref": "#/definitions/schemaArray" },
        "not": { "$ref": "#" }
    },
    "dependencies": {
        "exclusiveMaximum": [ "maximum" ],
        "exclusiveMinimum": [ "minimum" ]
    },
    "default": {}
}
    ''';

  static final String draft6 = r'''
    {
    "$schema": "http://json-schema.org/draft-06/schema#",
    "$id": "http://json-schema.org/draft-06/schema#",
    "title": "Core schema meta-schema",
    "definitions": {
        "schemaArray": {
            "type": "array",
            "minItems": 1,
            "items": { "$ref": "#" }
        },
        "nonNegativeInteger": {
            "type": "integer",
            "minimum": 0
        },
        "nonNegativeIntegerDefault0": {
            "allOf": [
                { "$ref": "#/definitions/nonNegativeInteger" },
                { "default": 0 }
            ]
        },
        "simpleTypes": {
            "enum": [
                "array",
                "boolean",
                "integer",
                "null",
                "number",
                "object",
                "string"
            ]
        },
        "stringArray": {
            "type": "array",
            "items": { "type": "string" },
            "uniqueItems": true,
            "default": []
        }
    },
    "type": ["object", "boolean"],
    "properties": {
        "$id": {
            "type": "string",
            "format": "uri-reference"
        },
        "$schema": {
            "type": "string",
            "format": "uri"
        },
        "$ref": {
            "type": "string",
            "format": "uri-reference"
        },
        "title": {
            "type": "string"
        },
        "description": {
            "type": "string"
        },
        "default": {},
        "examples": {
            "type": "array",
            "items": {}
        },
        "multipleOf": {
            "type": "number",
            "exclusiveMinimum": 0
        },
        "maximum": {
            "type": "number"
        },
        "exclusiveMaximum": {
            "type": "number"
        },
        "minimum": {
            "type": "number"
        },
        "exclusiveMinimum": {
            "type": "number"
        },
        "maxLength": { "$ref": "#/definitions/nonNegativeInteger" },
        "minLength": { "$ref": "#/definitions/nonNegativeIntegerDefault0" },
        "pattern": {
            "type": "string",
            "format": "regex"
        },
        "additionalItems": { "$ref": "#" },
        "items": {
            "anyOf": [
                { "$ref": "#" },
                { "$ref": "#/definitions/schemaArray" }
            ],
            "default": {}
        },
        "maxItems": { "$ref": "#/definitions/nonNegativeInteger" },
        "minItems": { "$ref": "#/definitions/nonNegativeIntegerDefault0" },
        "uniqueItems": {
            "type": "boolean",
            "default": false
        },
        "contains": { "$ref": "#" },
        "maxProperties": { "$ref": "#/definitions/nonNegativeInteger" },
        "minProperties": { "$ref": "#/definitions/nonNegativeIntegerDefault0" },
        "required": { "$ref": "#/definitions/stringArray" },
        "additionalProperties": { "$ref": "#" },
        "definitions": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "properties": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "patternProperties": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "dependencies": {
            "type": "object",
            "additionalProperties": {
                "anyOf": [
                    { "$ref": "#" },
                    { "$ref": "#/definitions/stringArray" }
                ]
            }
        },
        "propertyNames": { "$ref": "#" },
        "const": {},
        "enum": {
            "type": "array",
            "minItems": 1,
            "uniqueItems": true
        },
        "type": {
            "anyOf": [
                { "$ref": "#/definitions/simpleTypes" },
                {
                    "type": "array",
                    "items": { "$ref": "#/definitions/simpleTypes" },
                    "minItems": 1,
                    "uniqueItems": true
                }
            ]
        },
        "format": { "type": "string" },
        "allOf": { "$ref": "#/definitions/schemaArray" },
        "anyOf": { "$ref": "#/definitions/schemaArray" },
        "oneOf": { "$ref": "#/definitions/schemaArray" },
        "not": { "$ref": "#" }
    },
    "default": {}
}
    ''';

  static final String draft7 = r'''{
    "$schema": "http://json-schema.org/draft-07/schema#",
    "$id": "http://json-schema.org/draft-07/schema#",
    "title": "Core schema meta-schema",
    "definitions": {
        "schemaArray": {
            "type": "array",
            "minItems": 1,
            "items": { "$ref": "#" }
        },
        "nonNegativeInteger": {
            "type": "integer",
            "minimum": 0
        },
        "nonNegativeIntegerDefault0": {
            "allOf": [
                { "$ref": "#/definitions/nonNegativeInteger" },
                { "default": 0 }
            ]
        },
        "simpleTypes": {
            "enum": [
                "array",
                "boolean",
                "integer",
                "null",
                "number",
                "object",
                "string"
            ]
        },
        "stringArray": {
            "type": "array",
            "items": { "type": "string" },
            "uniqueItems": true,
            "default": []
        }
    },
    "type": ["object", "boolean"],
    "properties": {
        "$id": {
            "type": "string",
            "format": "uri-reference"
        },
        "$schema": {
            "type": "string",
            "format": "uri"
        },
        "$ref": {
            "type": "string",
            "format": "uri-reference"
        },
        "$comment": {
            "type": "string"
        },
        "title": {
            "type": "string"
        },
        "description": {
            "type": "string"
        },
        "default": true,
        "readOnly": {
            "type": "boolean",
            "default": false
        },
        "writeOnly": {
            "type": "boolean",
            "default": false
        },
        "examples": {
            "type": "array",
            "items": true
        },
        "multipleOf": {
            "type": "number",
            "exclusiveMinimum": 0
        },
        "maximum": {
            "type": "number"
        },
        "exclusiveMaximum": {
            "type": "number"
        },
        "minimum": {
            "type": "number"
        },
        "exclusiveMinimum": {
            "type": "number"
        },
        "maxLength": { "$ref": "#/definitions/nonNegativeInteger" },
        "minLength": { "$ref": "#/definitions/nonNegativeIntegerDefault0" },
        "pattern": {
            "type": "string",
            "format": "regex"
        },
        "additionalItems": { "$ref": "#" },
        "items": {
            "anyOf": [
                { "$ref": "#" },
                { "$ref": "#/definitions/schemaArray" }
            ],
            "default": true
        },
        "maxItems": { "$ref": "#/definitions/nonNegativeInteger" },
        "minItems": { "$ref": "#/definitions/nonNegativeIntegerDefault0" },
        "uniqueItems": {
            "type": "boolean",
            "default": false
        },
        "contains": { "$ref": "#" },
        "maxProperties": { "$ref": "#/definitions/nonNegativeInteger" },
        "minProperties": { "$ref": "#/definitions/nonNegativeIntegerDefault0" },
        "required": { "$ref": "#/definitions/stringArray" },
        "additionalProperties": { "$ref": "#" },
        "definitions": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "properties": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "default": {}
        },
        "patternProperties": {
            "type": "object",
            "additionalProperties": { "$ref": "#" },
            "propertyNames": { "format": "regex" },
            "default": {}
        },
        "dependencies": {
            "type": "object",
            "additionalProperties": {
                "anyOf": [
                    { "$ref": "#" },
                    { "$ref": "#/definitions/stringArray" }
                ]
            }
        },
        "propertyNames": { "$ref": "#" },
        "const": true,
        "enum": {
            "type": "array",
            "items": true,
            "minItems": 1,
            "uniqueItems": true
        },
        "type": {
            "anyOf": [
                { "$ref": "#/definitions/simpleTypes" },
                {
                    "type": "array",
                    "items": { "$ref": "#/definitions/simpleTypes" },
                    "minItems": 1,
                    "uniqueItems": true
                }
            ]
        },
        "format": { "type": "string" },
        "contentMediaType": { "type": "string" },
        "contentEncoding": { "type": "string" },
        "if": { "$ref": "#" },
        "then": { "$ref": "#" },
        "else": { "$ref": "#" },
        "allOf": { "$ref": "#/definitions/schemaArray" },
        "anyOf": { "$ref": "#/definitions/schemaArray" },
        "oneOf": { "$ref": "#/definitions/schemaArray" },
        "not": { "$ref": "#" }
    },
    "default": true
}
  ''';

  static final String draft2019_09 = r'''{
    "$schema": "https://json-schema.org/draft/2019-09/schema",
    "$id": "https://json-schema.org/draft/2019-09/schema",
    "$vocabulary": {
        "https://json-schema.org/draft/2019-09/vocab/core": true,
        "https://json-schema.org/draft/2019-09/vocab/applicator": true,
        "https://json-schema.org/draft/2019-09/vocab/validation": true,
        "https://json-schema.org/draft/2019-09/vocab/meta-data": true,
        "https://json-schema.org/draft/2019-09/vocab/format": false,
        "https://json-schema.org/draft/2019-09/vocab/content": true
    },
    "$recursiveAnchor": true,
    "allOf": [
      {"$ref": "#/$defs/vocab-applicator"},
      {"$ref": "#/$defs/vocab-content"},
      {"$ref": "#/$defs/vocab-core"},
      {"$ref": "#/$defs/vocab-format"},
      {"$ref": "#/$defs/vocab-metadata"},
      {"$ref": "#/$defs/vocab-validation"}
    ],
    "title": "Core and Validation specifications meta-schema",
    "type": ["object", "boolean"],
    "properties": {
        "definitions": {
            "$comment": "While no longer an official keyword as it is replaced by $defs, this keyword is retained in the meta-schema to prevent incompatible extensions as it remains in common use.",
            "type": "object",
            "additionalProperties": { "$recursiveRef": "#" },
            "default": {}
        },
        "dependencies": {
            "$comment": "\"dependencies\" is no longer a keyword, but schema authors should avoid redefining it to facilitate a smooth transition to \"dependentSchemas\" and \"dependentRequired\"",
            "type": "object",
            "additionalProperties": {
                "anyOf": [
                    { "$recursiveRef": "#" },
                    { "$ref": "meta/validation#/$defs/stringArray" }
                ]
            }
        }
    },
    "$defs": {''' +
      '''
      "vocab-applicator": ${Draft2019Subschemas.applicator},
      "vocab-content": ${Draft2019Subschemas.content},
      "vocab-core": ${Draft2019Subschemas.core},
      "vocab-format": ${Draft2019Subschemas.format},
      "vocab-metadata": ${Draft2019Subschemas.metadata},
      "vocab-validation": ${Draft2019Subschemas.validation}
    }
}
  ''';
}

class Draft2019Subschemas {
  static final String format = r'''{
    "$schema": "https://json-schema.org/draft/2019-09/schema",
    "$id": "https://json-schema.org/draft/2019-09/meta/format",
    "$vocabulary": {
        "https://json-schema.org/draft/2019-09/vocab/format": true
    },
    "$recursiveAnchor": true,

    "title": "Format vocabulary meta-schema",
    "type": ["object", "boolean"],
    "properties": {
        "format": { "type": "string" }
    }
}''';

  static final String core = r'''{
    "$schema": "https://json-schema.org/draft/2019-09/schema",
    "$id": "https://json-schema.org/draft/2019-09/meta/core",
    "$vocabulary": {
        "https://json-schema.org/draft/2019-09/vocab/core": true
    },
    "$recursiveAnchor": true,

    "title": "Core vocabulary meta-schema",
    "type": ["object", "boolean"],
    "properties": {
        "$id": {
            "type": "string",
            "format": "uri-reference",
            "$comment": "Non-empty fragments not allowed.",
            "pattern": "^[^#]*#?$"
        },
        "$schema": {
            "type": "string",
            "format": "uri"
        },
        "$anchor": {
            "type": "string",
            "pattern": "^[A-Za-z][-A-Za-z0-9.:_]*$"
        },
        "$ref": {
            "type": "string",
            "format": "uri-reference"
        },
        "$recursiveRef": {
            "type": "string",
            "format": "uri-reference"
        },
        "$recursiveAnchor": {
            "type": "boolean",
            "default": false
        },
        "$vocabulary": {
            "type": "object",
            "propertyNames": {
                "type": "string",
                "format": "uri"
            },
            "additionalProperties": {
                "type": "boolean"
            }
        },
        "$comment": {
            "type": "string"
        },
        "$defs": {
            "type": "object",
            "additionalProperties": { "$recursiveRef": "#" },
            "default": {}
        }
    }
}''';

  static final String applicator = r'''{
    "$schema": "https://json-schema.org/draft/2019-09/schema",
    "$id": "https://json-schema.org/draft/2019-09/meta/applicator",
    "$vocabulary": {
        "https://json-schema.org/draft/2019-09/vocab/applicator": true
    },
    "$recursiveAnchor": true,

    "title": "Applicator vocabulary meta-schema",
    "type": ["object", "boolean"],
    "properties": {
        "additionalItems": { "$recursiveRef": "#" },
        "unevaluatedItems": { "$recursiveRef": "#" },
        "items": {
            "anyOf": [
                { "$recursiveRef": "#" },
                { "$ref": "#/$defs/schemaArray" }
            ]
        },
        "contains": { "$recursiveRef": "#" },
        "additionalProperties": { "$recursiveRef": "#" },
        "unevaluatedProperties": { "$recursiveRef": "#" },
        "properties": {
            "type": "object",
            "additionalProperties": { "$recursiveRef": "#" },
            "default": {}
        },
        "patternProperties": {
            "type": "object",
            "additionalProperties": { "$recursiveRef": "#" },
            "propertyNames": { "format": "regex" },
            "default": {}
        },
        "dependentSchemas": {
            "type": "object",
            "additionalProperties": {
                "$recursiveRef": "#"
            }
        },
        "propertyNames": { "$recursiveRef": "#" },
        "if": { "$recursiveRef": "#" },
        "then": { "$recursiveRef": "#" },
        "else": { "$recursiveRef": "#" },
        "allOf": { "$ref": "#/$defs/schemaArray" },
        "anyOf": { "$ref": "#/$defs/schemaArray" },
        "oneOf": { "$ref": "#/$defs/schemaArray" },
        "not": { "$recursiveRef": "#" }
    },
    "$defs": {
        "schemaArray": {
            "type": "array",
            "minItems": 1,
            "items": { "$recursiveRef": "#" }
        }
    }
}''';

  static final String validation = r'''{
    "$schema": "https://json-schema.org/draft/2019-09/schema",
    "$id": "https://json-schema.org/draft/2019-09/meta/validation",
    "$vocabulary": {
        "https://json-schema.org/draft/2019-09/vocab/validation": true
    },
    "$recursiveAnchor": true,

    "title": "Validation vocabulary meta-schema",
    "type": ["object", "boolean"],
    "properties": {
        "multipleOf": {
            "type": "number",
            "exclusiveMinimum": 0
        },
        "maximum": {
            "type": "number"
        },
        "exclusiveMaximum": {
            "type": "number"
        },
        "minimum": {
            "type": "number"
        },
        "exclusiveMinimum": {
            "type": "number"
        },
        "maxLength": { "$ref": "#/$defs/nonNegativeInteger" },
        "minLength": { "$ref": "#/$defs/nonNegativeIntegerDefault0" },
        "pattern": {
            "type": "string",
            "format": "regex"
        },
        "maxItems": { "$ref": "#/$defs/nonNegativeInteger" },
        "minItems": { "$ref": "#/$defs/nonNegativeIntegerDefault0" },
        "uniqueItems": {
            "type": "boolean",
            "default": false
        },
        "maxContains": { "$ref": "#/$defs/nonNegativeInteger" },
        "minContains": {
            "$ref": "#/$defs/nonNegativeInteger",
            "default": 1
        },
        "maxProperties": { "$ref": "#/$defs/nonNegativeInteger" },
        "minProperties": { "$ref": "#/$defs/nonNegativeIntegerDefault0" },
        "required": { "$ref": "#/$defs/stringArray" },
        "dependentRequired": {
            "type": "object",
            "additionalProperties": {
                "$ref": "#/$defs/stringArray"
            }
        },
        "const": true,
        "enum": {
            "type": "array",
            "items": true
        },
        "type": {
            "anyOf": [
                { "$ref": "#/$defs/simpleTypes" },
                {
                    "type": "array",
                    "items": { "$ref": "#/$defs/simpleTypes" },
                    "minItems": 1,
                    "uniqueItems": true
                }
            ]
        }
    },
    "$defs": {
        "nonNegativeInteger": {
            "type": "integer",
            "minimum": 0
        },
        "nonNegativeIntegerDefault0": {
            "$ref": "#/$defs/nonNegativeInteger",
            "default": 0
        },
        "simpleTypes": {
            "enum": [
                "array",
                "boolean",
                "integer",
                "null",
                "number",
                "object",
                "string"
            ]
        },
        "stringArray": {
            "type": "array",
            "items": { "type": "string" },
            "uniqueItems": true,
            "default": []
        }
    }
}''';

  static final String metadata = r'''{
    "$schema": "https://json-schema.org/draft/2019-09/schema",
    "$id": "https://json-schema.org/draft/2019-09/meta/meta-data",
    "$vocabulary": {
        "https://json-schema.org/draft/2019-09/vocab/meta-data": true
    },
    "$recursiveAnchor": true,

    "title": "Meta-data vocabulary meta-schema",

    "type": ["object", "boolean"],
    "properties": {
        "title": {
            "type": "string"
        },
        "description": {
            "type": "string"
        },
        "default": true,
        "deprecated": {
            "type": "boolean",
            "default": false
        },
        "readOnly": {
            "type": "boolean",
            "default": false
        },
        "writeOnly": {
            "type": "boolean",
            "default": false
        },
        "examples": {
            "type": "array",
            "items": true
        }
    }
}''';

  static final String content = r'''{
    "$schema": "https://json-schema.org/draft/2019-09/schema",
    "$id": "https://json-schema.org/draft/2019-09/meta/content",
    "$vocabulary": {
        "https://json-schema.org/draft/2019-09/vocab/content": true
    },
    "$recursiveAnchor": true,

    "title": "Content vocabulary meta-schema",

    "type": ["object", "boolean"],
    "properties": {
        "contentMediaType": { "type": "string" },
        "contentEncoding": { "type": "string" },
        "contentSchema": { "$recursiveRef": "#" }
    }
}''';
}

class SupportedVocabularies {
  static final CORE = Uri.parse("https://json-schema.org/draft/2019-09/vocab/core");
  static final APPLICATOR = Uri.parse("https://json-schema.org/draft/2019-09/vocab/applicator");
  static final VALIDATION = Uri.parse("https://json-schema.org/draft/2019-09/vocab/validation");
  static final METADATA = Uri.parse("https://json-schema.org/draft/2019-09/vocab/meta-data");
  static final FORMAT = Uri.parse("https://json-schema.org/draft/2019-09/vocab/format");
  static final CONTENT = Uri.parse("https://json-schema.org/draft/2019-09/vocab/content");
  static final ALL = {
    CORE,
    APPLICATOR,
    VALIDATION,
    METADATA,
    FORMAT,
    CONTENT,
  };
}
