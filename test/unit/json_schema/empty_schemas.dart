import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

main() {
  group('JsonSchema.empty', () {
    test('can get an empty schema for any version', () {
      for (final version in SchemaVersion.values) {
        final emptySchema = JsonSchema.empty(schemaVersion: version);
        expect(emptySchema.schemaVersion, equals(version));
      }
    });
    test('defaults to the current default version', () {
      final emptySchema = JsonSchema.empty();
      expect(emptySchema.schemaVersion, equals(SchemaVersion.defaultVersion));
    });
    test('calling JsonSchema.empty on the same version has same identity', () {
      final thing1 = JsonSchema.empty();
      final thing2 = JsonSchema.empty();
      expect(identical(thing1, thing2), isTrue);
    });
  });
}
