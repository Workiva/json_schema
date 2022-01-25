import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

main() {
  group('Nested \$refs in root schema', () {
    test('properties', () async {
      final barSchema = await JsonSchema.createAsync({
        "properties": {
          "foo": {"\$ref": "http://localhost:1234/integer.json#"},
          "bar": {"\$ref": "http://localhost:4321/string.json#"}
        },
        "required": ["foo", "bar"]
      });

      final isValid = barSchema.validateWithResults({"foo": 2, "bar": "test"}).errors.isEmpty;
      final isInvalid = barSchema.validateWithResults({"foo": 2, "bar": 4}).errors.isEmpty;

      expect(isValid, isTrue);
      expect(isInvalid, isFalse);
    });

    test('items', () async {
      final schema = await JsonSchema.createAsync({
        "items": {"\$ref": "http://localhost:1234/integer.json"}
      });

      final isValid = schema.validateWithResults([1, 2, 3, 4]).errors.isEmpty;
      final isInvalid = schema.validateWithResults([1, 2, 3, '4']).errors.isEmpty;

      expect(isValid, isTrue);
      expect(isInvalid, isFalse);
    });

    test('not / anyOf', () async {
      final schema = await JsonSchema.createAsync({
        "items": {
          "not": {
            "anyOf": [
              {"\$ref": "http://localhost:1234/integer.json#"},
              {"\$ref": "http://localhost:4321/string.json#"},
            ]
          }
        }
      });

      final isValid = schema.validateWithResults([3.4]).errors.isEmpty;
      final isInvalid = schema.validateWithResults(['test']).errors.isEmpty;

      expect(isValid, isTrue);
      expect(isInvalid, isFalse);
    });
  });

  test('Recursive refs from a remote schema should be supported with a json provider', () async {
    final RefProvider syncRefJsonProvider = RefProvider.sync((String ref) {
      switch (ref) {
        case 'http://localhost:1234/tree.json':
          return {
            "\$id": "http://localhost:1234/tree.json",
            "description": "tree of nodes",
            "type": "object",
            "properties": {
              "meta": {"type": "string"},
              "nodes": {
                "type": "array",
                "items": {"\$ref": "node.json"}
              }
            },
            "required": ["meta", "nodes"]
          };
        case 'http://localhost:1234/node.json':
          return {
            "\$id": "http://localhost:1234/node.json",
            "description": "nodes",
            "type": "object",
            "properties": {
              "value": {"type": "number"},
              "subtree": {"\$ref": "tree.json"}
            },
            "required": ["value"]
          };
        default:
          return null;
      }
    });

    final schema = JsonSchema.create(
      syncRefJsonProvider.provide('http://localhost:1234/tree.json'),
      refProvider: syncRefJsonProvider,
    );

    final isValid = schema
        .validateWithResults({
          "meta": "a string",
          "nodes": [
            {
              "value": 123,
              "subtree": {"meta": "a string", "nodes": []}
            }
          ]
        })
        .errors
        .isEmpty;

    final isInvalid = schema
        .validateWithResults({
          "meta": "a string",
          "nodes": [
            {
              "value": 123,
              "subtree": {
                "meta": "a string",
                "nodes": [
                  {
                    "value": 123,
                    "subtree": {"meta": 123, "nodes": []}
                  }
                ]
              }
            }
          ]
        })
        .errors
        .isEmpty;

    expect(isValid, isTrue);
    expect(isInvalid, isFalse);
  });
}
