// This test suite verifies that creation of JsonSchema succeeds with valid inputs.

import 'dart:collection';

import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

void main() {
  group('create from maps', () {
    test('create with Map literal succeeds', () {
      final schema = JsonSchema.create({
        'properties': {
          'multiple': {'multipleOf': 2}
        }
      });
      final results = schema.validate({'multiple': 2})!;
      expect(results.errors.length, 0);
    });

    test('create with generic Map succeeds', () {
      final schema = JsonSchema.create(Map.from({
        'properties': {
          'multiple': {'multipleOf': 2}
        }
      }));
      final results = schema.validate({'multiple': 2})!;
      expect(results.errors.length, 0);
    });

    test('create with generic nested Map succeeds', () {
      final schema = JsonSchema.create({
        'properties': {
          'multiple': {'multipleOf': 2},
          'someKey': Map.from({
            'properties': {
              'multiple': {'multipleOf': 2},
            }
          }),
        },
      });
      final results = schema.validate({
        'multiple': 2,
        'someKey': {'multiple': 2},
      })!;
      expect(results.errors.length, 0);
    });

    test('create with typed Map succeeds', () {
      final schema = JsonSchema.create(LinkedHashMap<String, dynamic>.from({
        'properties': {
          'multiple': {'multipleOf': 2}
        }
      }));
      final results = schema.validate({'multiple': 2})!;
      expect(results.errors.length, 0);
    });

    test('create with Unmodifiable Map succeeds', () {
      final schema = JsonSchema.create(Map.unmodifiable({
        'properties': {
          'multiple': {'multipleOf': 2}
        }
      }));
      final results = schema.validate({'multiple': 2})!;
      expect(results.errors.length, 0);
    });
  });
}
