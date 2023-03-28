import 'package:json_schema/src/json_schema/formats/validation_regexes.dart';
import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';

ValidationContext defaultRelativeJsonPointerValidator(ValidationContext context, String? instanceData) {
  if (context.schemaVersion < SchemaVersion.draft7) return context;
  if (JsonSchemaValidationRegexes.relativeJsonPointer.firstMatch(instanceData!) == null) {
    context.addError('"relative-json-pointer" format not accepted $instanceData');
  }
  return context;
}
