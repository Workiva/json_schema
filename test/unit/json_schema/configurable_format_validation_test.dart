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

    expect(schemaDraft7.validate(badlyFormatted)!.isValid, isFalse);
    expect(schemaDraft7.validate(badlyFormatted, validateFormats: false)!.isValid, isTrue);

    expect(schemaDraft2019.validate(badlyFormatted)!.isValid, isTrue);
    expect(schemaDraft2019.validate(badlyFormatted, validateFormats: true)!.isValid, isFalse);
  });
}
