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
import 'dart:core';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:json_schema/src/json_schema/format_exceptions.dart';
import 'package:logging/logging.dart';

import 'package:json_schema/src/json_schema/constants.dart';
import 'package:json_schema/src/json_schema/json_schema.dart';
import 'package:json_schema/src/json_schema/schema_type.dart';
import 'package:json_schema/src/json_schema/global_platform_functions.dart' show defaultValidators;
import 'package:rfc_6901/rfc_6901.dart';

final Logger _logger = Logger('Validator');

class Instance {
  Instance(dynamic data, {String path = ''}) {
    this.data = data;
    this.path = path;
  }

  dynamic data;
  String path;

  @override
  toString() => data.toString();
}

/// The result of validating data against a schema
class ValidationResults {
  ValidationResults(errors, warnings) {
    this.errors = List.of(errors);
    this.warnings = List.of(warnings);
  }

  /// Correctness issues discovered by validation.
  List<ValidationError> errors = [];

  /// Potential issues
  List<ValidationError> warnings = [];

  @override
  String toString() {
    return '${errors.isEmpty ? 'VALID' : 'INVALID'}${errors.isEmpty ? ', Errors: ${errors}' : ''}${warnings.isEmpty ? ', Warnings: ${warnings}' : ''}';
  }
}

class ValidationError {
  ValidationError._(this.instancePath, this.schemaPath, this.message);

  /// Path in the instance data to the key where this error occurred
  String instancePath;

  /// Path to the key in the schema containing the rule that produced this error
  String schemaPath;

  /// A human-readable message explaining why validation failed
  String message;

  @override
  toString() => '${instancePath.isEmpty ? '# (root)' : instancePath}: $message';
}

/// Initialized with schema, validates instances against it
class Validator {
  Validator(this._rootSchema);

  Validator._(this._rootSchema, {bool inEvaluatedItemsContext = false}) {
    if (inEvaluatedItemsContext) {
      _pushEvaluatedItemsContext();
    }
  }

  ValidationResults _results;

  ValidationResults get results => _results;

  @Deprecated('Use validateWithResults and ValidationResults.errors.map((e) => e.toString()).toList() instead')
  List<String> get errors => _errors.map((e) => e.toString()).toList();

  @Deprecated('Use validateWithResults and ValidationResults.errors instead')
  List<ValidationError> get errorObjects => _errors;

  bool _validateFormats;

  bool _treatWarningsAsErrors;

  /// The set of vocabularies (from the schema's metaschema) to be used for validation
  Set<Uri> _vocabulary;

  /// Keep track of the number of evaluated items contexts in a list, treating the list as a stack.
  /// The context is an [int], representing the number of successful evaluations for the list in the
  /// given context.
  List<int> _evaluatedItemsContext = [];

  /// Validate the [instance] against the this validator's schema, returning results
  ValidationResults validateWithResults(dynamic instance,
      {bool reportMultipleErrors = false, bool parseJson = false, bool validateFormats}) {
    // Reference: https://json-schema.org/draft/2019-09/release-notes.html#format-vocabulary
    // By default, formats are validated on a best-effort basis from draft4 through draft7.
    // Starting with Draft 2019-09, formats shouldn't be validated by default.
    _validateFormats = validateFormats ?? _rootSchema.schemaVersion <= SchemaVersion.draft7;

    dynamic data = instance;
    if (parseJson && instance is String) {
      try {
        data = json.decode(instance);
      } catch (e) {
        throw ArgumentError('JSON instance provided to validate is not valid JSON.');
      }
    }

    _errors = [];
    _warnings = [];
    _reportMultipleErrors = reportMultipleErrors;
    _errors = [];
    // Initialize and validate the vocabulary to be used for validation
    _vocabulary = getVocabulary(_rootSchema);
    if (!_reportMultipleErrors) {
      try {
        _validate(_rootSchema, data);
        return ValidationResults(_errors, _warnings);
      } on FormatException {
        return ValidationResults(_errors, _warnings);
      } catch (e) {
        _logger.shout('Unexpected Exception: $e');
        return null;
      }
    }

    _validate(_rootSchema, data);
    return ValidationResults(_errors, _warnings);
  }

  /// Validate the [instance] against the this validator's schema
  @Deprecated('Use validateWithResults instead')
  bool validate(dynamic instance, {bool reportMultipleErrors = false, bool parseJson = false, bool validateFormats}) {
    return validateWithResults(instance,
            reportMultipleErrors: reportMultipleErrors, parseJson: parseJson, validateFormats: validateFormats)
        .errors
        .isEmpty;
  }

  Set<Uri> getVocabulary(JsonSchema s) {
    if (s.schemaVersion < SchemaVersion.draft2019_09) {
      // For simplicity's sake, we just use all supported vocabularies for drafts older than 2019.
      return SupportedVocabularies.ALL;
    } else {
      final vocab = s.metaschemaVocabulary();
      vocab?.forEach((uri, isRequired) {
        if (!SupportedVocabularies.ALL.contains(uri)) {
          if (isRequired) {
            throw ArgumentError('unsupported vocabulary required for validation', '$uri');
          } else {
            _warn('unsupported optional vocabulary in use: $uri', '', r'$schema');
          }
        }
      });
      return Set.of(vocab?.keys ?? Set<Uri>()).intersection(SupportedVocabularies.ALL);
    }
  }

  static bool _typeMatch(SchemaType type, JsonSchema schema, dynamic instance) {
    if (type == SchemaType.object) {
      return instance is Map;
    } else if (type == SchemaType.string) {
      return instance is String;
    } else if (type == SchemaType.integer) {
      return instance is int ||
          (schema.schemaVersion >= SchemaVersion.draft6 && instance is num && instance.remainder(1) == 0);
    } else if (type == SchemaType.number) {
      return instance is num;
    } else if (type == SchemaType.array) {
      return instance is List;
    } else if (type == SchemaType.boolean) {
      return instance is bool;
    } else if (type == SchemaType.nullValue) {
      return instance == null;
    }
    return false;
  }

  void _numberValidation(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.VALIDATION)) return;
    final num n = instance.data;
    final maximum = schema.maximum;
    final minimum = schema.minimum;
    final exclusiveMaximum = schema.exclusiveMaximum;
    final exclusiveMinimum = schema.exclusiveMinimum;

    if (exclusiveMaximum != null) {
      if (n >= exclusiveMaximum) {
        _err('exclusiveMaximum exceeded ($n >= $exclusiveMaximum)', instance.path, schema.path);
      }
    } else if (maximum != null) {
      if (n > maximum) {
        _err('maximum exceeded ($n > $maximum)', instance.path, schema.path);
      }
    }

    if (exclusiveMinimum != null) {
      if (n <= exclusiveMinimum) {
        _err('exclusiveMinimum violated ($n <= $exclusiveMinimum)', instance.path, schema.path);
      }
    } else if (minimum != null) {
      if (n < minimum) {
        _err('minimum violated ($n < $minimum)', instance.path, schema.path);
      }
    }

    final multipleOf = schema.multipleOf;
    if (multipleOf != null) {
      if (multipleOf is int && n is int) {
        if (0 != n % multipleOf) {
          _err('multipleOf violated ($n % $multipleOf)', instance.path, schema.path);
        }
      } else {
        final double result = n / multipleOf;
        if (result == double.infinity) {
          _err('multipleOf violated ($n % $multipleOf)', instance.path, schema.path);
        } else if (result.truncate() != result) {
          _err('multipleOf violated ($n % $multipleOf)', instance.path, schema.path);
        }
      }
    }
  }

  void _typeValidation(JsonSchema schema, dynamic instance) {
    final typeList = schema.typeList;
    if (_vocabulary.contains(SupportedVocabularies.VALIDATION) && typeList != null && typeList.isNotEmpty) {
      if (!typeList.any((type) => _typeMatch(type, schema, instance.data))) {
        _err('type: wanted ${typeList} got $instance', instance.path, schema.path);
      }
    }
  }

  void _constValidation(JsonSchema schema, dynamic instance) {
    if (_vocabulary.contains(SupportedVocabularies.VALIDATION) &&
        schema.hasConst &&
        !DeepCollectionEquality().equals(instance.data, schema.constValue)) {
      _err('const violated ${instance}', instance.path, schema.path);
    }
  }

  void _enumValidation(JsonSchema schema, dynamic instance) {
    final enumValues = schema.enumValues;
    if (_vocabulary.contains(SupportedVocabularies.VALIDATION) && enumValues.isNotEmpty) {
      try {
        enumValues.singleWhere((v) => DeepCollectionEquality().equals(instance.data, v));
      } on StateError {
        _err('enum violated ${instance}', instance.path, schema.path);
      }
    }
  }

  void _validateDeprecated(JsonSchema schema, dynamic instance) {
    if (schema.deprecated == true) {
      _warn('deprecated ${instance}', instance.path, schema.path);
    }
  }

  void _stringValidation(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.VALIDATION)) return;
    final actual = instance.data.runes.length;
    final minLength = schema.minLength;
    final maxLength = schema.maxLength;
    if (maxLength is int && actual > maxLength) {
      _err('maxLength exceeded ($instance vs $maxLength)', instance.path, schema.path);
    } else if (minLength is int && actual < minLength) {
      _err('minLength violated ($instance vs $minLength)', instance.path, schema.path);
    }
    final pattern = schema.pattern;
    if (pattern != null && !pattern.hasMatch(instance.data)) {
      _err('pattern violated ($instance vs $pattern)', instance.path, schema.path);
    }
  }

  void _itemsValidation(JsonSchema schema, Instance instance) {
    final int actual = instance.data.length;

    if (_vocabulary.contains(SupportedVocabularies.APPLICATOR)) {
      final singleSchema = schema.items;
      if (singleSchema != null) {
        instance.data.asMap().forEach((index, item) {
          final itemInstance = Instance(item, path: '${instance.path}/$index');
          _validate(singleSchema, itemInstance);
        });
        // All the items in this list have been evaluated.
        _setEvaluatedItemCount(actual);
      } else {
        final items = schema.itemsList;

        if (items != null) {
          final expected = items.length;
          final end = min(expected, actual);
          // All the items have been evaluated somewhere else, or they will be evaluated upto the end count.
          _setMaxEvaluatedItemCount(end);
          for (int i = 0; i < end; i++) {
            assert(items[i] != null);
            final itemInstance = Instance(instance.data[i], path: '${instance.path}/$i');
            _validate(items[i], itemInstance);
          }
          if (schema.additionalItemsSchema != null) {
            for (int i = end; i < actual; i++) {
              final itemInstance = Instance(instance.data[i], path: '${instance.path}/$i');
              _validate(schema.additionalItemsSchema, itemInstance);
            }
          } else if (schema.additionalItemsBool != null) {
            if (!schema.additionalItemsBool && actual > end) {
              _err('additionalItems false', instance.path, schema.path + '/additionalItems');
            } else {
              // All the items in this list have been evaluated.
              _setEvaluatedItemCount(actual);
            }
          }
        }
      }
    }

    if (!_vocabulary.contains(SupportedVocabularies.VALIDATION)) return;

    final maxItems = schema.maxItems;
    final minItems = schema.minItems;
    if (maxItems is int && actual > maxItems) {
      _err('maxItems exceeded ($actual vs $maxItems)', instance.path, schema.path);
    } else if (schema.minItems is int && actual < schema.minItems) {
      _err('minItems violated ($actual vs $minItems)', instance.path, schema.path);
    }

    if (schema.uniqueItems) {
      final end = instance.data.length;
      final penultimate = end - 1;
      for (int i = 0; i < penultimate; i++) {
        for (int j = i + 1; j < end; j++) {
          if (DeepCollectionEquality().equals(instance.data[i], instance.data[j])) {
            _err('uniqueItems violated: $instance [$i]==[$j]', instance.path, schema.path);
          }
        }
      }
    }

    if (schema.contains != null) {
      final maxContains = schema.maxContains;
      final minContains = schema.minContains;
      final containsItems =
          instance.data.where((item) => Validator(schema.contains).validateWithResults(item).errors.isEmpty).toList();
      if (minContains is int && containsItems.length < minContains) {
        _err('minContains violated: $instance', instance.path, schema.path);
      }
      if (maxContains is int && containsItems.length > maxContains) {
        _err('maxContains violated: $instance', instance.path, schema.path);
      }
      if (containsItems.length == 0 && !(minContains is int && minContains == 0)) {
        _err('contains violated: $instance', instance.path, schema.path);
      }
    }
  }

  _validateUnevaluatedItems(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.APPLICATOR)) return;
    final actual = instance.data.length;
    if (schema.unevaluatedItems != null && schema.additionalItemsBool is! bool) {
      if (schema.unevaluatedItems.schemaBool != null) {
        if (schema.unevaluatedItems.schemaBool == false && actual > this._evaluatedItemCount) {
          _err('unevaluatedItems false', instance.path, schema.path + '/unevaluatedItems');
        }
      } else {
        for (int i = this._evaluatedItemCount; i < actual; i++) {
          final itemInstance = Instance(instance.data[i], path: '${instance.path}/$i');
          _validate(schema.unevaluatedItems, itemInstance);
        }
      }
      // If we passed these test, then all the items have been evaluated.
      _setEvaluatedItemCount(actual);
    }
  }

  /// Helper function to capture the number of evaluatedItems and update the local count.
  bool _validateAndCaptureEvaluations(JsonSchema s, Instance instance) {
    var v = Validator._(s, inEvaluatedItemsContext: _isInEvaluatedItemContext);
    var isValid = v.validateWithResults(instance).errors.isEmpty;
    if (isValid) {
      _setMaxEvaluatedItemCount(v._evaluatedItemCount);
    }
    return isValid;
  }

  _validateAllOf(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.APPLICATOR)) return;
    if (!schema.allOf.every((s) => _validateAndCaptureEvaluations(s, instance))) {
      _err('${schema.path}: allOf violated ${instance}', instance.path, schema.path + '/allOf');
    }
  }

  void _validateAnyOf(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.APPLICATOR)) return;
    // `any` will short circuit on the first successful subschema. Each sub-schema needs to be evaluated
    // to properly account for evaluated properties and items.
    var results = schema.anyOf.map((s) => _validateAndCaptureEvaluations(s, instance)).toList();
    if (!results.any((s) => s)) {
      // TODO: deal with /anyOf
      _err('${schema.path}/anyOf: anyOf violated ($instance, ${schema.anyOf})', instance.path, schema.path + '/anyOf');
    }
  }

  void _validateOneOf(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.APPLICATOR)) return;
    try {
      schema.oneOf.map((s) => _validateAndCaptureEvaluations(s, instance)).singleWhere((s) => s);
    } on StateError catch (notOneOf) {
      // TODO consider passing back validation errors from sub-validations
      _err('${schema.path}/oneOf: violated ${notOneOf.message}', instance.path, schema.path + '/oneOf');
    }
  }

  void _validateNot(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.APPLICATOR)) return;
    if (Validator(schema.notSchema).validateWithResults(instance).errors.isEmpty) {
      _err('${schema.notSchema.path}: not violated', instance.path, schema.notSchema.path);
    }
  }

  void _validateFormat(JsonSchema schema, Instance instance) {
    if (!_validateFormats || !_vocabulary.contains(SupportedVocabularies.FORMAT)) return;

    // Non-strings in formats should be ignored.
    if (instance.data is! String) return;

    switch (schema.format) {
      case 'date-time':
        try {
          DateTime.parse(instance.data);
        } catch (e) {
          _err('"date-time" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'time':
        // regex is an allowed format in draft3, out in draft4/6, back in draft7.
        // Since we don't support draft3, just draft7 is needed here.
        if (SchemaVersion.draft7 != schema.schemaVersion) return;
        if (JsonSchemaValidationRegexes.fullTime.firstMatch(instance.data) == null) {
          _err('"time" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'date':
        // regex is an allowed format in draft3, out in draft4/6, back in draft7.
        // Since we don't support draft3, just draft7 is needed here.
        if (SchemaVersion.draft7 != schema.schemaVersion) return;
        if (JsonSchemaValidationRegexes.fullDate.firstMatch(instance.data) == null) {
          _err('"date" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'uri':
        final isValid = defaultValidators.uriValidator ?? (_) => false;

        if (!isValid(instance.data)) {
          _err('"uri" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'iri':
        if (SchemaVersion.draft7 != schema.schemaVersion) return;
        // Dart's URI class supports parsing IRIs, so we can use the same validator
        final isValid = defaultValidators.uriValidator ?? (_) => false;

        if (!isValid(instance.data)) {
          _err('"iri" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'iri-reference':
        if (SchemaVersion.draft7 != schema.schemaVersion) return;

        // Dart's URI class supports parsing IRIs, so we can use the same validator
        final isValid = defaultValidators.uriReferenceValidator ?? (_) => false;

        if (!isValid(instance.data)) {
          _err('"iri-reference" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'uri-reference':
        if (![SchemaVersion.draft6, SchemaVersion.draft7].contains(schema.schemaVersion)) return;
        final isValid = defaultValidators.uriReferenceValidator ?? (_) => false;

        if (!isValid(instance.data)) {
          _err('"uri-reference" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'uri-template':
        if (![SchemaVersion.draft6, SchemaVersion.draft7].contains(schema.schemaVersion)) return;
        final isValid = defaultValidators.uriTemplateValidator ?? (_) => false;

        if (!isValid(instance.data)) {
          _err('"uri-template" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'email':
        final isValid = defaultValidators.emailValidator ?? (_) => false;

        if (!isValid(instance.data)) {
          _err('"email" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'idn-email':
        // No maintained dart packages exist to validate RFC6531,
        // and it's too complex for a regex, so best effort is to pass for now.
        break;
      case 'ipv4':
        if (JsonSchemaValidationRegexes.ipv4.firstMatch(instance.data) == null) {
          _err('"ipv4" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'ipv6':
        try {
          Uri.parseIPv6Address(instance.data);
        } on FormatException catch (_) {
          _err('"ipv6" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'hostname':
        final regexp = schema.schemaVersion.compareTo(SchemaVersion.draft2019_09) < 0
            ? JsonSchemaValidationRegexes.hostname
            // Updated in Draft 2019-09
            : JsonSchemaValidationRegexes.hostnameDraft2019;

        if (regexp.firstMatch(instance.data) == null) {
          _err('"hostname" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'idn-hostname':
        // Introduced in Draft 7
        if (schema.schemaVersion.compareTo(SchemaVersion.draft7) < 0) return;

        final regexp = schema.schemaVersion.compareTo(SchemaVersion.draft2019_09) < 0
            ? JsonSchemaValidationRegexes.idnHostname
            // Updated in Draft 2019-09
            : JsonSchemaValidationRegexes.idnHostnameDraft2019;

        if (regexp.firstMatch(instance.data) == null) {
          _err('"idn-hostname" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'json-pointer':
        if (![SchemaVersion.draft6, SchemaVersion.draft7].contains(schema.schemaVersion)) return;
        try {
          JsonPointer(instance.data);
        } on FormatException catch (_) {
          _err('"json-pointer" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'relative-json-pointer':
        if (SchemaVersion.draft7 != schema.schemaVersion) return;
        if (JsonSchemaValidationRegexes.relativeJsonPointer.firstMatch(instance.data) == null) {
          _err('"relative-json-pointer" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'regex':
        // regex is an allowed format in draft3, out in draft4/6, back in draft7.
        // Since we don't support draft3, just draft7 is needed here.
        if (SchemaVersion.draft7 != schema.schemaVersion) return;
        try {
          RegExp(instance.data, unicode: true);
        } catch (e) {
          _err('"regex" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'duration':
        if (SchemaVersion.draft2019_09.compareTo(schema.schemaVersion) > 0) return;
        if (JsonSchemaValidationRegexes.duration.firstMatch(instance.data) == null) {
          _err('"duration" format not accepted $instance', instance.path, schema.path);
        }
        break;
      case 'uuid':
        if (SchemaVersion.draft2019_09.compareTo(schema.schemaVersion) > 0) return;
        if (JsonSchemaValidationRegexes.uuid.firstMatch(instance.data) == null) {
          _err('"uuid" format not accepted $instance', instance.path, schema.path);
        }
        break;
      default:
        // Don't attempt to validate unknown formats.
        break;
    }
  }

  void _objectPropertyValidation(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.APPLICATOR)) return;
    final propMustValidate = schema.additionalPropertiesBool != null && !schema.additionalPropertiesBool;

    instance.data.forEach((k, v) {
      // Validate property names against the provided schema, if any.
      if (schema.propertyNamesSchema != null) {
        _validate(schema.propertyNamesSchema, k);
      }

      final newInstance = Instance(v, path: '${instance.path}/$k');

      bool propCovered = false;
      final JsonSchema propSchema = schema.properties[k];
      if (propSchema != null) {
        assert(propSchema != null);
        _validate(propSchema, newInstance);
        propCovered = true;
      }

      schema.patternProperties.forEach((regex, patternSchema) {
        if (regex.hasMatch(k)) {
          assert(patternSchema != null);
          _validate(patternSchema, newInstance);
          propCovered = true;
        }
      });

      if (!propCovered) {
        if (schema.additionalPropertiesSchema != null) {
          _validate(schema.additionalPropertiesSchema, newInstance);
        } else if (propMustValidate) {
          _err('unallowed additional property $k', instance.path, schema.path + '/additionalProperties');
        }
      }
    });
  }

  void _propertyDependenciesValidation(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.APPLICATOR)) return;
    schema.propertyDependencies.forEach((k, dependencies) {
      if (instance.data.containsKey(k)) {
        if (!dependencies.every((prop) => instance.data.containsKey(prop))) {
          _err('prop $k => $dependencies required', instance.path, schema.path + '/dependencies');
        }
      }
    });
  }

  void _schemaDependenciesValidation(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.APPLICATOR)) return;

    schema.schemaDependencies.forEach((k, otherSchema) {
      if (instance.data.containsKey(k)) {
        if (Validator(otherSchema).validateWithResults(instance).errors.isNotEmpty) {
          _err('prop $k violated schema dependency', instance.path, otherSchema.path);
        }
      }
    });
  }

  void _objectValidation(JsonSchema schema, Instance instance) {
    if (_vocabulary.contains(SupportedVocabularies.VALIDATION)) {
      // Min / Max Props
      final numProps = instance.data.length;
      final minProps = schema.minProperties;
      final maxProps = schema.maxProperties;
      if (numProps < minProps) {
        _err('minProperties violated (${numProps} < ${minProps})', instance.path, schema.path);
      } else if (maxProps != null && numProps > maxProps) {
        _err('maxProperties violated (${numProps} > ${maxProps})', instance.path, schema.path);
      }

      // Required Properties
      if (schema.requiredProperties != null) {
        schema.requiredProperties.forEach((prop) {
          if (!instance.data.containsKey(prop)) {
            // One error for the root object that contains the missing property.
            _err('required prop missing: ${prop} from $instance', instance.path, schema.path + '/required');
            // Another error for the property on the root object. (Allows consumers to identify errors for individual fields)
            _err(
                'required prop missing: ${prop} from $instance', '${instance.path}/${prop}', schema.path + '/required');
          }
        });
      }
    }

    _objectPropertyValidation(schema, instance);

    if (schema.propertyDependencies != null) _propertyDependenciesValidation(schema, instance);

    if (schema.schemaDependencies != null) _schemaDependenciesValidation(schema, instance);
  }

  void _validate(JsonSchema schema, dynamic instance) {
    if (instance is! Instance) {
      instance = Instance(instance);
    }

    /// If the [JsonSchema] being validated is a ref, pull the ref
    /// from the [refMap] instead.
    while (schema.ref != null || schema.recursiveRef != null) {
      var nextSchema = schema.resolvePath(schema.ref ?? schema.recursiveRef);
      if (schema.recursiveRef != null && nextSchema.recursiveAnchor == true) {
        schema = nextSchema.furthestRecursiveAnchorParent();
      } else if (schema.schemaVersion == SchemaVersion.draft2019_09 &&
          schema.schemaMap.length > 1 &&
          nextSchema.schemaBool == null) {
        schema.mixinForRef(nextSchema);
      } else {
        schema = nextSchema;
      }
    }

    if (schema.unevaluatedItems != null) {
      _pushEvaluatedItemsContext();
    }

    /// If the [JsonSchema] is a bool, always return this value.
    if (schema.schemaBool != null) {
      if (schema.schemaBool == false) {
        _err('schema is a boolean == false, this schema will never validate. Instance: $instance', instance.path,
            schema.path);
      }
      return;
    }

    _ifThenElseValidation(schema, instance);
    _typeValidation(schema, instance);
    _constValidation(schema, instance);
    _enumValidation(schema, instance);
    if (instance.data is List) _itemsValidation(schema, instance);
    if (instance.data is String) _stringValidation(schema, instance);
    if (instance.data is num) _numberValidation(schema, instance);
    if (schema.allOf.isNotEmpty) _validateAllOf(schema, instance);
    if (schema.anyOf.isNotEmpty) _validateAnyOf(schema, instance);
    if (schema.oneOf.isNotEmpty) _validateOneOf(schema, instance);
    if (schema.notSchema != null) _validateNot(schema, instance);
    if (instance.data is List) _validateUnevaluatedItems(schema, instance);
    if (schema.format != null) _validateFormat(schema, instance);
    if (instance.data is Map) _objectValidation(schema, instance);
    if (schema.deprecated == true) _validateDeprecated(schema, instance);

    if (schema.unevaluatedItems != null) {
      _popEvaluatedItemsContext();
    }
  }

  bool _ifThenElseValidation(JsonSchema schema, Instance instance) {
    if (!_vocabulary.contains(SupportedVocabularies.APPLICATOR)) return true;
    if (schema.ifSchema != null) {
      // Bail out early if no 'then' or 'else' schemas exist.
      if (schema.thenSchema == null && schema.elseSchema == null) return true;

      if (schema.ifSchema.validateWithResults(instance).errors.isEmpty) {
        // Bail out early if no "then" is specified.
        if (schema.thenSchema == null) return true;
        if (!_validateAndCaptureEvaluations(schema.thenSchema, instance)) {
          _err('${schema.path}/then: then violated ($instance, ${schema.thenSchema})', instance.path,
              schema.path + '/then');
        }
      } else {
        // Bail out early if no "else" is specified.
        if (schema.elseSchema == null) return true;
        if (!_validateAndCaptureEvaluations(schema.elseSchema, instance)) {
          _err('${schema.path}/else: else violated ($instance, ${schema.elseSchema})', instance.path,
              schema.path + '/else');
        }
      }
      // Return early since we recursively call _validate in these cases.
      return true;
    }
    return false;
  }

  //////
  // Helper functions to deal with evaluatedItems.
  //////
  _pushEvaluatedItemsContext() {
    _evaluatedItemsContext.add(0);
  }

  _popEvaluatedItemsContext() {
    if (_evaluatedItemsContext.isNotEmpty) {
      var last = _evaluatedItemsContext.removeLast();
      _setMaxEvaluatedItemCount(last);
    }
  }

  bool get _isInEvaluatedItemContext => _evaluatedItemsContext.isNotEmpty;

  _setEvaluatedItemCount(int count) {
    if (_evaluatedItemsContext.isNotEmpty) {
      _evaluatedItemsContext[_evaluatedItemsContext.length - 1] = count;
    }
  }

  _setMaxEvaluatedItemCount(int count) {
    if (_evaluatedItemsContext.isNotEmpty) {
      _evaluatedItemsContext[_evaluatedItemsContext.length - 1] = max(_evaluatedItemsContext.last, count);
    }
  }

  int get _evaluatedItemCount => _evaluatedItemsContext.lastOrNull;

  void _err(String msg, String instancePath, String schemaPath) {
    schemaPath = schemaPath.replaceFirst('#', '');
    _errors.add(ValidationError._(instancePath, schemaPath, msg));
    if (!_reportMultipleErrors) throw FormatException(msg);
  }

  void _warn(String msg, String instancePath, String schemaPath) {
    schemaPath = schemaPath.replaceFirst('#', '');
    _warnings.add(ValidationError._(instancePath, schemaPath, msg));
    if (!_reportMultipleErrors && _treatWarningsAsErrors) throw FormatException(msg);
  }

  JsonSchema _rootSchema;
  List<ValidationError> _errors = [];
  List<ValidationError> _warnings = [];
  bool _reportMultipleErrors;
}
