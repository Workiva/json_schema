@TestOn('vm')
// Runs on VM because filesystem paths can only be resolved on a server.

import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

main() {
  test('Schema from relative filesystem URI should be supported', () async {
    // this assumes that tests are run from the root directory of the project
    final schema = await JsonSchema.createFromUrl('test/relative_refs/root.json');

    expect(schema.validate({"string": 123, "integer": 123})!.isValid, isFalse);
    expect(schema.validate({"string": "a string", "integer": "a string"})!.isValid, isFalse);
    expect(schema.validate({"string": "a string", "integer": 123})!.isValid, isTrue);
  });
}
