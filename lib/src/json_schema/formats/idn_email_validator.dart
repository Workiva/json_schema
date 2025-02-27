import 'package:json_schema/src/json_schema/models/validation_context.dart';
import 'package:rfc_6531/rfc_6531.dart' as rfc_6531;

ValidationContext defaultIdnEmailValidator(ValidationContext context, String instanceData) {
  if (rfc_6531.regExp.firstMatch(instanceData) == null) {
    context.addError('"idn-email" format not accepted $instanceData');
  }
  return context;
}
