import 'package:json_schema/src/json_schema/global_platform_functions.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';

ValidationContext defaultUriValidator(ValidationContext context, String? instanceData) {
  final isValid = defaultValidators.uriValidator as dynamic Function(String?)? ?? (_) => false;
  if (!isValid(instanceData)) {
    context.addError('"uri" format not accepted $instanceData');
  }
  return context;
}
