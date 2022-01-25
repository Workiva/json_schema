/// Formats introduced in Draft 4.
/// Commented out lines are NOT skipped.
final List<String> skippedDraft4FormatTestFiles = const [
  // 'date-time.json',
  // 'email.json',
  // 'hostname.json',
  // 'ipv4.json',
  // 'ipv6.json',
  // 'uri.json',
];

/// Formats introduced in Draft 6.
/// Commented out lines are NOT skipped.
final List<String> skippedDraft6FormatTestFiles = const [
  // 'json-pointer.json',
  // 'uri-reference.json',
  // 'uri-template.json',
];

/// Formats introduced in Draft 6.
/// Commented out lines are NOT skipped.
final List<String> skippedDraft7FormatTestFiles = const [
  // 'date.json',
  // 'idn-email.json',
  // 'idn-hostname.json',
  // 'iri-reference.json',
  // 'iri.json',
  // 'regex.json',
  // 'relative-json-pointer.json',
  // 'time.json',
];

/// Optional tests for Draft 7 (Not Optional later,
/// so needed for 2019-09, 2020-12, etc):
final List<String> skippedOptionalDraft7TestFiles = const [
  'content.json',
];

/// Optional tests for all drafts.
final List<String> skippedOptionalTestFiles = const [
  // Optional for all Drafts:
  'bignum.json',
  'float-overflow.json',
];

/// These tests are skipped because they do not yet pass.
/// We strive to keep the length of this list at zero,
/// but sometimes new tests are introducd that don't pass,
/// and we'd rather be up-to-date than have all tests pass.
final List<String> skippedNonWorkingTestFiles = const [
  // Not yet passing:
  'id.json',
  'unknownKeyword.json',
  // Not passing in the browser (Draft 4 Only)
  'zeroTerminatedFloats.json'
];

final List<String> commonSkippedTestFiles = []
  // Formats
  ..addAll(skippedDraft4FormatTestFiles)
  ..addAll(skippedDraft6FormatTestFiles)
  ..addAll(skippedDraft7FormatTestFiles)
  // Optional Tests
  ..addAll(skippedOptionalDraft7TestFiles)
  ..addAll(skippedOptionalTestFiles)
  // Non-passing Tests
  ..addAll(skippedNonWorkingTestFiles);

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
/// All Drafts: Dart Doesn't Support Leap-Seconds per: https://api.dart.dev/stable/2.15.1/dart-core/Duration/secondsPerMinute-constant.html
final List<String> skippedLeapSecondTests = const [
  // All Drafts:
  'validation of date-time strings : an invalid date-time past leap second, UTC', // date-time.json
  'validation of date-time strings : an invalid date-time with leap second on a wrong minute, UTC', // date-time.json
  'validation of date-time strings : an invalid date-time with leap second on a wrong hour, UTC', // date-time.json
  /// Draft 7 and later:
  'validation of time strings : a valid time string with leap second, Zulu', // time.json
  'validation of time strings : valid leap second, zero time-offset', // time.json
  'validation of time strings : valid leap second, positive time-offset', // time.json
  'validation of time strings : valid leap second, large positive time-offset', // time.json
  'validation of time strings : valid leap second, negative time-offset', // time.json
  'validation of time strings : valid leap second, large negative time-offset', // time.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
/// We choose not to worry about these because we don't want our JSON Schema implementation to be LESS permissive than
/// the Dart language itself, as that might be confusing to consumers.
final List<String> skippedPermissiveDateTimeFormatTests = const [
  /// All Drafts:
  'validation of date-time strings : an invalid day in date-time string', // date-time.json
  'validation of date-time strings : an invalid offset in date-time string', // date-time.json
  'validation of date-time strings : case-insensitive T and Z', // date-time.json
  // Draft 7 and later (date format)
  'validation of date strings : a invalid date string with 29 days in February (normal)', // date.json
  'validation of date strings : a invalid date string with 30 days in February (leap)', // date.json
  'validation of date strings : a invalid date string with 31 days in April', // date.json
  'validation of date strings : a invalid date string with 31 days in June', // date.json
  'validation of date strings : a invalid date string with 31 days in September', // date.json
  'validation of date strings : a invalid date string with 31 days in November', // date.json
  'validation of date strings : invalid month-day combination', // date.json
  'validation of date strings : 2021 is not a leap year', // date.json
  // Draft 7 and later (time format)
  'validation of time strings : a valid time string with second fraction', // time.json
  'validation of time strings : a valid time string with precise second fraction', // time.json
  'validation of time strings : a valid time string with case-insensitive Z', // time.json
  // Draft 2019 and later (date format)
  'validation of date strings : a invalid date string with 32 days in January', // date.json
  'validation of date strings : a invalid date string with 32 days in March', // date.json
  'validation of date strings : a invalid date string with 32 days in May', // date.json
  'validation of date strings : a invalid date string with 32 days in July', // date.json
  'validation of date strings : a invalid date string with 32 days in August', // date.json
  'validation of date strings : a invalid date string with 32 days in October', // date.json
  'validation of date strings : a invalid date string with 32 days in December', // date.json
  'validation of date strings : a invalid date string with invalid month', // date.json
  'validation of date strings : an invalid date string', // date.json
  'validation of date strings : only RFC3339 not all of ISO 8601 are valid', // date.json
  'validation of date strings : non-padded month dates are not valid', // date.json
  'validation of date strings : non-padded day dates are not valid', // date.json
  'validation of date strings : invalid month', // date.json
  'validation of date strings : non-ascii digits should be rejected', // date.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
/// We choose not to worry about these because we don't want our JSON Schema implementation to be LESS permissive than
/// the Dart language itself, as that might be confusing to consumers.
final List<String> skippedIpv6FormatTests = const [
  'validation of IPv6 addresses : trailing whitespace is invalid', // ipv6.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
/// There is not currently a good relative json pointer implementation for Dart.
final List<String> skippedRelativeJsonPointerFormatTest = const [
  'validation of Relative JSON Pointers (RJP) : a valid upwards RJP', // relative-json-pointers.json
  'validation of Relative JSON Pointers (RJP) : a valid downwards RJP', // relative-json-pointers.json
  'validation of Relative JSON Pointers (RJP) : a valid up and then down RJP, with array index', // relative-json-pointers.json
  'validation of Relative JSON Pointers (RJP) : an invalid RJP that is a valid JSON Pointer', // relative-json-pointers.json
  'validation of Relative JSON Pointers (RJP) : a valid RJP taking the member or index name', // relative-json-pointers.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
/// There is not currently a good IDN Hostname format implementation for Dart.
final List<String> skippedIdnHostnameFormatTests = const [
  'validation of internationalized host names : a valid host name (example.test in Hangul)', // idn-hostname.json
  'validation of internationalized host names : valid Chinese Punycode', // idn-hostname.json
  'validation of internationalized host names : Exceptions that are PVALID, left-to-right chars', // idn-hostname.json
  'validation of internationalized host names : Exceptions that are PVALID, right-to-left chars', // idn-hostname.json
  'validation of internationalized host names : MIDDLE DOT with surrounding \'l\'s', // idn-hostname.json
  'validation of internationalized host names : Greek KERAIA followed by Greek', // idn-hostname.json
  'validation of internationalized host names : Hebrew GERESH preceded by Hebrew', // idn-hostname.json
  'validation of internationalized host names : Hebrew GERSHAYIM preceded by Hebrew', // idn-hostname.json
  'validation of internationalized host names : KATAKANA MIDDLE DOT with Hiragana', // idn-hostname.json
  'validation of internationalized host names : KATAKANA MIDDLE DOT with Katakana', // idn-hostname.json
  'validation of internationalized host names : KATAKANA MIDDLE DOT with Han', // idn-hostname.json
  'validation of internationalized host names : Arabic-Indic digits not mixed with Extended Arabic-Indic digits', // idn-hostname.json
  'validation of internationalized host names : Extended Arabic-Indic digits not mixed with Arabic-Indic digits', // idn-hostname.json
  'validation of internationalized host names : ZERO WIDTH JOINER preceded by Virama', // idn-hostname.json
  'validation of internationalized host names : ZERO WIDTH NON-JOINER preceded by Virama', // idn-hostname.json
  'validation of internationalized host names : ZERO WIDTH NON-JOINER not preceded by Virama but matches regexp', // idn-hostname.json

  // Draft 2019 and later
  'validation of internationalized host names : illegal first char U+302E Hangul single dot tone mark',
  'validation of internationalized host names : contains illegal char U+302E Hangul single dot tone mark', // idn-hostname.json
  'validation of internationalized host names : a host name with a component too long', // idn-hostname.json
  'validation of internationalized host names : invalid label, correct Punycode', // idn-hostname.json
  'validation of internationalized host names : invalid Punycode', // idn-hostname.json
  'validation of internationalized host names : U-label contains "--" in the 3rd and 4th position', // idn-hostname.json
  'validation of internationalized host names : U-label starts with a dash', // idn-hostname.json
  'validation of internationalized host names : U-label ends with a dash', // idn-hostname.json
  'validation of internationalized host names : U-label starts and ends with a dash', // idn-hostname.json
  'validation of internationalized host names : Begins with a Spacing Combining Mark', // idn-hostname.json
  'validation of internationalized host names : Begins with a Nonspacing Mark', // idn-hostname.json
  'validation of internationalized host names : Begins with an Enclosing Mark', // idn-hostname.json
  'validation of internationalized host names : Exceptions that are DISALLOWED, right-to-left chars', // idn-hostname.json
  'validation of internationalized host names : Exceptions that are DISALLOWED, left-to-right chars', // idn-hostname.json
  'validation of internationalized host names : MIDDLE DOT with no preceding \'l\'', // idn-hostname.json
  'validation of internationalized host names : MIDDLE DOT with nothing preceding', // idn-hostname.json
  'validation of internationalized host names : MIDDLE DOT with no following \'l\'', // idn-hostname.json
  'validation of internationalized host names : MIDDLE DOT with nothing following', // idn-hostname.json
  'validation of internationalized host names : Greek KERAIA not followed by Greek', // idn-hostname.json
  'validation of internationalized host names : Greek KERAIA not followed by anything', // idn-hostname.json
  'validation of internationalized host names : Hebrew GERESH not preceded by Hebrew', // idn-hostname.json
  'validation of internationalized host names : Hebrew GERESH not preceded by anything', // idn-hostname.json
  'validation of internationalized host names : Hebrew GERSHAYIM not preceded by Hebrew', // idn-hostname.json
  'validation of internationalized host names : Hebrew GERSHAYIM not preceded by anything', // idn-hostname.json
  'validation of internationalized host names : KATAKANA MIDDLE DOT with no Hiragana, Katakana, or Han', // idn-hostname.json
  'validation of internationalized host names : KATAKANA MIDDLE DOT with no other characters', // idn-hostname.json
  'validation of internationalized host names : Arabic-Indic digits mixed with Extended Arabic-Indic digits', // idn-hostname.json
  'validation of internationalized host names : ZERO WIDTH JOINER not preceded by Virama', // idn-hostname.json
  'validation of internationalized host names : ZERO WIDTH JOINER not preceded by anything', // idn-hostname.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
final List<String> skippedIdnEmailFormatTests = const [
  'validation of an internationalized e-mail addresses : an invalid idn e-mail address', // idn-email.json
  'validation of an internationalized e-mail addresses : an invalid e-mail address', // idn-email.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
final List<String> skippedIriFormatTests = const [
  'validation of IRIs : an invalid IRI based on IPv6', // iri.json
  'validation of IRIs : an invalid relative IRI Reference', // iri.json
  'validation of IRIs : an invalid IRI', // iri.json
  'validation of IRIs : an invalid IRI though valid IRI reference', // iri.json
  'validation of IRI References : an invalid IRI Reference', // iri-reference.json
  'validation of IRI References : an invalid IRI fragment', // iri-reference.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
final List<String> skippedJsonPointerFormatTests = const [
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (~ not escaped)', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (URI Fragment Identifier) #1', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (URI Fragment Identifier) #2', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (URI Fragment Identifier) #3', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (some escaped, but not all) #1', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (some escaped, but not all) #2', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (wrong escape character) #1', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (wrong escape character) #2', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (multiple characters not escaped)', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (isn\'t empty nor starts with /) #1', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (isn\'t empty nor starts with /) #2', // json-pointer.json
  'validation of JSON-pointers (JSON String Representation) : not a valid JSON-pointer (isn\'t empty nor starts with /) #3', // json-pointer.json
  'validation of Relative JSON Pointers (RJP) : negative prefix', // relative-json-pointer.json
  'validation of Relative JSON Pointers (RJP) : ## is not a valid json-pointer',
  'validation of Relative JSON Pointers (RJP) : zero cannot be followed by other digits, plus json-pointer', // relative-json-pointer.json
  'validation of Relative JSON Pointers (RJP) : zero cannot be followed by other digits, plus octothorpe', // relative-json-pointer.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
final List<String> skippedRegexTests = const [
  'validation of regular expressions : a regular expression with unclosed parens is invalid', // regex.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
final List<String> skippedTimeTests = const [
  'validation of time strings : invalid leap second, Zulu (wrong hour)', // time.json
  'validation of time strings : invalid leap second, Zulu (wrong minute)', // time.json
  'validation of time strings : invalid leap second, zero time-offset (wrong hour)', // time.json
  'validation of time strings : invalid leap second, zero time-offset (wrong minute)', // time.json
  'validation of time strings : invalid leap second, positive time-offset (wrong hour)', // time.json
  'validation of time strings : invalid leap second, positive time-offset (wrong minute)', // time.json
  'validation of time strings : invalid leap second, negative time-offset (wrong hour)', // time.json
  'validation of time strings : invalid leap second, negative time-offset (wrong minute)', // time.json
  'validation of time strings : an invalid time string with invalid hour', // time.json
  'validation of time strings : an invalid time string with invalid minute', // time.json
  'validation of time strings : an invalid time string with invalid second', // time.json
  'validation of time strings : an invalid time string with invalid leap second (wrong hour)', // time.json
  'validation of time strings : an invalid time string with invalid leap second (wrong minute)', // time.json
  'validation of time strings : an invalid time string with invalid time numoffset hour', // time.json
  'validation of time strings : an invalid time string with invalid time numoffset minute', // time.json
  'validation of time strings : an invalid time string with invalid time with both Z and numoffset', // time.json
  'validation of time strings : an invalid offset indicator', // time.json
  'validation of time strings : only RFC3339 not all of ISO 8601 are valid', // time.json
  'validation of time strings : no time offset', // time.json
  'validation of time strings : non-ascii digits should be rejected', // time.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
final List<String> skippedURITests = const [
  'validation of URI References : an invalid URI Reference', // uri-reference.json
  'validation of URI References : an invalid URI fragment', // uri-reference.json
  'format: uri-template : an invalid uri-template', // uri-template.json
];

/// All Skipped tests below are OPTIONAL format tests. Implementations make a best effort to support these.
final List<String> skippedUUIDTests = const [
  'uuid format : hypothetical version 6', // uuid.json
  'uuid format : hypothetical version 15', // uuid.json
];

/// A list of tests to skip for all drafts.
/// Should match the portion of the test name printed after the JSON file name on test run.
final List<String> commonSkippedTests = []
  ..addAll(skippedLeapSecondTests)
  ..addAll(skippedPermissiveDateTimeFormatTests)
  ..addAll(skippedIpv6FormatTests)
  ..addAll(skippedRelativeJsonPointerFormatTest)
  ..addAll(skippedIdnHostnameFormatTests)
  ..addAll(skippedIdnEmailFormatTests)
  ..addAll(skippedIriFormatTests)
  ..addAll(skippedJsonPointerFormatTests)
  ..addAll(skippedRegexTests)
  ..addAll(skippedTimeTests)
  ..addAll(skippedURITests)
  ..addAll(skippedUUIDTests);

final List<String> draft2019SkippedTestFiles = [
  // WIP
  "unevaluatedProperties.json",

  // As of Draft 2019, format validation becomes an opt-in option.
  // We *do* run the optional format test files below, but they appear
  // on this skip list because they are skipped when we are running not configured
  // to validate formats. Instead we run them in a separate test configuration.
  "date.json",
  "date-time.json",
  "duration.json",
  "email.json",
  "hostname.json",
  "idn-hostname.json",
  "ipv4.json",
  "ipv6.json",
  "iri-reference.json",
  "iri.json",
  "json-pointer.json",
  "regex.json",
  "relative-json-pointer.json",
  "time.json",
  "uri-reference.json",
  "uri-template.json",
  "uri.json",
  "uuid.json",
]..addAll(commonSkippedTestFiles);

final List<String> draft2019SkippedTests = [
  // Requires unevaluatedProperties support
  'ref creates new scope when adjacent to keywords : referenced subschema doesn\'t see annotations from properties',
  'unevaluatedItems with \$ref : with no unevaluated items',
  'unevaluatedItems with \$ref : with unevaluated items',
]..addAll(commonSkippedTests);

final List<String> draft2019FormatSkippedTestFiles = [];
