import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';

ValidationContext defaultRegexValidator(ValidationContext context, String? instanceData) {
  if (context.schemaVersion < SchemaVersion.draft7) return context;
  try {
    RegExp(instanceData!, unicode: true);
  } catch (e) {
    context.addError('"regex" format not accepted $instanceData');
  }
  return context;
}
