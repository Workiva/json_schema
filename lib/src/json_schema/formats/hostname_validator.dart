import 'package:json_schema/src/json_schema/formats/validation_regexes.dart';
import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';

ValidationContext defaultHostnameValidator(ValidationContext context, String? instanceData) {
  final regexp = context.schemaVersion < SchemaVersion.draft2019_09
      ? JsonSchemaValidationRegexes.hostname
      // Updated in Draft 2019-09
      : JsonSchemaValidationRegexes.hostnameDraft2019;

  if (regexp.firstMatch(instanceData!) == null) {
    context.addError('"hostname" format not accepted $instanceData');
  }
  return context;
}
