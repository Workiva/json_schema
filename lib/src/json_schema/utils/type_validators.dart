import 'package:collection/collection.dart';
import 'package:json_schema/src/json_schema/utils/format_exceptions.dart';
import 'package:json_schema/src/json_schema/formats/validation_regexes.dart';
import 'package:json_schema/src/json_schema/models/schema_type.dart';
import 'package:json_schema/src/json_schema/models/schema_version.dart';

class TypeValidators {
  static List list(String key, Object? value) {
    if (value is List) return value;
    throw FormatExceptions.list(key, value);
  }

  static List nonEmptyList(String key, Object? value) {
    final List theList = list(key, value);
    if (theList.isNotEmpty) return theList;
    throw FormatExceptions.error('$key must be a non-empty list: $value');
  }

  static List uniqueList(String key, Object? value) {
    int i = 0;
    final List enumValues = TypeValidators.nonEmptyList(key, value);
    enumValues.forEach((v) {
      for (int j = i + 1; j < enumValues.length; j++) {
        if (DeepCollectionEquality().equals(enumValues[i], enumValues[j]))
          throw FormatExceptions.error('enum values must be unique: $value [$i]==[$j]');
      }
      i++;
    });
    return enumValues;
  }

  /// Validate a dynamic value is a String.
  static String string(String key, Object? value) {
    if (value is String) return value;
    throw FormatExceptions.string(key, value);
  }

  static String nonEmptyString(String key, Object? value) {
    var stringValue = TypeValidators.string(key, value);
    if (stringValue.isNotEmpty) return stringValue;
    throw FormatExceptions.error('$key must be a non-empty string: $value');
  }

  static List<SchemaType?> typeList(String key, Object? value) {
    var typeList;
    if (value is String) {
      typeList = [SchemaType.fromString(value)];
    } else if (value is List) {
      typeList = value.map((v) => SchemaType.fromString(v)).toList();
    } else {
      throw FormatExceptions.error('$key must be string or array: ${value.runtimeType}');
    }
    if (!typeList.contains(null)) return typeList;
    throw FormatExceptions.error('$key(s) invalid $value');
  }

  static int nonNegative(String key, int value) {
    if (value < 0) throw FormatExceptions.error('$key must be non-negative: $value');
    return value;
  }

  static int nonNegativeInt(String key, Object? value) {
    if (value is int) return nonNegative(key, value);
    throw FormatExceptions.int(key, value);
  }

  static num number(String key, Object? value) {
    if (value is num) return value;
    throw FormatExceptions.num(key, value);
  }

  static num nonNegativeNum(String key, Object? value) {
    var numberValue = number(key, value);
    if (numberValue > 0) return numberValue;
    throw FormatExceptions.nonNegativeNum(key, value);
  }

  static bool boolean(String key, Object? value) {
    if (value is bool) return value;
    throw FormatExceptions.bool(key, value);
  }

  static Map object(String key, Object? value) {
    if (value is Map) return value;
    throw FormatExceptions.object(key, value);
  }

  static SchemaVersion builtInSchemaVersion(String key, Object? value) {
    string(key, value);
    final schemaVersion = SchemaVersion.fromString(value as String?);
    if (schemaVersion != null) {
      return schemaVersion;
    }
    throw FormatExceptions.error(
        'Only draft 4, draft 6, draft 7, draft 2019-09, draft 2020-12, and custom schemas supported');
  }

  static Uri uri(String key, Object? value) {
    final String id = string('id', value);
    try {
      return Uri.parse(id);
    } catch (e) {
      throw FormatExceptions.error('$key must be a valid URI: $value ($e)');
    }
  }

  static String anchorString(String key, Object? value) {
    final String id = string(key, value);
    if (JsonSchemaValidationRegexes.anchor.hasMatch(id)) {
      return id;
    }
    throw FormatExceptions.error(
        "$key must start with a letter ([A-Za-z]), followed by any number of letters, digits ([0-9]), hyphens (\"-\"), underscores (\"_\"), colons (\":\"), or periods (\".\"): $value");
  }
}
