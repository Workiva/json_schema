import 'package:json_schema/src/json_schema/global_platform_functions.dart';
import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';

ValidationContext defaultIriValidator(ValidationContext context, String? instanceData) {
  if (context.schemaVersion < SchemaVersion.draft7) return context;
  // Dart's URI class supports parsing IRIs, so we can use the same validator
  final isValid = defaultValidators.uriValidator as dynamic Function(String?)? ?? (_) => false;

  if (!isValid(instanceData)) {
    context.addError('"iri" format not accepted $instanceData');
  }
  return context;
}
