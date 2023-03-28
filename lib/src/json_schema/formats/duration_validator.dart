import 'package:json_schema/src/json_schema/formats/validation_regexes.dart';
import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';

ValidationContext defaultDurationValidator(ValidationContext context, String? instanceData) {
  if (context.schemaVersion < SchemaVersion.draft2019_09) return context;
  if (JsonSchemaValidationRegexes.duration.firstMatch(instanceData!) == null) {
    context.addError('"duration" format not accepted $instanceData');
  }
  return context;
}
