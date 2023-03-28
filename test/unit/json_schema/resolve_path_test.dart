import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

main() {
  late JsonSchema testSchema;
  setUp(() {
    testSchema = JsonSchema.create({
      '\$id': 'root',
      '\$defs': {
        'a': {
          '\$anchor': 'a_anchor',
          'properties': {
            'deeper': {'const': 'deeper in the schema'},
          },
          '\$ref': '#/\$defs/b'
        },
        'b': {'const': 'b in not resolved'}
      },
      'properties': {
        'foo': {'\$ref': '#/\$defs/a'},
        'baz': {
          '\$ref': '#a_anchor',
          'properties': {
            'findMe': {'const': 'is found'}
          }
        }
      }
    }, schemaVersion: SchemaVersion.draft2020_12);
  });
  group('Resolve path', () {
    test('ref resolved immediately when it is the only property.', () {
      var ref = testSchema.resolvePath(Uri.parse('#/properties/foo'))!;
      expect(ref.anchor, 'a_anchor');
    });

    test('ref should not resolve when there are multiple properties', () {
      var ref = testSchema.resolvePath(Uri.parse('#/properties/baz'))!;
      expect(ref.constValue, null);
      expect(ref.ref == null, false);
    });

    test('should continue resolving in the current node even if there is a ref', () {
      final ref = testSchema.resolvePath(Uri.parse('#/properties/baz/properties/findMe'))!;
      expect(ref.constValue, 'is found');
    });

    test('should follow the ref and continue resolving', () {
      final ref = testSchema.resolvePath(Uri.parse('#/properties/baz/properties/deeper'))!;
      expect(ref.constValue, 'deeper in the schema');
    });

    test('should throw an exception when there in an ambiguous path', () async {
      final testSchema = await JsonSchema.createAsync({
        "\$ref": "#/\$defs/objectX",
        "properties": {
          "a": {"minimum": 1, "maximum": 2}
        },
        "\$defs": {
          "objectX": {
            "properties": {
              "a": {"type": "string"}
            }
          }
        }
      });
      expect(() => testSchema.resolvePath(Uri.parse('#/properties/a')), throwsException);
    });

    test('should throw an exception when there in an ambiguous path', () {
      final schema = JsonSchema.create({
        "\$defs": {
          "a": {"type": "integer"},
          "b": {"\$ref": "#/\$defs/a"},
          "c": {"\$ref": "#/\$defs/b"}
        },
        "properties": {
          "Q": {
            "type": "object",
            "\$ref": "#/\$defs/c",
            "properties": {
              "a": {"type": "string"}
            }
          }
        }
      }, schemaVersion: SchemaVersion.draft2020_12);
      expect(() => schema.resolvePath(Uri.parse('#/properties/Q/a')), throwsException);
    });
  });
}
