import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';
import 'package:rfc_6901/rfc_6901.dart';

ValidationContext defaultJsonPointerValidator(ValidationContext context, String? instanceData) {
  if (context.schemaVersion < SchemaVersion.draft6) return context;
  try {
    JsonPointer(instanceData!);
  } on FormatException catch (_) {
    context.addError('"json-pointer" format not accepted $instanceData');
  }
  return context;
}
