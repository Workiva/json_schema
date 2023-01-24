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

import 'dart:math';

import 'package:json_schema2/json_schema2.dart';
import 'package:yaon/yaon.dart' as yaon;

class Instance {
  Instance(dynamic data, {String path = ''}) {
    this.data = data;
    this.path = path;
  }

  dynamic data;
  String? path;

  @override
  String toString() => data.toString();
}

class ValidationError {
  ValidationError._(this.instancePath, this.schemaPath, this.message);

  /// Path in the instance data to the key where this error occurred
  String? instancePath;

  /// Path to the key in the schema containing the rule that produced this error
  String schemaPath;

  /// A human-readable message explaining why validation failed
  String message;

  @override
  String toString() =>
      '${instancePath!.isEmpty ? '# (root)' : instancePath}: $message';
}

/// Initialized with schema, validates instances against it
class Validator {
  Validator(this._rootSchema);

  final JsonSchema? _rootSchema;
  List<ValidationError> _errors = [];
  late bool _reportMultipleErrors;

  List<String> get errors => _errors.map((e) => e.toString()).toList();

  List<ValidationError> get errorObjects => _errors;

  /// Validate the [instance] against the this validator's schema
  bool validate(dynamic instance,
      {bool reportMultipleErrors = false, bool parseJson = false}) {
    // _logger.info('Validating ${instance.runtimeType}:$instance on ${_rootSchema}'); TODO: re-add logger

    dynamic data = instance;
    if (parseJson && instance is String) {
      try {
        data = yaon.parse(instance);
      } catch (e) {
        throw ArgumentError(
            'JSON instance provided to validate is not valid JSON.');
      }
    }

    _reportMultipleErrors = reportMultipleErrors;
    _errors = [];
    if (!_reportMultipleErrors) {
      try {
        _validate(_rootSchema!, data);
        return true;
      } on FormatException {
        return false;
      } catch (e) {
        // _logger.shout('Unexpected Exception: $e'); TODO: re-add logger
        return false;
      }
    }

    _validate(_rootSchema!, data);
    return _errors.isEmpty == true;
  }

  static bool _typeMatch(
      SchemaType? type, JsonSchema schema, dynamic instance) {
    switch (type) {
      case SchemaType.object:
        return instance is Map;
      case SchemaType.string:
        return instance is String;
      case SchemaType.integer:
        return instance is int ||
            (schema.schemaVersion == SchemaVersion.draft6 &&
                instance is num &&
                instance.remainder(1) == 0);
      case SchemaType.number:
        return instance is num;
      case SchemaType.array:
        return instance is List;
      case SchemaType.boolean:
        return instance is bool;
      case SchemaType.nullValue:
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
            instance.path, schema.path!);
      }
    } else if (maximum != null) {
      if (n! > maximum) {
        _err('maximum exceeded ($n > $maximum)', instance.path, schema.path!);
      }
    }

    if (exclusiveMinimum != null) {
      if (n! <= exclusiveMinimum) {
        _err('exclusiveMinimum violated ($n <= $exclusiveMinimum)',
            instance.path, schema.path!);
      }
    } else if (minimum != null) {
      if (n! < minimum) {
        _err('minimum violated ($n < $minimum)', instance.path, schema.path!);
      }
    }

    final multipleOf = schema.multipleOf;
    if (multipleOf != null) {
      if (multipleOf is int && n is int) {
        if (0 != n % multipleOf) {
          _err(
            'multipleOf violated ($n % $multipleOf)',
            instance.path,
            schema.path!,
          );
        }
      } else {
        final result = n! / multipleOf;
        if (result.truncate() != result) {
          _err(
            'multipleOf violated ($n % $multipleOf)',
            instance.path,
            schema.path!,
          );
        }
      }
    }
  }

  void _typeValidation(JsonSchema schema, dynamic instance) {
    final typeList = schema.typeList;
    if (typeList?.isNotEmpty == true) {
      if (!typeList!.any((type) => _typeMatch(type, schema, instance.data))) {
        _err(
          'type: wanted ${typeList} got $instance',
          instance.path,
          schema.path!,
        );
      }
    }
  }

  void _constValidation(JsonSchema schema, dynamic instance) {
    if (schema.hasConst &&
        !JsonSchemaUtils.jsonEqual(instance.data, schema.constValue)) {
      _err('const violated ${instance}', instance.path, schema.path!);
    }
  }

  void _enumValidation(JsonSchema schema, dynamic instance) {
    final enumValues = schema.enumValues;
    if (enumValues?.isNotEmpty == true) {
      try {
        enumValues!
            .singleWhere((v) => JsonSchemaUtils.jsonEqual(instance.data, v));
      } on StateError {
        _err('enum violated ${instance}', instance.path, schema.path!);
      }
    }
  }

  void _stringValidation(JsonSchema schema, Instance instance) {
    final actual = instance.data.runes.length;
    final minLength = schema.minLength;
    final maxLength = schema.maxLength;
    if (maxLength is int && actual > maxLength) {
      _err(
        'maxLength exceeded ($instance vs $maxLength)',
        instance.path,
        schema.path!,
      );
    } else if (minLength is int && actual < minLength) {
      _err(
        'minLength violated ($instance vs $minLength)',
        instance.path,
        schema.path!,
      );
    }
    final pattern = schema.pattern;
    if (pattern != null && instance.data != pattern.stringMatch(instance.data)) {
      _err(
        'pattern violated ($instance vs $pattern)',
        instance.path,
        schema.path!,
      );
    }
  }

  void _itemsValidation(JsonSchema schema, Instance instance) {
    final int? actual = instance.data.length;

    final singleSchema = schema.items;
    if (singleSchema != null) {
      instance.data.asMap().forEach((index, item) {
        final itemInstance = Instance(item, path: '${instance.path}/$index');
        _validate(singleSchema, itemInstance);
      });
    } else {
      final items = schema.itemsList;

      if (items != null) {
        final expected = items.length;
        final end = min(expected, actual!);
        for (var i = 0; i < end; i++) {
          final itemInstance =
              Instance(instance.data[i], path: '${instance.path}/$i');
          _validate(items[i], itemInstance);
        }
        if (schema.additionalItemsSchema != null) {
          for (var i = end; i < actual; i++) {
            final itemInstance =
                Instance(instance.data[i], path: '${instance.path}/$i');
            _validate(schema.additionalItemsSchema!, itemInstance);
          }
        } else if (schema.additionalItemsBool != null) {
          if (!schema.additionalItemsBool! && actual > end) {
            _err(
              'additionalItems false',
              instance.path,
              '${schema.path}/additionalItems',
            );
          }
        }
      }
    }

    final maxItems = schema.maxItems;
    final minItems = schema.minItems;
    if (maxItems is int && actual! > maxItems) {
      _err('maxItems exceeded ($actual vs $maxItems)', instance.path,
          schema.path!);
    } else if (schema.minItems is int && actual! < schema.minItems!) {
      _err(
        'minItems violated ($actual vs $minItems)',
        instance.path,
        schema.path!,
      );
    }

    if (schema.uniqueItems) {
      final end = instance.data.length;
      final penultimate = end - 1;
      for (var i = 0; i < penultimate; i++) {
        for (var j = i + 1; j < end; j++) {
          if (JsonSchemaUtils.jsonEqual(instance.data[i], instance.data[j])) {
            _err(
              'uniqueItems violated: $instance [$i]==[$j]',
              instance.path,
              schema.path!,
            );
          }
        }
      }
    }

    if (schema.contains != null) {
      if (!instance.data
          .any((item) => Validator(schema.contains).validate(item))) {
        _err(
          'contains violated: $instance',
          instance.path,
          schema.path!,
        );
      }
    }
  }

  void _validateAllOf(JsonSchema schema, Instance instance) {
    if (!schema.allOf.every((s) => Validator(s).validate(instance))) {
      _err(
        '${schema.path}: allOf violated ${instance}',
        instance.path,
        '${schema.path}/allOf',
      );
    }
  }

  void _validateAnyOf(JsonSchema schema, Instance instance) {
    if (!schema.anyOf.any((s) => Validator(s).validate(instance))) {
      // TODO: deal with /anyOf
      _err(
        '${schema.path}/anyOf: anyOf violated ($instance, ${schema.anyOf})',
        instance.path,
        '${schema.path}/anyOf',
      );
    }
  }

  void _validateOneOf(JsonSchema schema, Instance instance) {
    try {
      schema.oneOf.singleWhere((s) => Validator(s).validate(instance));
    } on StateError catch (notOneOf) {
      // TODO: deal with oneOf
      _err(
        '${schema.path}/oneOf: violated ${notOneOf.message}',
        instance.path,
        '${schema.path}/oneOf',
      );
    }
  }

  void _validateNot(JsonSchema schema, Instance instance) {
    if (Validator(schema.notSchema).validate(instance)) {
      // TODO: deal with .notSchema
      _err(
        '${schema.notSchema!.path}: not violated',
        instance.path,
        schema.notSchema!.path!,
      );
    }
  }

  void _validateFormat(JsonSchema schema, Instance instance) {
    if (instance.data is! String) {
      _err(
        '${instance.data} is type ${instance.data.runtimeType}; only inputs '
        'of type String are accepted for format operations.',
        instance.path,
        schema.path!,
      );
      return;
    }

    switch (schema.format) {
      case 'date-time':
        {
          try {
            DateTime.parse(instance.data);
          } catch (e) {
            _err(
              '"date-time" format not accepted $instance',
              instance.path,
              schema.path!,
            );
          }
        }
        break;
      case 'uri':
        {
          final isValid =
              defaultValidators.uriValidator as bool Function(String?)? ??
                  (_) => false;

          if (!isValid(instance.data)) {
            _err(
              '"uri" format not accepted $instance',
              instance.path,
              schema.path!,
            );
          }
        }
        break;
      case 'uri-reference':
        {
          if (schema.schemaVersion != SchemaVersion.draft6) {
            // TODO: deal with schema.format
            _err(
              '${schema.format} not supported as format before draft6',
              instance.path,
              schema.path!,
            );
          }
          final isValid = defaultValidators.uriReferenceValidator as bool
                  Function(String?)? ??
              (_) => false;

          if (!isValid(instance.data)) {
            _err(
              '"uri-reference" format not accepted $instance',
              instance.path,
              schema.path!,
            );
          }
        }
        break;
      case 'uri-template':
        {
          if (schema.schemaVersion != SchemaVersion.draft6) {
            _err(
              '${schema.format} not supported as format before draft6',
              instance.path,
              schema.path!,
            );
          }
          final isValid = defaultValidators.uriTemplateValidator as bool
                  Function(String?)? ??
              (_) => false;

          if (!isValid(instance.data)) {
            _err(
              '"uri-template" format not accepted $instance',
              instance.path,
              schema.path!,
            );
          }
        }
        break;
      case 'email':
        {
          final isValid =
              defaultValidators.emailValidator as bool Function(String?)? ??
                  (_) => false;

          if (!isValid(instance.data)) {
            _err(
              '"email" format not accepted $instance',
              instance.path,
              schema.path!,
            );
          }
        }
        break;
      case 'ipv4':
        {
          if (JsonSchemaValidationRegexes.ipv4.firstMatch(instance.data) ==
              null) {
            _err(
              '"ipv4" format not accepted $instance',
              instance.path,
              schema.path!,
            );
          }
        }
        break;
      case 'ipv6':
        {
          if (JsonSchemaValidationRegexes.ipv6.firstMatch(instance.data) ==
              null) {
            _err(
              'ipv6" format not accepted $instance',
              instance.path,
              schema.path!,
            );
          }
        }
        break;
      case 'hostname':
        {
          if (JsonSchemaValidationRegexes.hostname.firstMatch(instance.data) ==
              null) {
            _err(
              '"hostname" format not accepted $instance',
              instance.path,
              schema.path!,
            );
          }
        }
        break;
      case 'json-pointer':
        {
          if (schema.schemaVersion != SchemaVersion.draft6) {
            _err(
              '${schema.format} not supported as format before draft6',
              instance.path,
              schema.path!,
            );
          }
          if (JsonSchemaValidationRegexes.jsonPointer
                  .firstMatch(instance.data) ==
              null) {
            _err(
              'json-pointer" format not accepted $instance',
              instance.path,
              schema.path!,
            );
          }
        }
        break;
      default:
        {
          _err(
            '${schema.format} not supported as format',
            instance.path,
            schema.path!,
          );
        }
    }
  }

  void _objectPropertyValidation(JsonSchema schema, Instance instance) {
    final propMustValidate = schema.additionalPropertiesBool != null &&
        !schema.additionalPropertiesBool!;

    instance.data.forEach((k, v) {
      // Validate property names against the provided schema, if any.
      if (schema.propertyNamesSchema != null) {
        _validate(schema.propertyNamesSchema!, k);
      }

      final newInstance = Instance(v, path: '${instance.path}/$k');

      var propCovered = false;
      final propSchema = schema.properties[k];
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

      if (!propCovered) {
        if (schema.additionalPropertiesSchema != null) {
          _validate(schema.additionalPropertiesSchema!, newInstance);
        } else if (propMustValidate) {
          _err('unallowed additional property $k', instance.path,
              '${schema.path}/additionalProperties');
        }
      }
    });
  }

  void _propertyDependenciesValidation(JsonSchema schema, Instance instance) {
    schema.propertyDependencies?.forEach((k, dependencies) {
      if (instance.data.containsKey(k)) {
        if (!dependencies.every((prop) => instance.data.containsKey(prop))) {
          _err('prop $k => $dependencies required', instance.path,
              '${schema.path}/dependencies');
        }
      }
    });
  }

  void _schemaDependenciesValidation(JsonSchema schema, Instance instance) {
    schema.schemaDependencies?.forEach((k, otherSchema) {
      if (instance.data.containsKey(k)) {
        if (!Validator(otherSchema).validate(instance)) {
          _err('prop $k violated schema dependency', instance.path,
              otherSchema.path!);
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
      _err('minProperties violated (${numProps} < ${minProps})', instance.path,
          schema.path!);
    } else if (maxProps != null && numProps > maxProps) {
      _err('maxProperties violated (${numProps} > ${maxProps})', instance.path,
          schema.path!);
    }

    // Required Properties
    if (schema.requiredProperties != null) {
      schema.requiredProperties!.forEach((prop) {
        if (!instance.data.containsKey(prop)) {
          _err('required prop missing: ${prop} from $instance', instance.path,
              '${schema.path}/required');
        }
      });
    }

    _objectPropertyValidation(schema, instance);

    if (schema.propertyDependencies != null) {
      _propertyDependenciesValidation(schema, instance);
    }

    if (schema.schemaDependencies != null) {
      _schemaDependenciesValidation(schema, instance);
    }
  }

  void _validate(JsonSchema schema, dynamic instance) {
    if (instance is! Instance) {
      instance = Instance(instance);
    }

    /// If the [JsonSchema] is a bool, always return this value.
    if (schema.schemaBool != null) {
      if (schema.schemaBool == false) {
        _err(
          'schema is a boolean == false, this schema will never validate. Instance: $instance',
          instance.path,
          schema.path!,
        );
      }
      return;
    }

    /// If the [JsonSchema] being validated is a ref, pull the ref
    /// from the [refMap] instead.
    if (schema.ref != null) {
      final path = schema.root!.endPath(schema.ref.toString());
      schema = schema.root!.refMap![path]!;
    }
    _typeValidation(schema, instance);
    _constValidation(schema, instance);
    _enumValidation(schema, instance);
    if (instance.data is List) _itemsValidation(schema, instance);
    if (instance.data is String) _stringValidation(schema, instance);
    if (instance.data is num) _numberValidation(schema, instance);
    if (schema.allOf.isNotEmpty == true) _validateAllOf(schema, instance);
    if (schema.anyOf.isNotEmpty == true) _validateAnyOf(schema, instance);
    if (schema.oneOf.isNotEmpty == true) _validateOneOf(schema, instance);
    if (schema.notSchema != null) _validateNot(schema, instance);
    if (schema.format != null) _validateFormat(schema, instance);
    if (instance.data is Map) _objectValidation(schema, instance);
  }

  void _err(String msg, String? instancePath, String schemaPath) {
    schemaPath = schemaPath.replaceFirst('#', '');
    _errors.add(ValidationError._(instancePath, schemaPath, msg));
    if (!_reportMultipleErrors) throw FormatException(msg);
  }
}
