import 'package:json_schema/src/json_schema/models/validation_context.dart';

ValidationContext defaultIpv6Validator(ValidationContext context, String? instanceData) {
  try {
    Uri.parseIPv6Address(instanceData!);
  } on FormatException catch (_) {
    context.addError('"ipv6" format not accepted $instanceData');
  }
  return context;
}
