import 'package:json_schema/src/json_schema/formats/validation_regexes.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';

ValidationContext defaultIpv4Validator(ValidationContext context, String? instanceData) {
  if (JsonSchemaValidationRegexes.ipv4.firstMatch(instanceData!) == null) {
    context.addError('"ipv4" format not accepted $instanceData');
  }
  return context;
}
