import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

main() {
  test('Should respect configurable format validation', () {
    final schemaDraft7 = JsonSchema.create({
      'properties': {
        'someKey': {'format': 'email'}
      }
    }, schemaVersion: SchemaVersion.draft7);

    final schemaDraft2019 = JsonSchema.create({
      'properties': {
        'someKey': {'format': 'email'}
      }
    }, schemaVersion: SchemaVersion.draft2019_09);

    final badlyFormatted = {'someKey': '@@@@@'};

    expect(schemaDraft7.validateWithResults(badlyFormatted).errors.isEmpty, isFalse);
    expect(schemaDraft7.validateWithResults(badlyFormatted, validateFormats: false).errors.isEmpty, isTrue);

    expect(schemaDraft2019.validateWithResults(badlyFormatted).errors.isEmpty, isTrue);
    expect(schemaDraft2019.validateWithResults(badlyFormatted, validateFormats: true).errors.isEmpty, isFalse);
  });
}
