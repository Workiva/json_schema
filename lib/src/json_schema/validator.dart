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

import 'dart:convert';
import 'dart:core';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:json_schema/src/json_schema/formats/validators.dart';
import 'package:json_schema/src/json_schema/models/concrete_validation_context.dart';
import 'package:json_schema/src/json_schema/models/instance.dart';
import 'package:json_schema/src/json_schema/models/instance_ref_pair.dart';
import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/validation_results.dart';
import 'package:logging/logging.dart';

import 'package:json_schema/src/json_schema/json_schema.dart';
import 'package:json_schema/src/json_schema/models/schema_type.dart';

final Logger _logger = Logger('Validator');

class ValidationError {
  ValidationError._(this.instancePath, this.schemaPath, this.message,
      {this.customMessage});

  /// Path in the instance data to the key where this error occurred
  String? instancePath;

  /// Path to the key in the schema containing the rule that produced this error
  String? schemaPath;

  /// A custom error message
  Map<dynamic, dynamic>? customMessage;

  /// A human-readable message explaining why validation failed
  String message;

  @override
  toString() =>
      '${instancePath!.isEmpty ? '# (root)' : instancePath}: $message';
}

/// Initialized with schema, validates instances against it
class Validator {
  Validator(this._rootSchema);

  /// A private constructor for recursive validations.
  /// [inEvaluatedItemsContext] and [inEvaluatedPropertiesContext] are used to pass in the parents context state.
  Validator._(this._rootSchema,
      {List<bool>? inEvaluatedItemsContext,
      bool inEvaluatedPropertiesContext = false,
      Map<JsonSchema, JsonSchema>? initialDynamicParents}) {
    if (inEvaluatedItemsContext != null) {
      _pushEvaluatedItemsContext(inEvaluatedItemsContext.length);
    }
    if (inEvaluatedPropertiesContext) {
      _pushEvaluatedPropertiesContext();
    }
    if (initialDynamicParents != null) {
      _dynamicParents.addAll(initialDynamicParents);
    }
  }

  late bool _validateFormats;

  /// Keep track of the number of evaluated items contexts in a list, treating the list as a stack.
  /// The context is an [List] of [bool], representing the number of successful evaluations for the list in the
  /// given context.
  final List<List<bool>> _evaluatedItemsContext = [];

  /// Keep track of the evaluated properties contexts in a list, treating the list as a stack.
  /// The context is a [Set] of [Instance], keeping track of the instances that have been evaluated
  /// in a given context.
  final List<Set<Instance>> _evaluatedPropertiesContext = [];

  /// Lexical and dynamic scopes align until a reference keyword is encountered.
  /// While following the reference keyword moves processing from one lexical scope into a different one,
  /// from the perspective of dynamic scope, following reference is no different from descending into a
  /// subschema present as a value. A keyword on the far side of that reference that resolves information
  /// through the dynamic scope will consider the originating side of the reference to be their dynamic parent,
  /// rather than examining the local lexically enclosing parent.
  ///
  /// https://json-schema.org/draft/2019-09/json-schema-core.html#rfc.section.7.1
  ///
  /// This Map keeps track of schemas when a reference is resolved.
  final Map<JsonSchema, JsonSchema> _dynamicParents = {};

  final Set<InstanceRefPair> _refsEncountered = {};

  get _evaluatedProperties => _evaluatedPropertiesContext.isNotEmpty
      ? _evaluatedPropertiesContext.last
      : <Instance>{};

  @Deprecated('4.0, to be removed in 5.0, use validate() instead.')
  ValidationResults? validateWithResults(dynamic instance,
          {bool reportMultipleErrors = false,
          bool parseJson = false,
          bool? validateFormats}) =>
      validate(
        instance,
        reportMultipleErrors: reportMultipleErrors,
        parseJson: parseJson,
        validateFormats: validateFormats,
      );

  /// Validate the [instance] against the `Validator`'s `JsonSchema`
  ValidationResults validate(
    dynamic instance, {
    bool reportMultipleErrors = false,
    bool parseJson = false,
    bool? validateFormats,
  }) {
    final rootSchema = _rootSchema;
    if (rootSchema == null) {
      throw ArgumentError();
    }
    // Reference: https://json-schema.org/draft/2019-09/release-notes.html#format-vocabulary
    // By default, formats are validated on a best-effort basis from draft4 through draft7.
    // Starting with Draft 2019-09, formats shouldn't be validated by default.
    _validateFormats =
        validateFormats ?? rootSchema.schemaVersion <= SchemaVersion.draft7;

    dynamic data = instance;
    if (parseJson && instance is String) {
      try {
        data = json.decode(instance);
      } catch (e) {
        throw ArgumentError(
            'JSON instance provided to validate is not valid JSON.');
      }
    }

    _reportMultipleErrors = reportMultipleErrors;
    _errors = [];
    if (!_reportMultipleErrors) {
      try {
        _validate(rootSchema, data);
        return ValidationResults(_errors, _warnings);
      } on FormatException {
        return ValidationResults(_errors, _warnings);
      } on Exception catch (e) {
        _logger.shout('Unexpected Exception: $e');
        rethrow;
      }
    }

    _validate(rootSchema, data);
    return ValidationResults(_errors, _warnings);
  }

  static bool _typeMatch(
      SchemaType? type, JsonSchema schema, dynamic instance) {
    if (type == SchemaType.object) {
      return instance is Map;
    } else if (type == SchemaType.string) {
      return instance is String;
    } else if (type == SchemaType.integer) {
      return instance is int ||
          (schema.schemaVersion >= SchemaVersion.draft6 &&
              instance is num &&
              instance.remainder(1) == 0);
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
    final num? n = instance.data;
    final maximum = schema.maximum;
    final minimum = schema.minimum;
    final exclusiveMaximum = schema.exclusiveMaximum;
    final exclusiveMinimum = schema.exclusiveMinimum;

    if (exclusiveMaximum != null) {
      if (n! >= exclusiveMaximum) {
        _err('exclusiveMaximum exceeded ($n >= $exclusiveMaximum)',
            instance.path, schema.path!,
            customMessage: {
              ...?schema.customMessage?['numberValidation_exclusiveMaximum'],
              ...?schema.customMessage?['general_message'],
            });
      }
    } else if (maximum != null) {
      if (n! > maximum) {
        _err('maximum exceeded ($n > $maximum)', instance.path, schema.path!,
            customMessage: {
              ...?schema.customMessage?['numberValidation_maximum'],
              ...?schema.customMessage?['general_message'],
            });
      }
    }

    if (exclusiveMinimum != null) {
      if (n! <= exclusiveMinimum) {
        _err('exclusiveMinimum violated ($n <= $exclusiveMinimum)',
            instance.path, schema.path!,
            customMessage: {
              ...?schema.customMessage?['numberValidation_exclusiveMinimum'],
              ...?schema.customMessage?['general_message'],
            });
      }
    } else if (minimum != null) {
      if (n! < minimum) {
        _err('minimum violated ($n < $minimum)', instance.path, schema.path!,
            customMessage: {
              ...?schema.customMessage?['numberValidation_minimum'],
              ...?schema.customMessage?['general_message'],
            });
      }
    }

    final multipleOf = schema.multipleOf;
    if (multipleOf != null) {
      if (multipleOf is int && n is int) {
        if (0 != n % multipleOf) {
          _err('multipleOf violated ($n % $multipleOf)', instance.path,
              schema.path!,
              customMessage: {
                ...?schema.customMessage?['numberValidation_multipleOf'],
                ...?schema.customMessage?['general_message'],
              });
        }
      } else {
        final double result = n! / multipleOf;
        if (result == double.infinity) {
          _err('multipleOf violated ($n % $multipleOf)', instance.path,
              schema.path!,
              customMessage: {
                ...?schema.customMessage?['numberValidation_multipleOf'],
                ...?schema.customMessage?['general_message'],
              });
        } else if (result.truncate() != result) {
          _err('multipleOf violated ($n % $multipleOf)', instance.path,
              schema.path!,
              customMessage: {
                ...?schema.customMessage?['numberValidation_multipleOf'],
                ...?schema.customMessage?['general_message'],
              });
        }
      }
    }
  }

  void _typeValidation(JsonSchema schema, dynamic instance) {
    final typeList = schema.typeList;
    if (typeList != null && typeList.isNotEmpty) {
      if (!typeList.any((type) => _typeMatch(type, schema, instance.data))) {
        _err(
            'type: wanted $typeList got $instance', instance.path, schema.path!,
            customMessage: {
              ...?schema.customMessage?['typeValidation'],
              ...?schema.customMessage?['general_message'],
            });
      }
    }
  }

  void _constValidation(JsonSchema schema, dynamic instance) {
    if (schema.hasConst &&
        !DeepCollectionEquality().equals(instance.data, schema.constValue)) {
      _err(
        'const violated $instance',
        instance.path,
        schema.path!,
        customMessage: {
          ...?schema.customMessage?['constValidation'],
          ...?schema.customMessage?['general_message'],
        },
      );
    }
  }

  void _enumValidation(JsonSchema schema, dynamic instance) {
    final enumValues = schema.enumValues;
    if (enumValues?.isNotEmpty == true) {
      try {
        enumValues!.singleWhere(
            (v) => DeepCollectionEquality().equals(instance.data, v));
      } on StateError {
        _err('enum violated $instance', instance.path, schema.path!,
            customMessage: {
              ...?schema.customMessage?['enumValidation'],
              ...?schema.customMessage?['general_message'],
            });
      }
    }
  }

  void _validateDeprecated(JsonSchema schema, dynamic instance) {
    if (schema.deprecated == true) {
      _warn('deprecated $instance', instance.path, schema.path!);
    }
  }

  void _validateCustomSetAttributes(JsonSchema schema, Instance instance) {
    final context = ConcreteValidationContext(
        instance.path, schema.path!, _err, _warn, schema.schemaVersion);
    // ignore: deprecated_member_use_from_same_package
    schema.customAttributeValidators.forEach((keyword, validator) {
      // ignore: unused_local_variable
      final _ = validator(context, instance.data);
    });
  }

  void _stringValidation(JsonSchema schema, Instance instance) {
    final actual = instance.data.runes.length;
    final minLength = schema.minLength;
    final maxLength = schema.maxLength;
    if (maxLength is int && actual > maxLength) {
      _err('maxLength exceeded ($instance vs $maxLength)', instance.path,
          schema.path!,
          customMessage: {
            ...?schema.customMessage?['stringValidation_maxLength'],
            ...?schema.customMessage?['general_message'],
          });
    } else if (minLength is int && actual < minLength) {
      _err('minLength violated ($instance vs $minLength)', instance.path,
          schema.path!,
          customMessage: {
            ...?schema.customMessage?['stringValidation_minLength'],
            ...?schema.customMessage?['general_message'],
          });
    }
    final pattern = schema.pattern;
    if (pattern != null && !pattern.hasMatch(instance.data)) {
      _err('pattern violated ($instance vs $pattern)', instance.path,
          schema.path!,
          customMessage: {
            ...?schema.customMessage?['stringValidation_pattern'],
            ...?schema.customMessage?['general_message'],
          });
    }
  }

  void _itemsValidation2020(JsonSchema schema, Instance instance) {
    final int actual = instance.data.length;
    final int end = min(schema.prefixItems?.length ?? 0, actual);
    if (schema.prefixItems != null) {
      var items = schema.prefixItems;
      for (int i = 0; i < end; i++) {
        final itemInstance =
            Instance(instance.data[i], path: '${instance.path}/$i');
        _validate(items![i], itemInstance);
        _setItemAsEvaluated(i);
      }
    }

    if (schema.items != null) {
      for (int i = end; i < actual; i++) {
        final itemInstance =
            Instance(instance.data[i], path: '${instance.path}/$i');
        _validate(schema.items!, itemInstance);
        _setItemAsEvaluated(i);
      }
    }
  }

  void _itemsValidation(JsonSchema schema, Instance instance) {
    final int actual = instance.data.length;

    if (schema.schemaVersion >= SchemaVersion.draft2020_12) {
      _itemsValidation2020(schema, instance);
    } else {
      final singleSchema = schema.items;
      if (singleSchema != null) {
        instance.data.asMap().forEach((index, item) {
          final itemInstance = Instance(item, path: '${instance.path}/$index');
          _validate(singleSchema, itemInstance);
          _setItemAsEvaluated(index);
        });
      } else {
        final items = schema.itemsList;

        if (items != null) {
          final expected = items.length;
          final end = min(expected, actual);
          // All the items have been evaluated somewhere else, or they will be evaluated upto the end count.
          for (int i = 0; i < end; i++) {
            final schema = items[i];
            if (schema == null) {
              throw StateError("Undefined schema $schema encountered");
            }
            final itemInstance =
                Instance(instance.data[i], path: '${instance.path}/$i');
            _validate(schema, itemInstance);
            _setItemAsEvaluated(i);
          }
          final additionalItemsSchema = schema.additionalItemsSchema;
          final additionalItemsBool = schema.additionalItemsBool;
          if (additionalItemsSchema != null) {
            for (int i = end; i < actual; i++) {
              final itemInstance =
                  Instance(instance.data[i], path: '${instance.path}/$i');
              _validate(additionalItemsSchema, itemInstance);
            }
          } else if (additionalItemsBool != null) {
            if (!additionalItemsBool && actual > end) {
              _err('additionalItems false', instance.path,
                  '${schema.path!}/additionalItems',
                  customMessage: {
                    ...?schema
                        .customMessage?['itemsValidation_additionalItems'],
                    ...?schema.customMessage?['general_message'],
                  });
            } else {
              // All the items in this list have been evaluated.
              _setAllItemsAsEvaluated();
            }
          }
        }
      }
    }

    final maxItems = schema.maxItems;
    final minItems = schema.minItems;
    if (maxItems is int && actual > maxItems) {
      _err('maxItems exceeded ($actual vs $maxItems)', instance.path,
          schema.path!,
          customMessage: {
            ...?schema.customMessage?['itemsValidation_maxItems'],
            ...?schema.customMessage?['general_message'],
          });
    } else if (minItems is int && actual < minItems) {
      _err('minItems violated ($actual vs $minItems)', instance.path,
          schema.path!,
          customMessage: {
            ...?schema.customMessage?['itemsValidation_minItems'],
            ...?schema.customMessage?['general_message'],
          });
    }

    if (schema.uniqueItems) {
      final end = instance.data.length;
      final penultimate = end - 1;
      for (int i = 0; i < penultimate; i++) {
        for (int j = i + 1; j < end; j++) {
          if (DeepCollectionEquality()
              .equals(instance.data[i], instance.data[j])) {
            _err('uniqueItems violated: $instance [$i]==[$j]', instance.path,
                schema.path!,
                customMessage: {
                  ...?schema.customMessage?['itemsValidation_uniqueItems'],
                  ...?schema.customMessage?['general_message'],
                });
          }
        }
      }
    }

    if (schema.contains != null) {
      final maxContains = schema.maxContains;
      final minContains = schema.minContains;

      var containsItems = [];
      for (var i = 0; i < instance.data.length; i++) {
        var item = instance.data[i];
        final res =
            _validateAndCaptureEvaluations(schema.contains, Instance(item));
        if (res) {
          _setItemAsEvaluated(i);
          containsItems.add(item);
        }
      }
      if (minContains is int && containsItems.length < minContains) {
        _err('minContains violated: $instance', instance.path, schema.path!,
            customMessage: {
              ...?schema.customMessage?['itemsValidation_minContains'],
              ...?schema.customMessage?['general_message'],
            });
      }
      if (maxContains is int && containsItems.length > maxContains) {
        _err('maxContains violated: $instance', instance.path, schema.path!,
            customMessage: {
              ...?schema.customMessage?['itemsValidation_maxContains'],
              ...?schema.customMessage?['general_message'],
            });
      }
      if (containsItems.isEmpty && !(minContains is int && minContains == 0)) {
        _err('contains violated: $instance', instance.path, schema.path!,
            customMessage: {
              ...?schema.customMessage?['itemsValidation_contains'],
              ...?schema.customMessage?['general_message'],
            });
      }
    }
  }

  _validateUnevaluatedItems(JsonSchema schema, Instance instance) {
    final unevaluatedItems = schema.unevaluatedItems;
    if (unevaluatedItems != null && schema.additionalItemsBool is! bool) {
      final actual = instance.data.length;
      if (unevaluatedItems.schemaBool != null) {
        if (unevaluatedItems.schemaBool == false &&
            actual > _evaluatedItemCount) {
          _err('unevaluatedItems false', instance.path,
              '${schema.path!}/unevaluatedItems',
              customMessage: {
                ...?schema.customMessage?['validateUnevaluatedItems'],
                ...?schema.customMessage?['general_message'],
              });
        }
      } else {
        var evaluatedItemsList = _evaluatedItemsContext.last;
        for (int i = 0; i < evaluatedItemsList.length; i++) {
          if (evaluatedItemsList[i] == false) {
            final itemInstance =
                Instance(instance.data[i], path: '${instance.path}/$i');
            _validate(unevaluatedItems, itemInstance);
          }
        }
      }
      // If we passed these test, then all the items have been evaluated.
      _setAllItemsAsEvaluated();
    }
  }

  /// Helper function to capture the number of evaluatedItems and update the local count.
  bool _validateAndCaptureEvaluations(JsonSchema? s, Instance instance) {
    Validator v = Validator._(
      s,
      inEvaluatedItemsContext: _evaluatedItemsContext.lastOrNull,
      inEvaluatedPropertiesContext: _isInEvaluatedPropertiesContext,
      initialDynamicParents: _dynamicParents,
    );
    final isValid = v.validate(instance).isValid;
    if (isValid) {
      if (_isInEvaluatedItemContext) {
        _mergeEvaluatedItems(v._evaluatedItemsContext.lastOrNull);
      }
      if (_isInEvaluatedPropertiesContext) {
        v._evaluatedProperties.forEach((e) => _addEvaluatedProp(e));
      }
    }
    return isValid;
  }

  _validateAllOf(JsonSchema schema, Instance instance) {
    if (!schema.allOf
        .every((s) => _validateAndCaptureEvaluations(s, instance))) {
      _err('${schema.path}: allOf violated $instance', instance.path,
          '${schema.path!}/allOf',
          customMessage: {
            ...?schema.customMessage?['validateAllOf'],
            ...?schema.customMessage?['general_message'],
          });
    }
  }

  void _validateAnyOf(JsonSchema schema, Instance instance) {
    bool anyOfValid = false;
    if (!_isInEvaluatedItemsOrPropertiesContext) {
      anyOfValid =
          schema.anyOf.any((s) => _validateAndCaptureEvaluations(s, instance));
    } else {
      // `any` will short circuit on the first successful subschema. Each sub-schema needs to be evaluated
      // to properly account for evaluated properties and items.
      anyOfValid = schema.anyOf.fold(false, (previousValue, s) {
        final result = _validateAndCaptureEvaluations(s, instance);
        return previousValue || result;
      });
    }
    if (!anyOfValid) {
      // TODO: deal with /anyOf
      _err('${schema.path}/anyOf: anyOf violated ($instance, ${schema.anyOf})',
          instance.path, '${schema.path!}/anyOf',
          customMessage: {
            ...?schema.customMessage?['validateAnyOf'],
            ...?schema.customMessage?['general_message'],
          });
    }
  }

  void _validateOneOf(JsonSchema schema, Instance instance) {
    try {
      schema.oneOf
          .map((s) => _validateAndCaptureEvaluations(s, instance))
          .singleWhere((s) => s);
    } on StateError catch (notOneOf) {
      // TODO consider passing back validation errors from sub-validations
      _err('${schema.path}/oneOf: violated ${notOneOf.message}', instance.path,
          '${schema.path!}/oneOf');
    }
  }

  void _validateNot(JsonSchema schema, Instance instance) {
    if (Validator(schema.notSchema).validate(instance).isValid) {
      _err('${schema.notSchema?.path}: not violated', instance.path,
          schema.notSchema!.path!,
          customMessage: {
            ...?schema.customMessage?['validateNot'],
            ...?schema.customMessage?['general_message'],
          });
    }
  }

  void _validateFormat(JsonSchema schema, Instance instance) {
    if (!_validateFormats) return;

    // Non-strings in formats should be ignored.
    if (instance.data is! String) return;

    // ignore: deprecated_member_use_from_same_package
    final validator = schema.customFormats[schema.format] ??
        defaultFormatValidators[schema.format];

    if (validator == null) {
      // Don't attempt to validate unknown formats.
      return;
    }

    validator(
        ConcreteValidationContext(
            instance.path, schema.path!, _err, _warn, schema.schemaVersion),
        instance.data);
  }

  void _objectPropertyValidation(JsonSchema schema, Instance instance) {
    final propMustValidate = schema.additionalPropertiesBool != null &&
        !schema.additionalPropertiesBool!;

    instance.data.forEach((k, v) {
      // Validate property names against the provided schema, if any.
      final propertyNamesSchema = schema.propertyNamesSchema;
      if (propertyNamesSchema != null) {
        _validate(propertyNamesSchema, k);
      }

      final newInstance = Instance(v, path: '${instance.path}/$k');

      bool propCovered = false;
      final JsonSchema? propSchema = schema.properties[k];
      if (propSchema != null) {
        _validate(propSchema, newInstance);
        propCovered = true;
      }

      schema.patternProperties.forEach((regex, patternSchema) {
        if (regex.hasMatch(k)) {
          _validate(patternSchema, newInstance);
          propCovered = true;
        }
      });

      if (propCovered) {
        _addEvaluatedProp(newInstance);
      } else {
        final additionalPropertiesSchema = schema.additionalPropertiesSchema;
        if (additionalPropertiesSchema != null) {
          _validate(additionalPropertiesSchema, newInstance);
          _addEvaluatedProp(newInstance);
        } else if (propMustValidate) {
          _err('unallowed additional property $k', instance.path,
              '${schema.path!}/additionalProperties',
              customMessage: {
                ...?schema.customMessage?['objectPropertyValidation'],
                ...?schema.customMessage?['general_message'],
              });
        } else if (schema.additionalPropertiesBool == true) {
          _addEvaluatedProp(newInstance);
        }
      }
    });
  }

  void _propertyDependenciesValidation(JsonSchema schema, Instance instance) {
    schema.propertyDependencies.forEach((k, dependencies) {
      if (instance.data.containsKey(k)) {
        if (!dependencies.every((prop) => instance.data.containsKey(prop))) {
          _err('prop $k => $dependencies required', instance.path,
              '${schema.path!}/dependencies',
              customMessage: {
                ...?schema.customMessage?['propertyDependenciesValidation'],
                ...?schema.customMessage?['general_message'],
              });
        } else {
          _addEvaluatedProp(instance);
        }
      }
    });
  }

  void _schemaDependenciesValidation(JsonSchema schema, Instance instance) {
    schema.schemaDependencies.forEach((k, otherSchema) {
      if (instance.data.containsKey(k)) {
        if (!_validateAndCaptureEvaluations(otherSchema, instance)) {
          _err('prop $k violated schema dependency', instance.path,
              otherSchema.path!,
              customMessage: {
                ...?schema.customMessage?['schemaDependenciesValidation'],
                ...?schema.customMessage?['general_message'],
              });
        } else {
          _addEvaluatedProp(instance);
        }
      }
    });
  }

  void _objectValidation(JsonSchema schema, Instance instance) {
    // Min / Max Props
    final numProps = instance.data.length;
    final minProps = schema.minProperties;
    final maxProps = schema.maxProperties;
    if (numProps < minProps) {
      _err('minProperties violated ($numProps < $minProps)', instance.path,
          schema.path!,
          customMessage: {
            ...?schema.customMessage?['objectValidation_minProperties'],
            ...?schema.customMessage?['general_message'],
          });
    } else if (maxProps != null && numProps > maxProps) {
      _err('maxProperties violated ($numProps > $maxProps)', instance.path,
          schema.path!,
          customMessage: {
            ...?schema.customMessage?['objectValidation_maxProperties'],
            ...?schema.customMessage?['general_message'],
          });
    }

    // Required Properties
    if (schema.requiredProperties != null) {
      for (final prop in schema.requiredProperties!) {
        if (!instance.data.containsKey(prop)) {
          // One error for the root object that contains the missing property.
          _err('required prop missing: $prop from $instance', instance.path,
              '${schema.path!}/required',
              customMessage: {
                ...?schema
                    .customMessage?['objectValidation_requiredProperties_root'],
                ...?schema.customMessage?['general_message'],
              });
          // Another error for the property on the root object. (Allows consumers to identify errors for individual fields)
          _err('required prop missing: $prop from $instance',
              '${instance.path}/$prop', '${schema.path!}/required',
              customMessage: {
                ...?schema.customMessage?[
                    'objectValidation_requiredProperties_property'],
                ...?schema.customMessage?['general_message'],
              });
        }
      }
    }

    _objectPropertyValidation(schema, instance);

    _propertyDependenciesValidation(schema, instance);

    _schemaDependenciesValidation(schema, instance);

    final unevaluatedProperties = schema.unevaluatedProperties;
    if (unevaluatedProperties != null) {
      if (schema.unevaluatedProperties?.schemaBool == true) {
        instance.data.forEach((k, v) {
          var i = Instance(v, path: '${instance.path}/$k');
          _addEvaluatedProp(i);
        });
      } else {
        instance.data.forEach((k, v) {
          var i = Instance(v, path: '${instance.path}/$k');
          if (!_evaluatedProperties.contains(i)) {
            _validate(unevaluatedProperties, i);
          }
        });
      }
    }
  }

  /// Find the furthest away parent [JsonSchema] the that is a recursive anchor
  /// or null of there is no recursiveAnchor found.
  JsonSchema? _findAnchorParent(JsonSchema schema) {
    JsonSchema? lastFound = schema.recursiveAnchor ? schema : null;
    JsonSchema? possibleAnchor = _dynamicParents[schema] ?? schema.parent;
    while (possibleAnchor != null) {
      if (possibleAnchor.recursiveAnchor) {
        lastFound = possibleAnchor;
      }
      possibleAnchor = _dynamicParents[possibleAnchor] ?? possibleAnchor.parent;
    }
    return lastFound;
  }

  // Traverse up the dynamic path, starting at schema, for the furthest most dynamicAnchor.
  JsonSchema? _findDynamicAnchorParent(JsonSchema schema, String? anchorName) {
    if (anchorName == null) {
      return null;
    }
    JsonSchema? lastFound;
    JsonSchema? parent = schema;
    while (parent != null) {
      var nextCandidate = parent.resolveDynamicAnchor(anchorName);
      if (nextCandidate != null) {
        lastFound = nextCandidate;
      }
      parent = _dynamicParents[parent] ?? parent.parent;
    }
    return lastFound;
  }

  /// A helper function to deal with infinite loops at evaluation time.
  /// If we see the same data/ref pair twice, we're in a loop.
  void _withRefScope(Uri? refScope, Instance instance, Function() fn) {
    var irp = InstanceRefPair(instance.path, refScope);
    if (!_refsEncountered.add(irp)) {
      // Throw if cycle is detected while evaluating refs.
      throw FormatException('Cycle detected at path: "$refScope"');
    }
    fn();
    _refsEncountered.remove(irp);
  }

  void _validate(JsonSchema schema, dynamic instance) {
    if (instance is! Instance) {
      instance = Instance(instance);
    }

    if (schema.unevaluatedItems != null) {
      var length = instance.data is List ? instance.data.length : 0;
      _pushEvaluatedItemsContext(length);
    }
    if (schema.unevaluatedProperties != null) {
      _pushEvaluatedPropertiesContext();
    }

    /// If the [JsonSchema] being validated is a ref, pull the ref
    /// from the [refMap] instead.
    if (schema.ref != null) {
      _withRefScope(schema.ref, instance, () {
        JsonSchema nextSchema = schema.resolvePath(schema.ref);
        final prevParent = _setDynamicParent(nextSchema, schema);
        _validate(nextSchema, instance);
        _setDynamicParent(nextSchema, prevParent);
      });
      // We're not supposed to evaluate other properties in drafts before 2019.
      if (schema.schemaVersion < SchemaVersion.draft2019_09) {
        return;
      }
    }

    /// If the [JsonSchema] being validated is a recursiveRef, pull the ref
    /// from the [refMap] instead.
    if (schema.recursiveRef != null) {
      _withRefScope(schema.recursiveRef, instance, () {
        JsonSchema nextSchema = schema.resolvePath(schema.recursiveRef);
        if (nextSchema.recursiveAnchor == true) {
          nextSchema = _findAnchorParent(nextSchema) ?? nextSchema;
          _validate(nextSchema, instance);
        } else {
          final prevParent = _setDynamicParent(nextSchema, schema);
          _validate(nextSchema, instance);
          _setDynamicParent(nextSchema, prevParent);
        }
      });
      if (schema.schemaVersion < SchemaVersion.draft2019_09) {
        return;
      }
    }

    if (schema.dynamicRef != null) {
      _withRefScope(schema.recursiveRef, instance, () {
        JsonSchema nextSchema = schema.resolvePath(schema.dynamicRef);
        var anchorParent =
            _findDynamicAnchorParent(schema, nextSchema.dynamicAnchor);
        if (anchorParent != null) {
          _validate(anchorParent, instance);
        } else {
          _validate(nextSchema, instance);
        }
      });
    }

    /// If the [JsonSchema] is a bool, always return this value.
    if (schema.schemaBool != null) {
      if (schema.schemaBool == false) {
        _err(
            'schema is a boolean == false, this schema will never validate. Instance: $instance',
            instance.path,
            schema.path!,
            customMessage: {
              ...?schema.customMessage?['schemaBool_false'],
              ...?schema.customMessage?['general_message'],
            });
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
    // ignore: deprecated_member_use_from_same_package
    if (schema.customAttributeValidators.isNotEmpty) {
      _validateCustomSetAttributes(schema, instance);
    }

    if (schema.unevaluatedItems != null) {
      _popEvaluatedItemsContext();
    }
    if (schema.unevaluatedProperties != null) {
      _popEvaluatedPropertiesContext();
    }
  }

  bool _ifThenElseValidation(JsonSchema schema, Instance instance) {
    if (schema.ifSchema != null) {
      if (_validateAndCaptureEvaluations(schema.ifSchema, instance)) {
        // Bail out early if no "then" is specified.
        if (schema.thenSchema == null) return true;
        if (!_validateAndCaptureEvaluations(schema.thenSchema, instance)) {
          _err(
              '${schema.path}/then: then violated ($instance, ${schema.thenSchema})',
              instance.path,
              '${schema.path!}/then',
              customMessage: {
                ...?schema.customMessage?['ifThenElseValidation_then'],
                ...?schema.customMessage?['general_message'],
              });
        }
      } else {
        // Bail out early if no "else" is specified.
        if (schema.elseSchema == null) return true;
        if (!_validateAndCaptureEvaluations(schema.elseSchema, instance)) {
          _err(
              '${schema.path}/else: else violated ($instance, ${schema.elseSchema})',
              instance.path,
              '${schema.path!}/else',
              customMessage: {
                ...?schema.customMessage?['ifThenElseValidation_else'],
                ...?schema.customMessage?['general_message']
              });
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
  _pushEvaluatedItemsContext(int length) {
    _evaluatedItemsContext.add(List.filled(length, false));
  }

  _popEvaluatedItemsContext() {
    var last = _evaluatedItemsContext.removeLast();
    _mergeEvaluatedItems(last);
  }

  bool get _isInEvaluatedItemContext => _evaluatedItemsContext.isNotEmpty;

  bool get _isInEvaluatedItemsOrPropertiesContext =>
      _isInEvaluatedItemContext || _isInEvaluatedPropertiesContext;

  _setItemAsEvaluated(int position) {
    if (_isInEvaluatedItemContext) {
      _evaluatedItemsContext.last[position] = true;
    }
  }

  _setAllItemsAsEvaluated() {
    if (_isInEvaluatedItemContext) {
      for (var i = 0; i < _evaluatedItemsContext.last.length; i++) {
        _evaluatedItemsContext.last[i] = true;
      }
    }
  }

  _mergeEvaluatedItems(List<bool>? evaluatedItems) {
    if (_isInEvaluatedItemContext) {
      evaluatedItems?.forEachIndexed((index, element) {
        if (element) {
          _setItemAsEvaluated(index);
        }
      });
    }
  }

  int? get _evaluatedItemCount =>
      _evaluatedItemsContext.lastOrNull?.where((element) => element).length;

  //////
  // Helper functions to deal with unevaluatedProperties.
  //////

  _pushEvaluatedPropertiesContext() {
    _evaluatedPropertiesContext.add(<Instance>{});
  }

  _popEvaluatedPropertiesContext() {
    var last = _evaluatedPropertiesContext.removeLast();
    if (_evaluatedPropertiesContext.isNotEmpty) {
      _evaluatedPropertiesContext.last.addAll(last);
    }
  }

  bool get _isInEvaluatedPropertiesContext =>
      _evaluatedPropertiesContext.isNotEmpty;

  void _addEvaluatedProp(Instance i) {
    if (_evaluatedPropertiesContext.isNotEmpty) {
      var context = _evaluatedPropertiesContext.last;
      context.add(i);
    }
  }

  JsonSchema? _setDynamicParent(JsonSchema child, JsonSchema? dynamicParent) {
    final oldParent = _dynamicParents.remove(child);
    if (dynamicParent != null) {
      _dynamicParents[child] = dynamicParent;
    } else {
      _dynamicParents.remove(child);
    }
    return oldParent;
  }

  void _err(String msg, String? instancePath, String schemaPath,
      {Map<dynamic, dynamic>? customMessage}) {
    schemaPath = schemaPath.replaceFirst('#', '');
    _errors.add(ValidationError._(
      instancePath,
      schemaPath,
      msg,
      customMessage: customMessage,
    ));
    if (!_reportMultipleErrors) throw FormatException(msg);
  }

  void _warn(String msg, String? instancePath, String? schemaPath) {
    schemaPath = schemaPath?.replaceFirst('#', '');
    _warnings.add(ValidationError._(instancePath, schemaPath, msg));
  }

  final JsonSchema? _rootSchema;
  List<ValidationError> _errors = [];
  final List<ValidationError> _warnings = [];
  late bool _reportMultipleErrors;
}
