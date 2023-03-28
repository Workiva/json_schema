import 'package:json_schema/src/json_schema/formats/validation_regexes.dart';
import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';

ValidationContext defaultIdnHostnameValidator(ValidationContext context, String? instanceData) {
  if (context.schemaVersion < SchemaVersion.draft7) return context;

  final regexp = context.schemaVersion < SchemaVersion.draft2019_09
      ? JsonSchemaValidationRegexes.idnHostname
      // Updated in Draft 2019-09
      : JsonSchemaValidationRegexes.idnHostnameDraft2019;

  if (regexp.firstMatch(instanceData!) == null) {
    context.addError('"idn-hostname" format not accepted $instanceData');
  }
  return context;
}
