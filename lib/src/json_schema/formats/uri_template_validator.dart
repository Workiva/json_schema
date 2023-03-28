import 'package:json_schema/src/json_schema/global_platform_functions.dart';
import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';

ValidationContext defaultUriTemplateValidator(ValidationContext context, String? instanceData) {
  if (context.schemaVersion < SchemaVersion.draft6) return context;
  final isValid = defaultValidators.uriTemplateValidator as dynamic Function(String?)? ?? (_) => false;

  if (!isValid(instanceData)) {
    context.addError('"uri-template" format not accepted $instanceData');
  }
  return context;
}
