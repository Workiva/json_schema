import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:convert' as convert;

import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';
import 'package:logging/logging.dart';
import 'package:rfc_6901/rfc_6901.dart';

import 'package:json_schema/src/json_schema/models/custom_vocabulary.dart';
import 'package:json_schema/src/json_schema/json_schema.dart';
import 'package:json_schema/src/json_schema/utils/utils.dart';
import 'package:json_schema/src/json_schema/schema_url_client/schema_url_client.dart';

final Logger _logger = Logger('IoSchemaUrlClient');

class IoSchemaUrlClient extends SchemaUrlClient {
  @override
  createFromUrl(
    String schemaUrl, {
    SchemaVersion? schemaVersion,
    List<CustomVocabulary>? customVocabularies,
    Map<String, ValidationContext Function(ValidationContext context, String? instanceData)> customFormats = const {},
  }) async {
    final uriWithFrag = Uri.parse(schemaUrl);
    final uri = schemaUrl.endsWith('#') ? uriWithFrag : uriWithFrag.removeFragment();
    Map? schemaMap;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      // Setup the HTTP request.
      _logger.info('GET\'ing Schema from URL: $uri');
      final httpRequest = await HttpClient().getUrl(uri);
      httpRequest.followRedirects = true;
      // Fetch the response
      final response = await httpRequest.close();
      // Convert the response into a string
      if (response.statusCode == HttpStatus.notFound) {
        throw ArgumentError('Schema at URL: $schemaUrl can\'t be found.');
      }
      final schemaText = await convert.Utf8Decoder().bind(response).join();
      schemaMap = json.decode(schemaText);
    } else if (uri.scheme == 'file' || uri.scheme == '') {
      final fileString = await File(uri.scheme == 'file' ? uri.toFilePath() : schemaUrl).readAsString();
      schemaMap = json.decode(fileString);
    } else {
      throw FormatException('Url schema must be http, file, or empty: $schemaUrl');
    }
    // HTTP servers / file systems ignore fragments, so resolve a sub-map if a fragment was specified.
    final parentSchema = await JsonSchema.createAsync(
      schemaMap,
      schemaVersion: schemaVersion,
      fetchedFromUri: uri,
      customVocabularies: customVocabularies,
      customFormats: customFormats,
    );
    final schema = JsonSchemaUtils.getSubMapFromFragment(parentSchema, uriWithFrag);
    return schema ?? parentSchema;
  }

  @override
  Future<Map<String, dynamic>?> getSchemaJsonFromUrl(String schemaUrl) async {
    final uriWithFrag = Uri.parse(schemaUrl);
    final uri = schemaUrl.endsWith('#') ? uriWithFrag : uriWithFrag.removeFragment();
    Map? schemaMap;
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      // Setup the HTTP request.
      _logger.info('GET\'ing Schema JSON from URL: $uri');
      final httpRequest = await HttpClient().getUrl(uri);
      httpRequest.followRedirects = true;
      // Fetch the response
      final response = await httpRequest.close();
      // Convert the response into a string
      if (response.statusCode == HttpStatus.notFound) {
        throw ArgumentError('Schema at URL: $schemaUrl can\'t be found.');
      }
      final schemaText = await convert.Utf8Decoder().bind(response).join();
      schemaMap = json.decode(schemaText);
    } else if (uri.scheme == 'file' || uri.scheme == '') {
      final fileString = await File(uri.scheme == 'file' ? uri.toFilePath() : schemaUrl).readAsString();
      schemaMap = json.decode(fileString);
    } else {
      throw FormatException('Url schema must be http, file, or empty: $schemaUrl');
    }
    // HTTP servers ignore fragments, so resolve a sub-map if a fragment was specified.
    var subSchema;
    try {
      subSchema = JsonPointer(uriWithFrag.fragment)?.read(schemaMap);
    } catch (_) {
      // Do nothing if we fail to decode or read the pointer.
    }
    return subSchema ?? schemaMap as FutureOr<Map<String, dynamic>?>;
  }
}

SchemaUrlClient createClient() => IoSchemaUrlClient();
