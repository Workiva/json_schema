// This test suite verifies that validation errors report correct values for
// instance & schema paths.

import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

JsonSchema createObjectSchema(Map<String, dynamic> nestedSchema) {
  return JsonSchema.create({
    'properties': {'someKey': nestedSchema}
  });
}

void main() {
  group('ValidationError', () {
    test('boolean false at root', () {
      final schema = JsonSchema.create(false);
      final errors = schema.validate({'someKey': 1})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '');
      expect(errors[0].schemaPath, '');
      expect(errors[0].message, contains('boolean == false'));
    });

    test('boolean false in object', () {
      final schema = JsonSchema.create({
        'properties': {'someKey': false}
      });
      final errors = schema.validate({'someKey': 1})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('boolean == false'));
    });

    test('type', () {
      final schema = createObjectSchema({"type": "string"});
      final errors = schema.validate({'someKey': 1})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('type'));
    });

    test('const', () {
      final schema = createObjectSchema({'const': 'foo'});
      final errors = schema.validate({'someKey': 'bar'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('const'));
    });

    test('enum', () {
      final schema = createObjectSchema({
        'enum': [1, 2, 3]
      });
      final errors = schema.validate({'someKey': 4})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('enum'));
    });

    group('string', () {
      final schema = createObjectSchema({'minLength': 3, 'maxLength': 5, 'pattern': '^a.*\$'});

      test('minLength', () {
        final errors = schema.validate({'someKey': 'ab'})!.errors;

        expect(errors.length, 1);
        expect(errors[0].instancePath, '/someKey');
        expect(errors[0].schemaPath, '/properties/someKey');
        expect(errors[0].message, contains('minLength'));
      });

      test('maxLength', () {
        final errors = schema.validate({'someKey': 'abcdef'})!.errors;

        expect(errors.length, 1);
        expect(errors[0].instancePath, '/someKey');
        expect(errors[0].schemaPath, '/properties/someKey');
        expect(errors[0].message, contains('maxLength'));
      });

      test('pattern', () {
        final errors = schema.validate({'someKey': 'bye'})!.errors;

        expect(errors.length, 1);
        expect(errors[0].instancePath, '/someKey');
        expect(errors[0].schemaPath, '/properties/someKey');
        expect(errors[0].message, contains('pattern'));
      });
    });

    group('number', () {
      final schema = createObjectSchema({
        'properties': {
          'nonexclusive': {
            'maximum': 5.0,
            'minimum': 3.0,
          },
          'exclusive': {'exclusiveMaximum': 5.0, 'exclusiveMinimum': 3.0},
          'multiple': {'multipleOf': 2}
        }
      });

      test('maximum', () {
        final errors = schema.validate({
          'someKey': {'nonexclusive': 5.1}
        })!.errors;

        expect(errors.length, 1);
        expect(errors[0].instancePath, '/someKey/nonexclusive');
        expect(errors[0].schemaPath, '/properties/someKey/properties/nonexclusive');
        expect(errors[0].message, contains('maximum'));
      });

      test('minimum', () {
        final errors = schema.validate({
          'someKey': {'nonexclusive': 2.9}
        })!.errors;

        expect(errors.length, 1);
        expect(errors[0].instancePath, '/someKey/nonexclusive');
        expect(errors[0].schemaPath, '/properties/someKey/properties/nonexclusive');
        expect(errors[0].message, contains('minimum'));
      });

      test('exclusiveMaximum', () {
        final errors = schema.validate({
          'someKey': {'exclusive': 5.0}
        })!.errors;

        expect(errors.length, 1);
        expect(errors[0].instancePath, '/someKey/exclusive');
        expect(errors[0].schemaPath, '/properties/someKey/properties/exclusive');
        expect(errors[0].message, contains('exclusiveMaximum'));
      });

      test('exclusiveMinimum', () {
        final errors = schema.validate({
          'someKey': {'exclusive': 3.0}
        })!.errors;

        expect(errors.length, 1);
        expect(errors[0].instancePath, '/someKey/exclusive');
        expect(errors[0].schemaPath, '/properties/someKey/properties/exclusive');
        expect(errors[0].message, contains('exclusiveMinimum'));
      });

      test('multipleOf', () {
        final errors = schema.validate({
          'someKey': {'multiple': 7}
        })!.errors;

        expect(errors.length, 1);
        expect(errors[0].instancePath, '/someKey/multiple');
        expect(errors[0].schemaPath, '/properties/someKey/properties/multiple');
        expect(errors[0].message, contains('multipleOf'));
      });
    });

    test('items with the same schema', () {
      final schema = createObjectSchema({
        'items': {'type': 'integer'}
      });
      final errors = schema.validate({
        'someKey': [1, 2, 'foo']
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey/2');
      expect(errors[0].schemaPath, '/properties/someKey/items');
      expect(errors[0].message, contains('type'));
    });

    test('items with an array of schemas', () {
      final schema = createObjectSchema({
        'items': [
          {'type': 'integer'},
          {'type': 'string'}
        ]
      });
      final errors = schema.validate({
        'someKey': ['foo', 'bar']
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey/0');
      expect(errors[0].schemaPath, '/properties/someKey/items/0');
      expect(errors[0].message, contains('type'));
    });

    test('defined items with type checking of additional items', () {
      final schema = createObjectSchema({
        'items': [
          {'type': 'string'},
          {'type': 'string'}
        ],
        'additionalItems': {'type': 'integer'}
      });
      final errors = schema.validate({
        'someKey': ['foo', 'bar', 'baz']
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey/2');
      expect(errors[0].schemaPath, '/properties/someKey/additionalItems');
      expect(errors[0].message, contains('type'));
    });

    test('defined items with no additional items allowed', () {
      final schema = createObjectSchema({
        'items': [
          {'type': 'string'},
          {'type': 'string'}
        ],
        'additionalItems': false
      });
      final errors = schema.validate({
        'someKey': ['foo', 'bar', 'baz']
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey/additionalItems');
      expect(errors[0].message, contains('additionalItems'));
    });

    test('simple allOf schema', () {
      final schema = createObjectSchema({
        "allOf": [
          {"type": "string"},
          {"maxLength": 5}
        ]
      });

      final errors = schema.validate({'someKey': 'a long string'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey/allOf');
      expect(errors[0].message, contains('allOf'));
    });

    test('allOf with an additional base schema', () {
      final schema = createObjectSchema({
        "properties": {
          "bar": {"type": "integer"}
        },
        "required": ["bar"],
        "allOf": [
          {
            "properties": {
              "foo": {"type": "string"}
            },
            "required": ["foo"]
          },
          {
            "properties": {
              "baz": {"type": "null"}
            },
            "required": ["baz"]
          }
        ]
      });

      final errors = schema.validate({
        'someKey': {'foo': 'string', 'bar': 1}
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey/allOf');
      expect(errors[0].message, contains('allOf'));
    });

    test('anyOf', () {
      final schema = createObjectSchema({
        "anyOf": [
          {"type": "integer"},
          {"minimum": 2}
        ]
      });

      final errors = schema.validate({'someKey': 1.5})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey/anyOf');
      expect(errors[0].message, contains('type'));
    });

    test('oneOf', () {
      final schema = createObjectSchema({
        "oneOf": [
          {"type": "integer"},
          {"minimum": 2}
        ]
      });

      final errors = schema.validate({'someKey': 3})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey/oneOf');
      expect(errors[0].message, contains('oneOf'));
    });

    test('not', () {
      final schema = createObjectSchema({
        "not": {"type": "integer"}
      });

      final errors = schema.validate({'someKey': 3})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey/not');
      expect(errors[0].message, contains('not'));
    });

    test('date-time format', () {
      final schema = createObjectSchema({'format': 'date-time'});

      final errors = schema.validate({'someKey': 'foo'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('date-time'));
    });

    test('URI format', () {
      final schema = createObjectSchema({'format': 'uri'});

      final errors = schema.validate({'someKey': 'foo'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('uri'));
    });

    test('URI reference format', () {
      final schema = createObjectSchema({'format': 'uri-reference'});

      final errors = schema.validate({'someKey': '\\\\WINDOWS\\fileshare'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('uri-reference'));
    });

    test('URI template format', () {
      final schema = createObjectSchema({'format': 'uri-template'});

      final errors = schema.validate({'someKey': 'http://example.com/dictionary/{term:1}/{term'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('uri-template'));
    });

    test('Email address format', () {
      final schema = createObjectSchema({'format': 'email'});

      final errors = schema.validate({'someKey': 'foo'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('email'));
    });

    test('IPv4 format', () {
      final schema = createObjectSchema({'format': 'ipv4'});

      final errors = schema.validate({'someKey': 'foo'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('ipv4'));
    });

    test('IPv6 format', () {
      final schema = createObjectSchema({'format': 'ipv6'});

      final errors = schema.validate({'someKey': '::foo'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('ipv6'));
    });

    test('Hostname format', () {
      final schema = createObjectSchema({'format': 'hostname'});

      final errors = schema.validate({'someKey': 'not_valid'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('hostname'));
    });

    test('JSON Pointer format', () {
      final schema = createObjectSchema({'format': 'json-pointer'});

      final errors = schema.validate({'someKey': 'foo'})!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('json-pointer'));
    });

    test('Unknown format', () {
      final schema = createObjectSchema({'format': 'fake-format'});

      final isValid = schema.validate({'someKey': '3'})!.isValid;

      expect(isValid, isTrue);
    });

    test('Object minProperties', () {
      final schema = createObjectSchema({'minProperties': 2});
      final errors = schema.validate({
        'someKey': {'foo': 'bar'}
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('minProperties'));
    });

    test('Object maxProperties', () {
      final schema = createObjectSchema({'maxProperties': 1});
      final errors = schema.validate({
        'someKey': {'foo': 1, 'bar': 2}
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey');
      expect(errors[0].message, contains('maxProperties'));
    });

    test('Object required properties', () {
      final schema = createObjectSchema({
        'properties': {
          'foo': {'type': 'string'},
          'bar': {'type': 'string'}
        },
        'required': ['foo', 'bar']
      });
      final errors = schema.validate({
        'someKey': {'foo': 'a'}
      })!.errors;

      // Error for the root object instance path.
      expect(errors.length, 2);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey/required');
      expect(errors[0].message, contains('required'));
      // Second error for the missing property on object.
      expect(errors[1].instancePath, '/someKey/bar');
      expect(errors[1].schemaPath, '/properties/someKey/required');
      expect(errors[1].message, contains('required'));
    });

    test('Object pattern properties', () {
      final schema = createObjectSchema({
        'patternProperties': {
          'f.*o': {'type': 'integer'},
        }
      });
      final errors = schema.validate({
        'someKey': {'foooooooo': 'a'}
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey/foooooooo');
      expect(errors[0].schemaPath, '/properties/someKey/patternProperties/f.*o');
      expect(errors[0].message, contains('type'));
    });

    test('Object additional properties not allowed', () {
      final schema = createObjectSchema({
        'properties': {
          'foo': {'type': 'string'},
          'bar': {'type': 'string'}
        },
        'additionalProperties': false
      });
      final errors = schema.validate({
        'someKey': {'foo': 'a', 'bar': 'b', 'baz': 'c'}
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey/additionalProperties');
      expect(errors[0].message, contains('additional property'));
    });

    test('Object additional properties with schema', () {
      final schema = createObjectSchema({
        'properties': {
          'foo': {'type': 'string'},
          'bar': {'type': 'string'}
        },
        'additionalProperties': {'type': 'string'}
      });
      final errors = schema.validate({
        'someKey': {'foo': 'a', 'bar': 'b', 'baz': 3}
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey/baz');
      expect(errors[0].schemaPath, '/properties/someKey/additionalProperties');
      expect(errors[0].message, contains('type'));
    });

    test('Object with property dependencies', () {
      final schema = createObjectSchema({
        'dependencies': {
          'bar': ['foo']
        }
      });
      final errors = schema.validate({
        'someKey': {'bar': 'b'}
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey/dependencies');
      expect(errors[0].message, contains('required'));
    });

    test('Object with schema dependencies', () {
      final schema = createObjectSchema({
        "dependencies": {
          "bar": {
            "properties": {
              "foo": {"type": "integer"},
              "bar": {"type": "integer"}
            }
          }
        }
      });
      final errors = schema.validate({
        'someKey': {"foo": 2, "bar": "quux"}
      })!.errors;

      expect(errors.length, 1);
      expect(errors[0].instancePath, '/someKey');
      expect(errors[0].schemaPath, '/properties/someKey/dependencies/bar');
      expect(errors[0].message, contains('schema dependency'));
    });

    group('string formatting', () {
      final schema = JsonSchema.create({
        "properties": {
          "foo": {"type": "string"},
          "bar": {"type": "integer"}
        },
        "required": ["foo"]
      });

      test('with an instance path should include the path', () {
        final errors = schema.validate({'foo': 'some string', 'bar': 'oops this should be an integer'})!.errors;
        expect(errors.length, 1);
        expect(errors[0].toString().startsWith('/bar:'), isTrue);
      });

      test('without an instance path should add "root" instead of the path', () {
        final errors = schema.validate({})!.errors;
        expect(errors.length, 2);
        expect(errors[0].toString(), '# (root): required prop missing: foo from {}');
      });
    });

    group('reference', () {
      final schemaJson = {
        'properties': {
          'minItems': {'minItems': 2},
          'maxItems': {'maxItems': 2},
          'minLength': {'\$ref': '#/properties/refDestination'},
          'refDestination': {'minLength': 5},
          'maxLength': {'\$ref': 'http://localhost/destination.json'},
          'stringArray': {
            'type': 'array',
            'items': {'type': 'string'}
          },
        }
      };

      final RefProvider syncRefProvider = RefProvider.sync((String ref) {
        final refs = {
          'http://localhost/destination.json': {'maxLength': 2}
        };

        return refs[ref];
      });

      final schema = JsonSchema.create(schemaJson, refProvider: syncRefProvider);

      test('local', () {
        final errors = schema.validate({'minLength': 'foo'})!.errors;

        expect(errors.length, 1);
        expect(errors[0].instancePath, '/minLength');
        expect(errors[0].schemaPath, '/properties/refDestination');
        expect(errors[0].message, contains('minLength'));
      });

      test('remote', () {
        final errors = schema.validate({'maxLength': 'foo'})!.errors;

        expect(errors.length, 1);
        expect(errors[0].instancePath, '/maxLength');
        expect(errors[0].schemaPath, 'http://localhost/destination.json/');
        expect(errors[0].message, contains('maxLength'));
      });
    });
  });
}
