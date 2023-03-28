import 'package:json_schema/json_schema.dart';

abstract class SchemaUrlClient {
  Future<JsonSchema> createFromUrl(
    String schemaUrl, {
    SchemaVersion? schemaVersion,
    List<CustomVocabulary>? customVocabularies,
    Map<String, ValidationContext Function(ValidationContext context, String? instanceData)> customFormats = const {},
  });

  Future<Map<String, dynamic>?> getSchemaJsonFromUrl(String schemaUrl);
}
