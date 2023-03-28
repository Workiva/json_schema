import 'package:json_schema/src/json_schema/formats/date_time_validator.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';

import 'date_validator.dart';
import 'duration_validator.dart';
import 'email_validator.dart';
import 'hostname_validator.dart';
import 'idn_email_validator.dart';
import 'idn_hostname_validator.dart';
import 'ipv4_validator.dart';
import 'ipv6_validator.dart';
import 'iri_validator.dart';
import 'iri_reference_validator.dart';
import 'json_pointer_validator.dart';
import 'regex_validator.dart';
import 'relative_json_pointer_validator.dart';
import 'time_validator.dart';
import 'uri_reference_validator.dart';
import 'uri_template_validator.dart';
import 'uri_validator.dart';
import 'uuid_validator.dart';

Map<String, ValidationContext Function(ValidationContext context, String? instanceData)> defaultFormatValidators = {
  'date': defaultDateValidator,
  'date-time': defaultDateTimeValidator,
  'duration': defaultDurationValidator,
  'email': defaultEmailValidator,
  'hostname': defaultHostnameValidator,
  'idn-email': defaultIdnEmailValidator,
  'idn-hostname': defaultIdnHostnameValidator,
  'ipv4': defaultIpv4Validator,
  'ipv6': defaultIpv6Validator,
  'iri': defaultIriValidator,
  'iri-reference': defaultIriReferenceValidator,
  'json-pointer': defaultJsonPointerValidator,
  'regex': defaultRegexValidator,
  'relative-json-pointer': defaultRelativeJsonPointerValidator,
  'time': defaultTimeValidator,
  'uri': defaultUriValidator,
  'uri-reference': defaultUriReferenceValidator,
  'uri-template': defaultUriTemplateValidator,
  'uuid': defaultUuidValidator,
};
