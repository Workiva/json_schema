import 'package:json_schema/json_schema.dart';

void main() {
  final schema = JsonSchema.empty();
  schema.validateWithResults(null);
  final validator = Validator(schema);
  validator.validateWithResults(null);
}
