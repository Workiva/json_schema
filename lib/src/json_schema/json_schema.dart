// Copyright 2013-2022 Workiva Inc.
//
// Licensed under the Boost Software License (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.boost.org/LICENSE_1_0.txt
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This software or document includes material copied from or derived
// from JSON-Schema-Test-Suite (https://github.com/json-schema-org/JSON-Schema-Test-Suite),
// Copyright (c) 2012 Julian Berman, which is licensed under the following terms:
//
//     Copyright (c) 2012 Julian Berman
//
//     Permission is hereby granted, free of charge, to any person obtaining a copy
//     of this software and associated documentation files (the "Software"), to deal
//     in the Software without restriction, including without limitation the rights
//     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//     copies of the Software, and to permit persons to whom the Software is
//     furnished to do so, subject to the following conditions:
//
//     The above copyright notice and this permission notice shall be included in
//     all copies or substantial portions of the Software.
//
//     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//     THE SOFTWARE.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:rfc_6901/rfc_6901.dart';

import 'package:json_schema/src/json_schema/constants.dart';
import 'package:json_schema/src/json_schema/models/custom_keyword.dart';
import 'package:json_schema/src/json_schema/models/custom_vocabulary.dart';
import 'package:json_schema/src/json_schema/models/ref_provider.dart';
import 'package:json_schema/src/json_schema/models/schema_path_pair.dart';
import 'package:json_schema/src/json_schema/models/schema_version.dart';
import 'package:json_schema/src/json_schema/models/schema_type.dart';
import 'package:json_schema/src/json_schema/models/typedefs.dart';
import 'package:json_schema/src/json_schema/models/validation_context.dart';
import 'package:json_schema/src/json_schema/models/validation_results.dart';

import 'package:json_schema/src/json_schema/utils/format_exceptions.dart';
import 'package:json_schema/src/json_schema/utils/type_validators.dart';
import 'package:json_schema/src/json_schema/utils/utils.dart';
import 'package:json_schema/src/json_schema/validator.dart';

import 'package:json_schema/src/json_schema/schema_url_client/stub_schema_url_client.dart'
    if (dart.library.html) 'package:json_schema/src/json_schema/schema_url_client/html_schema_url_client.dart'
    if (dart.library.io) 'package:json_schema/src/json_schema/schema_url_client/io_schema_url_client.dart';

class RetrievalRequest {
  Uri? schemaUri;
  late AsyncRetrievalOperation asyncRetrievalOperation;
  SyncRetrievalOperation? syncRetrievalOperation;
}

final Map<SchemaVersion, JsonSchema> _emptySchemas = {};

/// Constructed with a json schema, either as string or Map. Validation of
/// the schema itself is done on construction. Any errors in the schema
/// result in a FormatException being thrown.
class JsonSchema {
  JsonSchema._fromMap(this._root, Map? schemaMap, this._path, {JsonSchema? parent})
      : _schemaMap = schemaMap != null ? Map<String, dynamic>.unmodifiable(schemaMap) : null,
        _schemaBool = null {
    if (schemaMap == null) {
      throw ArgumentError.notNull('schemaMap');
    }
    this._parent = parent;
    _initialize();
  }

  JsonSchema._fromBool(this._root, this._schemaBool, this._path, {JsonSchema? parent}) : _schemaMap = null {
    this._parent = parent;
    _initialize();
  }

  JsonSchema._fromRootMap(
    Map? schemaMap,
    SchemaVersion? schemaVersion, {
    Uri? fetchedFromUri,
    bool isSync = false,
    Map<String, JsonSchema>? refMap,
    RefProvider? refProvider,
    Map<Uri, bool>? metaschemaVocabulary,
    List<CustomVocabulary>? customVocabularies,
    Map<String, Map<String, SchemaPropertySetter>>? customVocabMap,
    Map<String, ValidationContext Function(ValidationContext context, String instanceData)> customFormats = const {},
  })  : _schemaMap = schemaMap != null ? Map<String, dynamic>.unmodifiable(schemaMap) : null,
        _schemaBool = null {
    if (schemaMap == null) {
      throw ArgumentError.notNull('schemaMap');
    }
    _initialize(
      schemaVersion: schemaVersion,
      fetchedFromUri: fetchedFromUri,
      isSync: isSync,
      refMap: refMap,
      refProvider: refProvider,
      metaschemaVocabulary: metaschemaVocabulary,
      customVocabMap: customVocabMap ?? _createCustomVocabMap(customVocabularies),
      customFormats: customFormats,
    );
  }

  JsonSchema._fromRootBool(
    this._schemaBool,
    SchemaVersion? schemaVersion, {
    Uri? fetchedFromUri,
    bool isSync = false,
    Map<String, JsonSchema>? refMap,
    RefProvider? refProvider,
    Map<Uri, bool>? metaschemaVocabulary,
    List<CustomVocabulary>? customVocabularies,
    Map<String, Map<String, SchemaPropertySetter>>? customVocabMap,
    Map<String, ValidationContext Function(ValidationContext context, String instanceData)> customFormats = const {},
  }) : _schemaMap = null {
    _initialize(
      schemaVersion: schemaVersion,
      fetchedFromUri: fetchedFromUri,
      isSync: isSync,
      refMap: refMap,
      refProvider: refProvider,
      metaschemaVocabulary: metaschemaVocabulary,
      customVocabMap: customVocabMap ?? _createCustomVocabMap(customVocabularies),
      customFormats: customFormats,
    );
  }

  /// Create a schema from a JSON data.
  ///
  /// This method is asynchronous to support fetching of sub-[JsonSchema]s for items,
  /// properties, and sub-properties of the root schema.
  ///
  /// If you want to create a [JsonSchema] synchronously, use [create]. Note that for
  /// [create] remote reference fetching is not supported.
  ///
  /// The [schema] can either be a decoded JSON object (Only [Map] or [bool] per the spec),
  /// or alternatively, a [String] may be passed in and JSON decoding will be handled automatically.
  static Future<JsonSchema> createAsync(
    Object? schema, {
    SchemaVersion? schemaVersion,
    Uri? fetchedFromUri,
    RefProvider? refProvider,
    List<CustomVocabulary>? customVocabularies,
    Map<String, ValidationContext Function(ValidationContext context, String instanceData)> customFormats = const {},
  }) {
    // Default to assuming the schema is already a decoded, primitive dart object.
    Object? data = schema;

    /// JSON Schemas must be [bool]s or [Map]s, so if we encounter a [String], we're looking at encoded JSON.
    /// https://json-schema.org/latest/json-schema-core.html#rfc.section.4.3.1
    if (schema is String) {
      try {
        data = json.decode(schema);
      } catch (e) {
        throw ArgumentError('String data provided to createAsync is not valid JSON.');
      }
    }

    /// Set the Schema version before doing anything else, since almost everything depends on it.
    final version = _getSchemaVersion(schemaVersion, data);

    if (data is Map) {
      return JsonSchema._fromRootMap(
        data,
        schemaVersion,
        fetchedFromUri: fetchedFromUri,
        refProvider: refProvider,
        customVocabularies: customVocabularies,
        customFormats: customFormats,
      )._thisCompleter.future;

      // Boolean schemas are only supported in draft 6 and later.
    } else if (data is bool && version >= SchemaVersion.draft6) {
      return JsonSchema._fromRootBool(
        data,
        schemaVersion,
        fetchedFromUri: fetchedFromUri,
        refProvider: refProvider,
        customVocabularies: customVocabularies,
        customFormats: customFormats,
      )._thisCompleter.future;
    }
    throw ArgumentError(
        'Data provided to createAsync is not valid: Data must be, or parse to a Map (or bool in draft6 or later). | $data');
  }

  /// Create a schema from JSON data.
  ///
  /// This method is synchronous, and doesn't support fetching of remote references, properties, and sub-properties of the
  /// schema. If you need remote reference support use [createAsync].
  ///
  /// The [schema] can either be a decoded JSON object (Only [Map] or [bool] per the spec),
  /// or alternatively, a [String] may be passed in and JSON decoding will be handled automatically.
  static JsonSchema create(
    Object schema, {
    SchemaVersion? schemaVersion,
    Uri? fetchedFromUri,
    RefProvider? refProvider,
    List<CustomVocabulary>? customVocabularies,
    Map<String, ValidationContext Function(ValidationContext context, String instanceData)> customFormats = const {},
  }) {
    // Default to assuming the schema is already a decoded, primitive dart object.
    Object? data = schema;

    /// JSON Schemas must be [bool]s or [Map]s, so if we encounter a [String], we're looking at encoded JSON.
    /// https://json-schema.org/latest/json-schema-core.html#rfc.section.4.3.1
    if (schema is String) {
      try {
        data = json.decode(schema);
      } catch (e) {
        throw ArgumentError('String data provided to create is not valid JSON.');
      }
    }

    /// Set the Schema version before doing anything else, since almost everything depends on it.
    schemaVersion = _getSchemaVersion(schemaVersion, data);

    if (data is Map) {
      return JsonSchema._fromRootMap(
        data,
        schemaVersion,
        fetchedFromUri: fetchedFromUri,
        isSync: true,
        refProvider: refProvider,
        customVocabularies: customVocabularies,
        customFormats: customFormats,
      );

      // Boolean schemas are only supported in draft 6 and later.
    } else if (data is bool && schemaVersion >= SchemaVersion.draft6) {
      return JsonSchema._fromRootBool(
        data,
        schemaVersion,
        fetchedFromUri: fetchedFromUri,
        isSync: true,
        refProvider: refProvider,
        customVocabularies: customVocabularies,
        customFormats: customFormats,
      );
    }
    throw ArgumentError(
        'Data provided to JsonSchema.create is not valid: Data must be a Map or a String that parses to a Map (or bool in draft6 or later). | $data');
  }

  /// Create a schema from a URL.
  ///
  /// This method is asynchronous to support automatic fetching of sub-[JsonSchema]s for items,
  /// properties, and sub-properties of the root schema.
  static Future<JsonSchema> createFromUrl(
    String schemaUrl, {
    SchemaVersion? schemaVersion,
    List<CustomVocabulary>? customVocabularies,
    Map<String, ValidationContext Function(ValidationContext context, String? instanceData)> customFormats = const {},
  }) {
    return createClient().createFromUrl(schemaUrl,
        schemaVersion: schemaVersion, customVocabularies: customVocabularies, customFormats: customFormats);
  }

  /// Create an empty schema.
  static JsonSchema empty({SchemaVersion schemaVersion = SchemaVersion.defaultVersion}) {
    return _emptySchemas[schemaVersion] ??= JsonSchema.create({}, schemaVersion: schemaVersion);
  }

  /// Construct and validate a JsonSchema.
  _initialize({
    SchemaVersion? schemaVersion,
    Uri? fetchedFromUri,
    bool isSync = false,
    Map<String, JsonSchema>? refMap,
    RefProvider? refProvider,
    Map<Uri, bool>? metaschemaVocabulary,
    Map<String, Map<String, SchemaPropertySetter>>? customVocabMap,
    Map<String, ValidationContext Function(ValidationContext context, String instanceData)> customFormats = const {},
  }) {
    String? schemaString;
    final JsonSchema root;
    if (_root == null) {
      /// Set the Schema version before doing anything else, since almost everything depends on it.
      final version = _getSchemaVersion(schemaVersion, this._schemaMap);

      root = _root = this;
      _isSync = isSync;
      _refMap = refMap ?? {};
      _refProvider = refProvider;
      _schemaVersion = version;
      _fetchedFromUri = fetchedFromUri;
      _metaschemaVocabulary = metaschemaVocabulary;
      _customVocabMap = customVocabMap ?? {};
      _customFormats = customFormats;
      _rootMemomizedPathResults = {};
      try {
        _fetchedFromUriBase = JsonSchemaUtils.getBaseFromFullUri(_fetchedFromUri!);
      } catch (e) {
        // ID base can't be set for schemes other than HTTP(S).
        // This is expected behavior.
      }
      _path = '#';
      final String refString = '${_uri ?? ''}$_path';
      _addSchemaToRefMap(refString, this);

      schemaString = _schemaMap?.containsKey(r'$schema') == true ? _schemaMap![r'$schema'] : null;
      _resolveMetaSchemasForVocabulary(schemaString, _schemaVersion);
    } else {
      root = _root!;
      _isSync = root._isSync;
      _refProvider = root._refProvider;
      _schemaVersion = root.schemaVersion;
      _refMap = root._refMap;
      _thisCompleter = root._thisCompleter;
      _metaSchemaCompleter = root._metaSchemaCompleter;
      _metaschemaVocabulary = metaschemaVocabulary;
      _schemaAssignments = root._schemaAssignments;
      _customVocabMap = root._customVocabMap;
      _customFormats = root._customFormats;
    }
    if (root._isSync) {
      _validateSchemaSync();
    } else {
      if (!root._metaSchemaCompleter.isCompleted) {
        // Wait here until the vocabularies from the metaschema have been resolved.
        // This should only need to happen once for the _root object.
        root._metaSchemaCompleter.future
            .then((_) => _validateSchemaAsync())
            .onError((Object e, stack) => root._thisCompleter.completeError(e, stack));
      } else {
        _validateSchemaAsync();
      }
    }
  }

  /// Calculate, validate and set all properties defined in the JSON Schema spec.
  ///
  /// Doesn't validate interdependent properties. See [_validateInterdependentProperties]
  void _validateAndSetIndividualProperties() {
    Map<String, SchemaPropertySetter> accessMap = {};
    // Set the access map based on features used in the currently set version.
    if (_root?.schemaVersion == SchemaVersion.draft4) {
      accessMap = _accessMapV4;
    } else if (_root?.schemaVersion == SchemaVersion.draft6) {
      accessMap = _accessMapV6;
    } else if ((_root?.schemaVersion ?? schemaVersion) >= SchemaVersion.draft2019_09) {
      final vocabMap = Map()
        ..addAll(_vocabMaps)
        ..addAll(_customVocabMap);
      this.metaschemaVocabulary?.keys.forEach((vocabUri) {
        accessMap.addAll(vocabMap[vocabUri.toString()]);
      });
    } else {
      accessMap = _accessMapV7;
    }

    processAttribute(String k, Object? v) {
      /// Get the _set<X> method from the [accessMap] based on the [Map] string key.
      final SchemaPropertySetter? accessor = accessMap[k];
      if (accessor != null) {
        accessor(this, v);
      } else {
        // Attempt to create a schema out of the custom property and register the ref, but don't error if it's not a valid schema.
        _createOrRetrieveSchema('$_path/$k', v, (rhs) {
          // Translate ref for schema to include full inheritedUri.
          final String refPath = rhs._translateLocalRefToFullUri(Uri.parse(rhs.path!)).toString();
          return _refMap[refPath] = rhs;
        }, mustBeValid: false);
      }
    }

    // Some sibling attributes depend on $id being setup first.
    if (_schemaMap?.containsKey(r'$id') == true) {
      processAttribute(r'$id', _schemaMap![r'$id']);
    }
    // Iterate over all string keys of the root JSON Schema Map. Calculate, validate and
    // set all properties according to spec.
    (_schemaMap ?? {}).forEach((k, v) {
      if (k != r'$id') {
        processAttribute(k, v);
      }
    });
  }

  void _validateInterdependentProperties() {
    // Check that a minimum is set if both exclusiveMinimum and minimum properties are set.
    if (_exclusiveMinimum != null && _minimum == null)
      throw FormatExceptions.error('exclusiveMinimum requires minimum');

    // Check that a minimum is set if both exclusiveMaximum and maximum properties are set.
    if (_exclusiveMaximum != null && _maximum == null)
      throw FormatExceptions.error('exclusiveMaximum requires maximum');
  }

  /// Validate, calculate and set all properties on the [JsonSchema], included properties
  /// that have interdependencies.
  void _validateAndSetAllProperties() {
    _validateAndSetIndividualProperties();

    // Interdependent properties were removed in draft6.
    if (schemaVersion == SchemaVersion.draft4) {
      _validateInterdependentProperties();
    }
  }

  void _baseResolvePaths() {
    if (_root == this) {
      // Validate refs in localRefs.
      for (Uri? localRef in _localRefs) {
        _getSchemaFromPath(localRef);
      }

      // Filter out requests that can be resolved locally.
      final List<RetrievalRequest> requestsToRemove = [];
      for (final retrievalRequest in _retrievalRequests) {
        // Optimistically assume resolution successful, and switch to false on errors.
        bool resolvedSuccessfully = true;
        JsonSchema? localSchema;
        final Uri? schemaUri = retrievalRequest.schemaUri;

        // Attempt to resolve schema if it does not exist within ref map already.
        if (schemaUri != null && _refMap[schemaUri.toString()] == null) {
          final Uri baseUri = schemaUri.scheme.isNotEmpty ? schemaUri.removeFragment() : schemaUri;
          final String baseUriString = '${baseUri}#';

          if (baseUri.path == _inheritedUri?.path) {
            // If the ref base is the same as the _inheritedUri, ref is _root schema.
            localSchema = _root;
          } else if (_refMap[baseUriString] != null) {
            // If the ref base is already in the _refMap, set it directly.
            localSchema = _refMap[baseUriString];
          } else if (SchemaVersion.fromString(baseUriString) != null) {
            // If the referenced URI is or within versioned schema spec.
            final staticSchema = getStaticSchemaByVersion(SchemaVersion.fromString(baseUriString));
            if (staticSchema != null) {
              _addSchemaToRefMap(baseUriString, JsonSchema.create(staticSchema));
            }
          } else {
            // The remote ref needs to be resolved if the above checks failed.
            resolvedSuccessfully = false;
          }

          // Resolve sub schema of fetched schema if a fragment was included.
          if (resolvedSuccessfully && schemaUri.fragment.isNotEmpty) {
            localSchema?.resolvePath(Uri.parse('#${schemaUri.fragment}'));
          }
        }

        // Mark retrieval request to be removed since it was resolved.
        if (resolvedSuccessfully) {
          requestsToRemove.add(retrievalRequest);
        }
      }

      // Pull out all successful retrieval requests.
      requestsToRemove.forEach(_retrievalRequests.remove);
    }
  }

  /// Check for refs that need to be fetched, fetch them, and return the final [JsonSchema].
  void _resolveAllPathsAsync() async {
    if (_root == this) {
      if (_retrievalRequests.isNotEmpty) {
        await Future.wait(_retrievalRequests.map((r) => r.asyncRetrievalOperation()));
      }

      _schemaAssignments.forEach((assignment) => assignment());
      _thisCompleter.complete(_getSchemaFromPath(Uri.parse('#')));
    }
  }

  /// Check for refs that need to be fetched, fetch them, and return the final [JsonSchema].
  void _resolveAllPathsSync() {
    if (_root == this) {
      // If a ref provider is specified, use it and remove the corresponding retrieval request if
      // the provider returns a result.
      if (_refProvider != null) {
        while (_retrievalRequests.isNotEmpty) {
          final r = _retrievalRequests.removeAt(0);
          r.syncRetrievalOperation!();
        }
      }

      _schemaAssignments.forEach((assignment) => assignment());

      // Throw an error if there are any remaining retrieval requests the ref provider couldn't resolve.
      if (_retrievalRequests.isNotEmpty) {
        throw FormatExceptions.error(
            'When resolving schemas synchronously, all remote refs must be resolvable via a RefProvider. Found ${_retrievalRequests.length} unresolvable request(s): ${_retrievalRequests.map((r) => r.schemaUri).join(',')}');
      }
    }
  }

  void _validateSchemaBase() {
    _validateAndSetAllProperties();
  }

  /// Validate that a given [JsonSchema] conforms to the official JSON Schema spec.
  void _validateSchemaAsync() {
    _validateSchemaBase();
    _baseResolvePaths();
    _resolveAllPathsAsync();
  }

  /// Validate that a given [JsonSchema] conforms to the official JSON Schema spec.
  void _validateSchemaSync() {
    _validateSchemaBase();
    _baseResolvePaths();
    _resolveAllPathsSync();
  }

  void _resolveMetaSchemasForVocabulary(String? schemaString, SchemaVersion? schemaVersion) {
    final root = _root;
    if (root == null || root._metaSchemaCompleter.isCompleted) {
      return;
    }
    if (schemaVersion != null && schemaVersion >= SchemaVersion.draft2019_09) {
      final baseUri = Uri.parse(schemaString ?? schemaVersion.toString());
      if (root._isSync) {
        _resolveMetaSchemasSync(baseUri);
        root._metaSchemaCompleter.complete();
      } else {
        _resolveMetaSchemasAsync(baseUri);
      }
    } else {
      root._metaSchemaCompleter.complete();
    }
  }

  void _resolveMetaSchemasSync(Uri baseUri) {
    final Map<String, dynamic>? staticSchema = getStaticSchemaByURI(baseUri) ??
        _refProvider?.provide(baseUri.toString()) ??
        _refProvider?.provide('${baseUri}#');

    if (staticSchema?.containsKey(r'$vocabulary') == true) {
      _setMetaschemaVocabulary(staticSchema![r'$vocabulary']);
    }
  }

  void _resolveMetaSchemasAsync(Uri baseUri) async {
    final refProvider = _refProvider ?? defaultUrlRefProvider;
    final Map<String, dynamic>? staticSchema = getStaticSchemaByURI(baseUri) as Map<String, dynamic>? ??
        await refProvider.provide(baseUri.toString()) ??
        await refProvider.provide('${baseUri}#');

    if (staticSchema?.containsKey(r'$vocabulary') == true) {
      try {
        _setMetaschemaVocabulary(staticSchema![r'$vocabulary']);
      } catch (e) {
        _root?._metaSchemaCompleter.completeError(e);
        return;
      }
    }

    _root?._metaSchemaCompleter.complete();
  }

  /// Given a [Uri] path, find the ref'd [JsonSchema] from the map.
  JsonSchema _getSchemaFromPath(Uri? pathUri, [Set<Uri?>? refsEncountered]) {
    // Store encountered refs to avoid cycles.
    refsEncountered ??= {};

    final currentPair = SchemaPathPair(this, pathUri);
    final memomizedResult = _memomizedResults?[currentPair];
    if (memomizedResult != null) {
      return memomizedResult;
    }

    Uri basePathUri;
    if (pathUri!.host.isEmpty && pathUri.path.isEmpty && (_uri != null || _inheritedUri != null)) {
      // Prepend _uri or _inheritedUri to provided [Uri] path if no host or path detected.
      pathUri = _translateLocalRefToFullUri(pathUri);
    }

    // basePathUri should always have an empty fragment.
    basePathUri = Uri.parse('${pathUri.removeFragment()}#');

    // If _refMap already contains the full pathUri, return the ref'd JsonSchema.
    final refMapResult = _refMap[pathUri.toString()];
    if (refMapResult != null) {
      return refMapResult;
    }

    JsonSchema baseSchema;
    final basePathUriResult = _refMap[basePathUri.toString()];
    if (basePathUriResult != null) {
      // Pull the baseSchema from the _refMap
      baseSchema = basePathUriResult;
    } else {
      // If the _refMap does not contain basePathUri, the ref was never resolved during validation.
      throw ArgumentError(
          'Failed to get schema for path because the schema file ($basePathUri) could not be found. Unable to resolve path $pathUri');
    }

    // Follow JSON Pointer path of fragments if provided.
    if (pathUri.fragment.isNotEmpty) {
      final List<String> fragments = Uri.parse(pathUri.fragment).pathSegments;
      final foundSchema = _recursiveResolvePath(pathUri, fragments, baseSchema, refsEncountered);
      if (foundSchema != null) {
        _memomizedResults?[currentPair] = foundSchema;
        return foundSchema;
      }
    }

    // No fragments present, return the successfully resolved base schema.
    return baseSchema;
  }

  // When there are 2 possible path to be resolve, traverse both paths.
  JsonSchema _resolveParallelPaths(
    Uri? pathUri, // The path being resolved
    List<String> fragments, // A slice of fragments being traversed.
    JsonSchema schemaWithRef, // A JsonSchema containing a ref.
    Set<Uri?> refsEncountered, // Refs encountered from schemaWithRef
  ) {
    if (schemaWithRef.ref == null) {
      throw ArgumentError("Expected schemaWithRef to contain a ref");
    }
    // Store refs encountered for the other branch.
    var preRefsEncountered = Set.of(refsEncountered);
    var resolvedRefsEncountered = Set.of(refsEncountered);
    var resolvedSchema = _resolveSchemaWithAccounting(pathUri, schemaWithRef, resolvedRefsEncountered);

    JsonSchema? firstResult;
    JsonSchema? secondResult;
    dynamic firstError;
    // ignore: unused_local_variable
    dynamic secondError;
    try {
      firstResult = _recursiveResolvePath(
        pathUri,
        fragments,
        schemaWithRef,
        preRefsEncountered,
        skipInitialRefCheck:
            true, // Check the other properties, no the ref. No need to check it again and have an infinite loop.
      );
    } catch (e) {
      firstError = e;
    }
    try {
      secondResult = _recursiveResolvePath(
        pathUri,
        fragments,
        resolvedSchema,
        resolvedRefsEncountered,
      );
    } catch (e) {
      secondError = e;
    }
    // Both paths errored out.
    if (firstResult == null && secondResult == null) {
      throw firstError; // Is there a nice way to combine errors?
      // Both paths ended up an the same JSON Schema object.
    } else if (firstResult == secondResult) {
      return firstResult!;
      // Both paths returned different JsonSchema objects.
    } else if (firstResult != null && secondResult != null) {
      throw Exception("Ambiguous paths detected");
    } else if (firstResult != null) {
      refsEncountered.addAll(preRefsEncountered);
      return firstResult;
    } else if (secondResult != null) {
      refsEncountered.addAll(resolvedRefsEncountered);
      return secondResult;
    }
    // This line should never be reached.
    throw StateError("Error resolving parallel paths");
  }

  JsonSchema? _recursiveResolvePath(
      Uri? pathUri, List<String> fragments, JsonSchema? baseSchema, Set<Uri?> refsEncountered,
      {bool skipInitialRefCheck = false}) {
    // Set of properties that are ignored when set beside a `$ref`.
    final Set<String> consts = Set.of([r'$id', r'$schema', r'$comment']);
    if (fragments.isNotEmpty) {
      // Start at the baseSchema.
      JsonSchema? currentSchema = baseSchema;

      // If currentSchema is a ref, try resolving before looping over the fragments start.
      // There is a very similar check at  the end of the fragment loop.
      if (currentSchema?.ref != null && !refsEncountered.contains(currentSchema!.ref) && !skipInitialRefCheck) {
        // If currentSchema has additional values, then traverse both paths to find the result.
        if (currentSchema._schemaMap!.keys.toSet().difference(consts).length > 1) {
          return _resolveParallelPaths(pathUri, fragments, currentSchema, refsEncountered);
        }
        currentSchema = _resolveSchemaWithAccounting(pathUri, currentSchema, refsEncountered);
      }

      // Iterate through supported keywords or custom properties.
      for (int i = 0; i < fragments.length; i++) {
        final String fragment = fragments[i];

        /// Fetch the property getter from the [_baseAccessGetterMap].
        final SchemaPropertyGetter? accessor = _baseAccessGetterMap[fragment];
        if (accessor != null && currentSchema != null) {
          // Get the property off the current schema.
          final schemaValues = accessor(currentSchema);
          if (schemaValues is JsonSchema) {
            // Continue iteration if result is a valid schema.
            currentSchema = schemaValues;
          } else if (schemaValues is Map<String, JsonSchema>) {
            // Map properties use the following fragment to fetch the value by key.
            i += 1;
            String propertyKey = fragments[i];
            if (schemaValues[propertyKey] is! JsonSchema) {
              try {
                propertyKey = Uri.decodeQueryComponent(propertyKey);
                // Create a JSON Pointer with one segment from the current key.
                // (This will throw a FormatException if invalid, and not be unescaped)
                JsonPointer('/$propertyKey');
                propertyKey = JsonSchemaUtils.unescapeJsonPointerToken(propertyKey);
              } on FormatException catch (_) {
                // Fall back to original propertyKey if it can't be unescaped.
              }
            }
            currentSchema = schemaValues[propertyKey];

            // Fetched properties must be valid schemas.
            if (currentSchema is! JsonSchema) {
              throw FormatException(
                  'Failed to get schema at path: "$fragment/$propertyKey". Property must be a valid schema : $currentSchema');
            }
          } else if (schemaValues is List<JsonSchema>) {
            // List properties use the following fragment to fetch the value by index.
            i += 1;
            final String propertyIndex = fragments[i];
            try {
              final int schemaIndex = int.parse(propertyIndex);
              currentSchema = schemaValues[schemaIndex];
            } catch (e) {
              throw FormatException(
                  'Failed to get schema at path: "$fragment/$propertyIndex". Unable to resolve index.');
            }
          }
        } else {
          // Fragment might be a custom property, pull from _refMap and throw if result is not a valid JsonSchema.

          // If the currentSchema does not have a _uri set from refProvider, check _refMap for fragment only.
          String currentSchemaRefPath = pathUri.toString();
          if (currentSchema?._uri == null && currentSchema?._inheritedUri == null) {
            currentSchemaRefPath = '#${pathUri!.fragment}';
          }
          currentSchema = currentSchema?._refMap[currentSchemaRefPath];
          if (currentSchema is! JsonSchema) {
            throw FormatException(
                'Failed to get schema at path: "$fragment". Custom property must be a valid schema, but got : $currentSchema');
          }
        }

        // If currentSchema contains a ref, try resolving it.
        // There is a very similar check before the fragment loop starts.
        if (currentSchema.ref != null) {
          // If we are at the end of the fragments to search and there are additional properties in the schema,
          // continue here so the currentSchema will be returned.
          if (i + 1 == fragments.length &&
              (currentSchema._schemaMap?.keys.toSet().difference(consts).length ?? 0) > 1) {
            continue;
          }
          // If currentSchema has additional values, then traverse both paths to find the result.
          if (i + 1 < fragments.length && (currentSchema._schemaMap?.keys.toSet().difference(consts).length ?? 0) > 1) {
            return _resolveParallelPaths(
                pathUri, fragments.sublist(i + 1, fragments.length), currentSchema, refsEncountered);
          }

          currentSchema = _resolveSchemaWithAccounting(pathUri, currentSchema, refsEncountered);
        }
      }
      // Return the successfully resolved schema from fragment path.
      return currentSchema;
    }
    return baseSchema;
  }

  // Not to be confused with _getSchemaFromPath! This one throws exceptions and track if a ref has been seen before.
  JsonSchema _resolveSchemaWithAccounting(Uri? pathUri, JsonSchema schema, Set<Uri?> refsEncountered) {
    if (!refsEncountered.add(schema.ref)) {
      // Throw if cycle is detected for currentSchema ref.
      throw FormatException('Failed to get schema at path: "${schema.ref}". Cycle detected.');
    }

    JsonSchema? resolvedSchema = schema._getSchemaFromPath(schema.ref, refsEncountered);

    return resolvedSchema;
  }

  /// Look for the given anchor at the schema. Returns null if nothing is found.
  JsonSchema? _resolveDynamicAnchor(String dynamicAnchor, JsonSchema? schema) {
    if (schema == null) {
      schema = this;
    }
    if (schema.schemaVersion < SchemaVersion.draft2020_12) {
      return null;
    }
    // IDs in draft2019 and up do not have fragments.
    var ref = Uri.parse("${schema.id.toString()}#$dynamicAnchor").toString();
    if (_refMap.containsKey(ref)) {
      var anchorPoint = _refMap[ref]!;
      if (anchorPoint.dynamicAnchor == dynamicAnchor) {
        return anchorPoint;
      }
    }
    return null;
  }

  /// Create a sub-schema inside the root, using either a directly nested schema, or a definition.
  JsonSchema _createSubSchema(Object? schemaDefinition, String path) {
    if (schemaDefinition is Map) {
      return JsonSchema._fromMap(_root, schemaDefinition, path, parent: this);

      // Boolean schemas are only supported in draft 6 and later.
    } else if (schemaDefinition is bool && schemaVersion >= SchemaVersion.draft6) {
      return JsonSchema._fromBool(_root, schemaDefinition, path, parent: this);
    }
    throw ArgumentError(
        'Data provided to createSubSchema is not valid: Must be a Map (or bool in draft6 or later). | ${schemaDefinition}');
  }

  JsonSchema? _fetchRefSchemaFromSyncProvider(Uri ref) {
    // Always check refMap first.
    if (_refMap.containsKey(ref.toString())) {
      return _refMap[ref.toString()];
    }

    final Uri baseUri = ref.removeFragment();

    // Fallback order for ref provider:
    // 1. Statically-known schema definition (skips ref provider)
    // 2. Base URI (example: localhost:1234/integer.json)
    // 3. Base URI with empty fragment (example: localhost:1234/integer.json#)
    final Map<String, dynamic>? schemaDefinition = getStaticSchemaByURI(ref) as Map<String, dynamic>? ??
        _refProvider?.provide(baseUri.toString()) ??
        _refProvider?.provide('${baseUri}#');

    return _createAndResolveProvidedSchema(ref, schemaDefinition);
  }

  Future<JsonSchema?> _fetchRefSchemaFromAsyncProvider(Uri? ref, {RefProvider? refProvider}) async {
    // Always check refMap first.
    if (_refMap.containsKey(ref.toString())) {
      return _refMap[ref.toString()];
    }

    final Uri baseUri = ref!.removeFragment();

    refProvider ??= _refProvider;

    // Fallback order for ref provider:
    // 1. Statically-known schema definition (skips ref provider)
    // 2. Base URI (example: localhost:1234/integer.json)
    // 3. Base URI with empty fragment (example: localhost:1234/integer.json#)
    final dynamic schemaDefinition = getStaticSchemaByURI(ref) ??
        await refProvider!.provide(baseUri.toString()) ??
        await refProvider!.provide('${baseUri}#');

    return _createAndResolveProvidedSchema(ref, schemaDefinition);
  }

  JsonSchema? _createAndResolveProvidedSchema(Uri ref, dynamic schemaDefinition) {
    final Uri baseUri = ref.removeFragment();

    JsonSchema? baseSchema;
    if (schemaDefinition is JsonSchema) {
      // Provider gave validated schema.
      baseSchema = schemaDefinition;
    } else if (schemaDefinition is Map) {
      // Provider gave a schema object.
      baseSchema = JsonSchema._fromRootMap(
        schemaDefinition,
        schemaVersion,
        isSync: _isSync,
        refMap: _refMap,
        refProvider: _refProvider,
        fetchedFromUri: baseUri,
        metaschemaVocabulary: _root?._metaschemaVocabulary,
        customVocabMap: _root?._customVocabMap,
        customFormats: _root?._customFormats ?? {},
      );
      _addSchemaToRefMap(baseSchema._uri.toString(), baseSchema);
    } else if (schemaDefinition is bool && schemaVersion >= SchemaVersion.draft6) {
      baseSchema = JsonSchema._fromRootBool(
        schemaDefinition,
        schemaVersion,
        isSync: _isSync,
        refMap: _refMap,
        refProvider: _refProvider,
        fetchedFromUri: baseUri,
        metaschemaVocabulary: _root?._metaschemaVocabulary,
        customVocabMap: _root?._customVocabMap,
        customFormats: _root?._customFormats ?? {},
      );
      _addSchemaToRefMap(baseSchema._uri.toString(), baseSchema);
    }

    if (baseSchema != null && ref.hasFragment && ref.fragment.isNotEmpty) {
      // Resolve fragment if provided.
      return baseSchema.resolvePath(Uri.parse('#${ref.fragment}'));
    }

    // Return base schema or null if no fragment present.
    return baseSchema;
  }

  // --------------------------------------------------------------------------
  // Root Schema Fields
  // --------------------------------------------------------------------------

  /// The root [JsonSchema] for this [JsonSchema].
  JsonSchema? _root;

  /// The parent [JsonSchema] for this [JsonSchema].
  JsonSchema? _parent;

  /// JSON of the [JsonSchema] as a [Map]. Only this value or [_schemaBool] should be set, not both.
  final Map<String, dynamic>? _schemaMap;

  /// JSON of the [JsonSchema] as a [bool]. Only this value or [_schemaMap] should be set, not both.
  final bool? _schemaBool;

  /// JSON Schema version string.
  SchemaVersion? _schemaVersion;

  /// Remote [Uri] the [JsonSchema] was fetched from, if any.
  Uri? _fetchedFromUri;

  /// Base of the remote [Uri] the [JsonSchema] was fetched from, if any.
  Uri? _fetchedFromUriBase;

  /// A [List<JsonSchema>] which the value must conform to all of.
  List<JsonSchema> _allOf = [];

  /// A [List<JsonSchema>] which the value must conform to at least one of.
  List<JsonSchema> _anyOf = [];

  /// Whether or not const is set, we need this since const can be null and valid.
  bool _hasConst = false;

  /// A value which the [JsonSchema] instance must exactly conform to.
  dynamic _constValue;

  /// Default value of the [JsonSchema].
  dynamic _defaultValue;

  /// Included [JsonSchema] definitions.
  Map<String, JsonSchema> _definitions = {};

  /// Included [JsonSchema] $defs.
  Map<String, JsonSchema> _defs = {};

  /// Whether the [JsonSchema] is deprecated.
  bool? _deprecated;

  /// Description of the [JsonSchema].
  String? _description;

  /// Comment on the [JsonSchema] for schema maintainers.
  String? _comment;

  /// Content Media Type.
  String? _contentMediaType;

  /// Content Encoding.
  String? _contentEncoding;

  /// Content Schema.
  String? _contentSchema;

  /// A [JsonSchema] used for validataion if the schema doesn't validate against the 'if' schema.
  JsonSchema? _elseSchema;

  /// Possible values of the [JsonSchema].
  List? _enumValues = [];

  /// Example values for the given schema.
  List _examples = [];

  /// Whether the maximum of the [JsonSchema] is exclusive.
  bool? _exclusiveMaximum;

  /// Whether the maximum of the [JsonSchema] is exclusive.
  num? _exclusiveMaximumV6;

  /// Whether the minumum of the [JsonSchema] is exclusive.
  bool? _exclusiveMinimum;

  /// Whether the minumum of the [JsonSchema] is exclusive.
  num? _exclusiveMinimumV6;

  /// Pre-defined format (i.e. date-time, email, etc) of the [JsonSchema] value.
  String? _format;

  /// ID of the [JsonSchema].
  Uri? _id;

  /// Metaschema id of the [JsonSchema].
  Uri? _schema;

  /// Base URI of the ID. All sub-schemas are resolved against this
  Uri? _idBase;

  /// An identifier for a subschema.
  String? _anchor;

  /// An identifier for a subschema.
  String? _dynamicAnchor;

  /// A [JsonSchema] that conditionally decides if validation should be performed against the 'then' or 'else' schema.
  JsonSchema? _ifSchema;

  /// Maximum value of the [JsonSchema] value.
  num? _maximum;

  /// Minimum value of the [JsonSchema] value.
  num? _minimum;

  /// Maximum value of the [JsonSchema] value.
  int? _maxLength;

  /// Minimum length of the [JsonSchema] value.
  int? _minLength;

  /// The number which the value of the [JsonSchema] must be a multiple of.
  num? _multipleOf;

  /// A [JsonSchema] which the value must NOT be.
  JsonSchema? _notSchema;

  /// A [List<JsonSchema>] which the value must conform to at least one of.
  List<JsonSchema> _oneOf = [];

  /// The regular expression the [JsonSchema] value must conform to.
  RegExp? _pattern;

  /// Whether the schema is read-only.
  bool _readOnly = false;

  /// Ref to the URI of the [JsonSchema].
  Uri? _ref;

  /// Whether the [JsonSchema] is an anchor point for recursive references.
  bool? _recursiveAnchor;

  /// RecursiveRef to the Uri of the [JsonSchema].
  Uri? _recursiveRef;

  /// DynamicRef to the Uri of the [JsonSchema].
  Uri? _dynamicRef;

  /// A [JsonSchema] used for validation if the schema also validates against the 'if' schema.
  JsonSchema? _thenSchema;

  /// The path of the [JsonSchema] within the root [JsonSchema].
  String? _path;

  /// Title of the [JsonSchema].
  String? _title;

  /// List of allowable types for the [JsonSchema].
  List<SchemaType?>? _typeList;

  /// Whether the schema is write-only.
  bool _writeOnly = false;

  // For current metaschemas, indicates the vocabularies in use and the requiredness of each for processing schemas.
  Map<Uri, bool>? _vocabulary;

  // For the current schema. Indicates the vocabularies in use and the requiredness of each for processing schemas.
  Map<Uri, bool>? _metaschemaVocabulary;

  // --------------------------------------------------------------------------
  // Schema List Item Related Fields
  // --------------------------------------------------------------------------

  /// [JsonSchema] definition used to validate items of this schema.
  JsonSchema? _items;

  /// List of [JsonSchema] used to validate items of this schema.
  List<JsonSchema>? _itemsList;

  List<JsonSchema>? _prefixItems;

  /// Whether additional items are allowed.
  bool? _additionalItemsBool;

  /// [JsonSchema] additionalItems should conform to.
  JsonSchema? _additionalItemsSchema;

  /// [JsonSchema] definition that at least one item must match to be valid.
  JsonSchema? _contains;

  /// Minimum number of [_contains] required.
  int? _minContains;

  /// Maximum number of [_contains] allowed
  int? _maxContains;

  /// Maximum number of items allowed.
  int? _maxItems;

  /// Minimum number of items allowed.
  int? _minItems;

  /// Whether the items in the list must be unique.
  bool _uniqueItems = false;

  // --------------------------------------------------------------------------
  // Schema Sub-Property Related Fields
  // --------------------------------------------------------------------------

  /// Map of [JsonSchema]s by property key.
  Map<String, JsonSchema> _properties = {};

  /// [JsonSchema] that property names must conform to.
  JsonSchema? _propertyNamesSchema;

  /// Whether additional properties, other than those specified, are allowed.
  bool? _additionalProperties;

  /// [JsonSchema] that additional properties must conform to.
  JsonSchema? _additionalPropertiesSchema;

  Map<String, List<String>> _propertyDependencies = {};

  Map<String, JsonSchema> _schemaDependencies = {};

  /// [JsonSchema] that unevaluated properties must conform to.
  JsonSchema? _unevaluatedProperties;

  /// The maximum number of properties allowed.
  int? _maxProperties;

  /// The minimum number of properties allowed.
  int _minProperties = 0;

  /// Map of [JsonSchema]s for properties, based on [RegExp]s keys.
  Map<RegExp, JsonSchema> _patternProperties = {};

  /// Map of sub-properties' and references' [JsonSchema]s by path.
  Map<String, JsonSchema> _refMap = {};

  /// List if properties that are required for the [JsonSchema] instance to be valid.
  List<String>? _requiredProperties;

  /// [JsonSchema] for dealing with items in a list that have not been evaluated by other schemas.
  JsonSchema? _unevaluatedItems;

  // --------------------------------------------------------------------------
  // Implementation Specific Fields
  // --------------------------------------------------------------------------

  int? _hashCode;

  /// Set of local ref Uris to validate during ref resolution.
  Set<Uri?> _localRefs = Set<Uri?>();

  /// HTTP(S) requests to fetch ref'd schemas.
  List<RetrievalRequest> _retrievalRequests = [];

  /// Remote ref assignments that need to wait until RetrievalRequests have been resolved to execute.
  ///
  /// The assignments themselves can be thought of as a callback dependent on a Future<RetrievalRequest>.
  List _schemaAssignments = [];

  /// Completer that fires when [this] [JsonSchema] has finished building.
  Completer<JsonSchema> _thisCompleter = Completer<JsonSchema>();
  Completer<void> _metaSchemaCompleter = Completer<void>();

  bool _isSync = false;

  /// Ref provider object used to resolve remote references in a given [JsonSchema].
  ///
  /// If [isSync] is true, the provider will be used to fetch remote refs.
  /// If [isSync] is false, the provider will be used if specified, otherwise the default HTTP(S) ref provider will be used.
  // ignore: deprecated_member_use_from_same_package
  /// If provider type is [RefProviderType.schema], fully resolved + validated schemas are expected from the provider.
  /// If provider type is [RefProviderType.json], the provider expects valid JSON objects from the provider.
  RefProvider? _refProvider;

  /// Store results for looking up paths in a jsonSchema. Helps performance and bogus cycle detection.
  Map<SchemaPathPair, JsonSchema>? _rootMemomizedPathResults;

  static Map<String, SchemaPropertyGetter> _baseAccessGetterMap = {
    r'$defs': (JsonSchema s) => s.defs,
    'definitions': (JsonSchema s) => s.definitions,
    'properties': (JsonSchema s) => s.properties,
    'items': (JsonSchema s) => s.items ?? s.itemsList ?? [],
    'prefixItems': (JsonSchema s) => s.prefixItems ?? [],
  };

  /// Shared keywords across all versions of JSON Schema.
  static Map<String, SchemaPropertySetter> _baseAccessMap = {
    // Root Schema Properties
    'allOf': (JsonSchema s, dynamic v) => s._setAllOf(v),
    'anyOf': (JsonSchema s, dynamic v) => s._setAnyOf(v),
    'default': (JsonSchema s, dynamic v) => s._setDefault(v),
    'definitions': (JsonSchema s, dynamic v) => s._setDefinitions(v),
    'description': (JsonSchema s, dynamic v) => s._setDescription(v),
    'enum': (JsonSchema s, dynamic v) => s._setEnum(v),
    'format': (JsonSchema s, dynamic v) => s._setFormat(v),
    'maximum': (JsonSchema s, dynamic v) => s._setMaximum(v),
    'minimum': (JsonSchema s, dynamic v) => s._setMinimum(v),
    'maxLength': (JsonSchema s, dynamic v) => s._setMaxLength(v),
    'minLength': (JsonSchema s, dynamic v) => s._setMinLength(v),
    'multipleOf': (JsonSchema s, dynamic v) => s._setMultipleOf(v),
    'not': (JsonSchema s, dynamic v) => s._setNot(v),
    'oneOf': (JsonSchema s, dynamic v) => s._setOneOf(v),
    'pattern': (JsonSchema s, dynamic v) => s._setPattern(v),
    '\$ref': (JsonSchema s, dynamic v) => s._setRef(v),
    'title': (JsonSchema s, dynamic v) => s._setTitle(v),
    'type': (JsonSchema s, dynamic v) => s._setType(v),
    // Schema List Item Related Fields
    'items': (JsonSchema s, dynamic v) => s._setItems(v),
    'additionalItems': (JsonSchema s, dynamic v) => s._setAdditionalItems(v),
    'maxItems': (JsonSchema s, dynamic v) => s._setMaxItems(v),
    'minItems': (JsonSchema s, dynamic v) => s._setMinItems(v),
    'uniqueItems': (JsonSchema s, dynamic v) => s._setUniqueItems(v),
    // Schema Sub-Property Related Fields
    'properties': (JsonSchema s, dynamic v) => s._setProperties(v),
    'additionalProperties': (JsonSchema s, dynamic v) => s._setAdditionalProperties(v),
    'dependencies': (JsonSchema s, dynamic v) => s._setDependencies(v),
    'maxProperties': (JsonSchema s, dynamic v) => s._setMaxProperties(v),
    'minProperties': (JsonSchema s, dynamic v) => s._setMinProperties(v),
    'patternProperties': (JsonSchema s, dynamic v) => s._setPatternProperties(v),
    r'$schema': (JsonSchema s, dynamic v) => s._setSchema(v),
  };

  /// Map to allow getters to be accessed by String key.
  static Map<String, SchemaPropertySetter> _accessMapV4 = Map<String, SchemaPropertySetter>()
    ..addAll(_baseAccessMap)
    ..addAll({
      // Add properties that are changed incompatibly later.
      'exclusiveMaximum': (JsonSchema s, dynamic v) => s._setExclusiveMaximum(v),
      'exclusiveMinimum': (JsonSchema s, dynamic v) => s._setExclusiveMinimum(v),
      'id': (JsonSchema s, dynamic v) => s._setId(v),
      'required': (JsonSchema s, dynamic v) => s._setRequired(v),
    });

  static Map<String, SchemaPropertySetter> _accessMapV6 = Map<String, SchemaPropertySetter>()
    ..addAll(_baseAccessMap)
    ..addAll({
      // Note: see https://json-schema.org/draft-06/json-schema-release-notes.html

      // Added in draft6
      'const': (JsonSchema s, dynamic v) => s._setConst(v),
      'contains': (JsonSchema s, dynamic v) => s._setContains(v),
      'examples': (JsonSchema s, dynamic v) => s._setExamples(v),
      'propertyNames': (JsonSchema s, dynamic v) => s._setPropertyNames(v),
      // changed (incompatible) in draft6
      'exclusiveMaximum': (JsonSchema s, dynamic v) => s._setExclusiveMaximumV6(v),
      'exclusiveMinimum': (JsonSchema s, dynamic v) => s._setExclusiveMinimumV6(v),
      r'$id': (JsonSchema s, dynamic v) => s._setId(v),
      'required': (JsonSchema s, dynamic v) => s._setRequiredV6(v),
    });

  static Map<String, SchemaPropertySetter> _accessMapV7 = Map<String, SchemaPropertySetter>()
    ..addAll(_baseAccessMap)
    ..addAll(_accessMapV6)
    ..addAll({
      // Note: see https://json-schema.org/draft-07/json-schema-release-notes.html

      // Added in draft7
      r'$comment': (JsonSchema s, dynamic v) => s._setComment(v),
      'if': (JsonSchema s, dynamic v) => s._setIf(v),
      'then': (JsonSchema s, dynamic v) => s._setThen(v),
      'else': (JsonSchema s, dynamic v) => s._setElse(v),
      'readOnly': (JsonSchema s, dynamic v) => s._setReadOnly(v),
      'writeOnly': (JsonSchema s, dynamic v) => s._setWriteOnly(v),
      'contentMediaType': (JsonSchema s, dynamic v) => s._setContentMediaType(v),
      'contentEncoding': (JsonSchema s, dynamic v) => s._setContentEncoding(v),
    });

  static Map<String, SchemaPropertySetter> _draft2019_core = Map<String, SchemaPropertySetter>()
    ..addAll({
      r'$id': (JsonSchema s, dynamic v) => s._setId(v),
      r'$schema': (JsonSchema s, Object? v) => s._setSchema(v),
      r'$anchor': (JsonSchema s, dynamic v) => s._setAnchor(v),
      r'$ref': (JsonSchema s, dynamic v) => s._setRef(v),
      r'$recursiveRef': (JsonSchema s, dynamic v) => s._setRecursiveRef(v),
      r'$recursiveAnchor': (JsonSchema s, dynamic v) => s._setRecursiveAnchor(v),
      r'$vocabulary': (JsonSchema s, dynamic v) => s._setVocabulary(v),
      r'$comment': (JsonSchema s, dynamic v) => s._setComment(v),
      r'$defs': (JsonSchema s, dynamic v) => s._setDefs(v),
    });
  static Map<String, SchemaPropertySetter> _draft2019_applicator = Map<String, SchemaPropertySetter>()
    ..addAll({
      'additionalItems': (JsonSchema s, dynamic v) => s._setAdditionalItems(v),
      'unevaluatedItems': (JsonSchema s, dynamic v) => s._setUnevaluatedItems(v),
      'items': (JsonSchema s, dynamic v) => s._setItems(v),
      'contains': (JsonSchema s, dynamic v) => s._setContains(v),
      'additionalProperties': (JsonSchema s, dynamic v) => s._setAdditionalProperties(v),
      'unevaluatedProperties': (JsonSchema s, dynamic v) => s._setUnevaluatedProperties(v),
      'properties': (JsonSchema s, dynamic v) => s._setProperties(v),
      'patternProperties': (JsonSchema s, dynamic v) => s._setPatternProperties(v),
      'dependentSchemas': (JsonSchema s, dynamic v) => s._setDependentSchemas(v),
      'propertyNames': (JsonSchema s, dynamic v) => s._setPropertyNames(v),
      'if': (JsonSchema s, dynamic v) => s._setIf(v),
      'then': (JsonSchema s, dynamic v) => s._setThen(v),
      'else': (JsonSchema s, dynamic v) => s._setElse(v),
      'allOf': (JsonSchema s, dynamic v) => s._setAllOf(v),
      'anyOf': (JsonSchema s, dynamic v) => s._setAnyOf(v),
      'oneOf': (JsonSchema s, dynamic v) => s._setOneOf(v),
      'not': (JsonSchema s, dynamic v) => s._setNot(v)
    });

  static Map<String, SchemaPropertySetter> _draft2019_content = Map<String, SchemaPropertySetter>()
    ..addAll({
      'contentMediaType': (JsonSchema s, dynamic v) => s._setContentMediaType(v),
      'contentEncoding': (JsonSchema s, dynamic v) => s._setContentEncoding(v),
      'contentSchema': (JsonSchema s, dynamic v) => s._setContentSchema(v)
    });

  static Map<String, SchemaPropertySetter> _draft2019_format = Map<String, SchemaPropertySetter>()
    ..addAll({'format': (JsonSchema s, dynamic v) => s._setFormat(v)});

  static Map<String, SchemaPropertySetter> _draft2019_metadata = Map<String, SchemaPropertySetter>()
    ..addAll({
      'title': (JsonSchema s, dynamic v) => s._setTitle(v),
      'description': (JsonSchema s, dynamic v) => s._setDescription(v),
      'default': (JsonSchema s, dynamic v) => s._setDefault(v),
      'deprecated': (JsonSchema s, dynamic v) => s._setDeprecated(v),
      'readOnly': (JsonSchema s, dynamic v) => s._setReadOnly(v),
      'writeOnly': (JsonSchema s, dynamic v) => s._setWriteOnly(v),
      'examples': (JsonSchema s, dynamic v) => s._setExamples(v)
    });

  static Map<String, SchemaPropertySetter> _draft2019_validation = Map<String, SchemaPropertySetter>()
    ..addAll({
      'multipleOf': (JsonSchema s, dynamic v) => s._setMultipleOf(v),
      'maximum': (JsonSchema s, dynamic v) => s._setMaximum(v),
      'exclusiveMaximum': (JsonSchema s, dynamic v) => s._setExclusiveMaximumV6(v),
      'minimum': (JsonSchema s, dynamic v) => s._setMinimum(v),
      'exclusiveMinimum': (JsonSchema s, dynamic v) => s._setExclusiveMinimumV6(v),
      'maxLength': (JsonSchema s, dynamic v) => s._setMaxLength(v),
      'minLength': (JsonSchema s, dynamic v) => s._setMinLength(v),
      'pattern': (JsonSchema s, dynamic v) => s._setPattern(v),
      'maxItems': (JsonSchema s, dynamic v) => s._setMaxItems(v),
      'minItems': (JsonSchema s, dynamic v) => s._setMinItems(v),
      'uniqueItems': (JsonSchema s, dynamic v) => s._setUniqueItems(v),
      'maxContains': (JsonSchema s, dynamic v) => s._setMaxContains(v),
      'minContains': (JsonSchema s, dynamic v) => s._setMinContains(v),
      'maxProperties': (JsonSchema s, dynamic v) => s._setMaxProperties(v),
      'minProperties': (JsonSchema s, dynamic v) => s._setMinProperties(v),
      'required': (JsonSchema s, dynamic v) => s._setRequiredV6(v),
      'dependentRequired': (JsonSchema s, dynamic v) => s._setDependentRequired(v),
      'const': (JsonSchema s, dynamic v) => s._setConst(v),
      'enum': (JsonSchema s, dynamic v) => s._setEnum(v),
      'type': (JsonSchema s, dynamic v) => s._setType(v)
    });

  static Map<String, Map<String, SchemaPropertySetter>> _draft2019VocabMap = Map()
    ..addAll({
      "https://json-schema.org/draft/2019-09/vocab/core": _draft2019_core,
      "https://json-schema.org/draft/2019-09/vocab/applicator": _draft2019_applicator,
      "https://json-schema.org/draft/2019-09/vocab/validation": _draft2019_validation,
      "https://json-schema.org/draft/2019-09/vocab/meta-data": _draft2019_metadata,
      "https://json-schema.org/draft/2019-09/vocab/format": _draft2019_format,
      "https://json-schema.org/draft/2019-09/vocab/content": _draft2019_content
    });

  static Map<String, SchemaPropertySetter> _draft2020_core = Map<String, SchemaPropertySetter>()
    ..addAll(_draft2019_core)
    ..addAll({
      r'$dynamicRef': (JsonSchema s, dynamic v) => s._setDynamicRef(v),
      r'$dynamicAnchor': (JsonSchema s, dynamic v) => s._setDynamicAnchor(v),
    });

  static Map<String, SchemaPropertySetter> _draft2020_applicator = Map<String, SchemaPropertySetter>()
    ..addAll(_draft2019_applicator)
    ..remove('unevaluatedItems')
    ..remove('unevaluatedProperties')
    ..addAll({
      'prefixItems': (JsonSchema s, dynamic v) => s._setPrefixItems(v),
      'items': (JsonSchema s, dynamic v) => s._setItemsDraft2020(v),
    });

  static Map<String, SchemaPropertySetter> _draft2020_unevaluated = Map<String, SchemaPropertySetter>()
    ..addAll({
      'unevaluatedItems': (JsonSchema s, dynamic v) => s._setUnevaluatedItems(v),
      'unevaluatedProperties': (JsonSchema s, dynamic v) => s._setUnevaluatedProperties(v),
    });

  static Map<String, SchemaPropertySetter> _draft2020_validation = Map<String, SchemaPropertySetter>()
    ..addAll(_draft2019_validation);

  static Map<String, SchemaPropertySetter> _draft2020_format_annotation = Map<String, SchemaPropertySetter>()
    ..addAll({'format': (JsonSchema s, dynamic v) => s._setFormat(v)});

  // Not used in the draft 2020, but including for completeness and potential future vocabulary useage.
  static Map<String, SchemaPropertySetter> _draft2020_format_assertion = Map<String, SchemaPropertySetter>()
    ..addAll({'format': (JsonSchema s, dynamic v) => s._setFormat(v)});

  static Map<String, SchemaPropertySetter> _draft2020_content = Map<String, SchemaPropertySetter>()
    ..addAll(_draft2019_content);

  static Map<String, SchemaPropertySetter> _draft2020_metadata = Map<String, SchemaPropertySetter>()
    ..addAll(_draft2019_metadata);

  static Map<String, Map<String, SchemaPropertySetter>> _draft2020VocabMap = Map()
    ..addAll({
      "https://json-schema.org/draft/2020-12/vocab/core": _draft2020_core,
      "https://json-schema.org/draft/2020-12/vocab/applicator": _draft2020_applicator,
      "https://json-schema.org/draft/2020-12/vocab/unevaluated": _draft2020_unevaluated,
      "https://json-schema.org/draft/2020-12/vocab/validation": _draft2020_validation,
      "https://json-schema.org/draft/2020-12/vocab/meta-data": _draft2020_metadata,
      "https://json-schema.org/draft/2020-12/vocab/format-annotation": _draft2020_format_annotation,
      "https://json-schema.org/draft/2020-12/vocab/format-assertion": _draft2020_format_assertion,
      "https://json-schema.org/draft/2020-12/vocab/content": _draft2020_content
    });

  static Map<String, Map<String, SchemaPropertySetter>> _vocabMaps = Map()
    ..addAll(_draft2019VocabMap)
    ..addAll(_draft2020VocabMap);

  // This structure holds setters for custom vocabularies.
  // It is Vocab Name->Attribute->Setter Function.
  Map<String, Map<String, SchemaPropertySetter>> _customVocabMap = Map();

  // Hold values set by the custom accessors.
  Map<String, ValidationContext Function(ValidationContext, Object)> _customAttributeValidators = Map();

  // This structure holds validators for custom formats.
  Map<String, ValidationContext Function(ValidationContext, String)> _customFormats = Map();

  /// Create a SchemaPropertySetter function that is used for setting custom properties while processing a schema.
  SchemaPropertySetter _setCustomProperty(String keyword, CustomKeyword processor) {
    // Return an function that matches the function signature for setting an attribute. It's called when
    // the given keyword is processed in a schema.
    return (JsonSchema s, Object? o) {
      // Call the users given setter function. This allows them do manipulate the data how ever they want.
      var obj = processor.propertySetter(s, o);
      // Create and store a closure for the validation function. This is kind of weird, but makes the code in the
      // validator simpler.
      ValidationContext Function(ValidationContext, Object) validationFunction =
          (ValidationContext context, Object instance) => processor.validator(context, obj, instance);
      s._customAttributeValidators[keyword] = validationFunction;
      return obj;
    };
  }

  /// Transform a list of custom vocabularies into vocabulary map.
  /// The Vocabulary map is Vocabulary->Accessor->Setter function
  Map<String, Map<String, SchemaPropertySetter>> _createCustomVocabMap(List<CustomVocabulary>? customVocabularies) {
    if (customVocabularies == null) {
      return {};
    }
    Map<String, Map<String, SchemaPropertySetter>> accessorMap = Map();
    customVocabularies.forEach((customVocabulary) {
      accessorMap[customVocabulary.vocabulary.toString()] = customVocabulary.keywordImplementations
          .map((keyword, setter) => MapEntry(keyword, _setCustomProperty(keyword, setter)));
    });
    return accessorMap;
  }

  // temporarily uses a constructed full path for relative. can be optimized in the future
  /// Get a nested [JsonSchema] from a path.
  JsonSchema resolvePath(Uri? path) =>
      _getSchemaFromPath(path?.toString().startsWith('/') == true ? Uri.parse('${this.path}${path}') : path);

  /// Get a [JsonSchema] from the dynamicParent with the given anchor. Returns null if none exists.
  JsonSchema? resolveDynamicAnchor(String dynamicAnchor, {JsonSchema? dynamicParent}) =>
      _resolveDynamicAnchor(dynamicAnchor, dynamicParent);

  @override
  bool operator ==(Object other) => other is JsonSchema && this.hashCode == other.hashCode;

  @override
  int get hashCode => _hashCode ?? (_hashCode = DeepCollectionEquality().hash(schemaMap ?? schemaBool));

  @override
  String toString() => '${_schemaBool ?? _schemaMap}';

  // --------------------------------------------------------------------------
  // Root Schema Getters
  // --------------------------------------------------------------------------

  /// The root [JsonSchema] for this [JsonSchema].
  JsonSchema? get root => _root;

  /// The parent [JsonSchema] for this [JsonSchema].
  JsonSchema? get parent => _parent;

  /// Get the anchestry of the current schema, up to the root [JsonSchema].
  List<JsonSchema> get _parents {
    final parents = <JsonSchema>[];

    var circularRefEscapeHatch = 0;
    var nextParent = this._parent;
    while (nextParent != null && circularRefEscapeHatch < 100) {
      circularRefEscapeHatch += 1;
      parents.add(nextParent);

      nextParent = nextParent._parent;
    }

    return parents;
  }

  /// JSON of the [JsonSchema] as a [Map]. Only this value or [_schemaBool] should be set, not both.
  Map? get schemaMap => _schemaMap;

  /// JSON of the [JsonSchema] as a [bool]. Only this value or [_schemaMap] should be set, not both.
  bool? get schemaBool => _schemaBool;

  /// JSON string represenatation of the schema.
  String toJson() => json.encode(_schemaMap ?? _schemaBool);

  /// JSON Schema version used.
  ///
  /// Note: Only one version can be used for a nested [JsonSchema] object.
  /// Default: [SchemaVersion.draft7]
  SchemaVersion get schemaVersion => _root?._schemaVersion ?? SchemaVersion.defaultVersion;

  /// Base [Uri] of the [JsonSchema] based on $id, or where it was fetched from, in that order, if any.
  Uri? get _uriBase => _idBase ?? _fetchedFromUriBase;

  /// [Uri] from the first ancestor with an ID
  Uri? get _inheritedUriBase {
    for (final parent in _parents) {
      if (parent._uriBase != null) {
        return parent._uriBase;
      }
    }

    return root?._uriBase;
  }

  /// [Uri] of the [JsonSchema] based on $id, or where it was fetched from, in that order, if any.
  Uri? get _uri => ((_id ?? _fetchedFromUri)?.removeFragment());

  /// [Uri] from the first ancestor with an ID
  Uri? get _inheritedUri {
    for (final parent in _parents) {
      if (parent._uri != null) {
        return parent._uri;
      }
    }

    return root?._uri;
  }

  /// Whether or not const is set, we need this since const can be null and valid.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.24
  bool get hasConst => _hasConst;

  /// Const value of the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.24
  dynamic get constValue => _constValue;

  /// Default value of the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-7.3
  dynamic get defaultValue => _defaultValue;

  /// Included [JsonSchema] definitions.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-7.1
  Map<String, JsonSchema> get definitions => _definitions;

  /// Included [JsonSchema] $defs.
  ///
  /// Spec: https://json-schema.org/draft/2019-09/json-schema-core.html#rfc.section.8.2.5
  Map<String, JsonSchema> get defs => _defs;

  /// Whether the JSON Schema is deprecated.
  ///
  /// Spec: https://json-schema.org/draft/2019-09/json-schema-validation.html#rfc.section.9.3
  bool? get deprecated => _deprecated;

  /// Description of the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-7.2
  String? get description => _description;

  /// Description of the [JsonSchema].
  ///
  /// Spec: https://json-schema.org/draft-07/json-schema-core.html#rfc.section.9
  String? get comment => _comment;

  /// Description of the [JsonSchema].
  ///
  /// Spec: https://json-schema.org/draft-07/json-schema-validation.html#rfc.section.8.4
  String? get contentMediaType => _contentMediaType;

  /// Description of the [JsonSchema].
  ///
  /// Spec: https://json-schema.org/draft-07/json-schema-validation.html#rfc.section.8.3
  String? get contentEncoding => _contentEncoding;

  /// Description of the [JsonSchema].
  ///
  /// Spec: https://json-schema.org/draft/2019-09/json-schema-validation.html#rfc.section.8.5
  String? get contentSchema => _contentSchema;

  /// A [JsonSchema] used for validataion if the schema doesn't validate against the 'if' schema.
  ///
  /// Spec: https://json-schema.org/draft-07/json-schema-validation.html#rfc.section.6.6.3
  JsonSchema? get elseSchema => _elseSchema;

  /// Possible values of the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.23
  List? get enumValues => _enumValues;

  /// The value of the exclusiveMaximum for the [JsonSchema], if any exists.
  num? get exclusiveMaximum {
    // If we're beyond draft4, the property contains the value, return it.
    if (schemaVersion > SchemaVersion.draft4) {
      return _exclusiveMaximumV6;

      // If we're on draft4, the property is a bool, so return the max instead.
    } else {
      if (hasExclusiveMaximum) {
        return _maximum;
      }
    }
    return null;
  }

  /// Whether the maximum of the [JsonSchema] is exclusive.
  bool get hasExclusiveMaximum => _exclusiveMaximum ?? _exclusiveMaximumV6 != null;

  /// The value of the exclusiveMaximum for the [JsonSchema], if any exists.
  num? get exclusiveMinimum {
    // If we're beyond draft4, the property contains the value, return it.
    if (schemaVersion >= SchemaVersion.draft6) {
      return _exclusiveMinimumV6;

      // If we're on draft4, the property is a bool, so return the min instead.
    } else {
      if (hasExclusiveMinimum) {
        return _minimum;
      }
    }
    return null;
  }

  /// Whether the minimum of the [JsonSchema] is exclusive.
  bool get hasExclusiveMinimum => _exclusiveMinimum ?? _exclusiveMinimumV6 != null;

  /// Pre-defined format (i.e. date-time, email, etc) of the [JsonSchema] value.
  String? get format => _format;

  /// ID of the [JsonSchema].
  Uri? get id => _id;

  /// ID from the first ancestor with an ID
  Uri? get _inheritedId {
    for (final parent in _parents) {
      if (parent.id != null) {
        return parent.id;
      }
    }

    return root?.id;
  }

  /// A name used to reference a [JsonSchema] object.
  String? get anchor => _anchor;

  /// A name used to reference a [JsonSchema] object.
  String? get dynamicAnchor => _dynamicAnchor;

  /// A [JsonSchema] that conditionally decides if validation should be performed against the 'then' or 'else' schema.
  ///
  /// Spec: https://json-schema.org/draft-07/json-schema-validation.html#rfc.section.6.6.1
  JsonSchema? get ifSchema => _ifSchema;

  /// Maximum value of the [JsonSchema] value.
  ///
  /// Reference: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.2
  num? get maximum => _maximum;

  /// Minimum value of the [JsonSchema] value.
  ///
  /// Reference: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.4
  num? get minimum => _minimum;

  /// Maximum length of the [JsonSchema] value.
  ///
  /// Reference: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.6
  int? get maxLength => _maxLength;

  /// Minimum length of the [JsonSchema] value.
  ///
  /// Reference: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.7
  int? get minLength => _minLength;

  /// The number which the value of the [JsonSchema] must be a multiple of.
  ///
  /// Reference: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.1
  num? get multipleOf => _multipleOf;

  /// The path of the [JsonSchema] within the root [JsonSchema].
  String? get path => _path;

  /// The regular expression the [JsonSchema] value must conform to.
  ///
  /// Refernce:
  RegExp? get pattern => _pattern;

  /// A [List<JsonSchema>] which the value must conform to all of.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.26
  List<JsonSchema> get allOf => _allOf;

  /// A [List<JsonSchema>] which the value must conform to at least one of.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.27
  List<JsonSchema> get anyOf => _anyOf;

  /// A [List<JsonSchema>] which the value must conform to at least one of.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.28
  List<JsonSchema> get oneOf => _oneOf;

  /// A [JsonSchema] which the value must NOT be.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.29
  JsonSchema? get notSchema => _notSchema;

  /// Whether the JSON Schema is read-only.
  ///
  /// Spec: https://json-schema.org/draft-07/json-schema-validation.html#rfc.section.10.3
  bool get readOnly => _readOnly;

  /// Ref to the URI of the [JsonSchema].
  Uri? get ref => _ref;

  /// Whether the [JsonSchema] is a recursive anchor point or not.
  bool get recursiveAnchor => _recursiveAnchor ?? false;

  /// RecursiveRef to the URI of the [JsonSchema].
  Uri? get recursiveRef => _recursiveRef;

  /// A DynamicRef to the URI of the [JsonSchema].
  Uri? get dynamicRef => _dynamicRef;

  /// Title of the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-7.2
  String? get title => _title;

  /// A [JsonSchema] used for validation if the schema also validates against the 'if' schema.
  ///
  /// Spec: https://json-schema.org/draft-07/json-schema-validation.html#rfc.section.6.6.2
  JsonSchema? get thenSchema => _thenSchema;

  /// List of allowable types for the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.25
  List<SchemaType?>? get typeList => _typeList;

  /// Single allowable type for the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.25
  SchemaType? get type => _typeList!.length == 1 ? _typeList!.single : null;

  /// Whether the JSON Schema is write-only.
  ///
  /// Spec: https://json-schema.org/draft-07/json-schema-validation.html#rfc.section.10.3
  bool get writeOnly => _writeOnly;

  /// The vocabularies defined by this [JsonSchema].
  ///
  /// Spec: https://json-schema.org/draft/2019-09/json-schema-core.html#rfc.section.8.1.2
  Map<Uri, bool>? get vocabulary => _vocabulary;

  /// The vocabularies defined by the metaschema of this [JsonSchema].
  ///
  /// Spec: https://json-schema.org/draft/2019-09/json-schema-core.html#rfc.section.8.1.2
  Map<Uri, bool>? get metaschemaVocabulary => _metaschemaVocabulary ?? _root?._metaschemaVocabulary;

  // --------------------------------------------------------------------------
  // Schema List Item Related Getters
  // --------------------------------------------------------------------------

  /// Single [JsonSchema] sub items of this [JsonSchema] must conform to.
  /// Note: This has subtly changed in draft 2020.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.9
  /// Spec: https://json-schema.org/draft/2020-12/json-schema-core.html#rfc.section.10.3.1.2
  JsonSchema? get items => _items;

  /// Ordered list of [JsonSchema] which the value of the same index must conform to.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.9
  List<JsonSchema?>? get itemsList => _itemsList;

  /// Ordered list of [JsonSchema] which the value of the same index must conform to.
  /// Used in draft2020-12
  /// https://json-schema.org/draft/2020-12/json-schema-core.html#rfc.section.10.3.1.1
  List<JsonSchema>? get prefixItems => _prefixItems;

  /// Whether additional items are allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.10
  bool? get additionalItemsBool => _additionalItemsBool;

  /// JsonSchema additional items should conform to.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.10
  JsonSchema? get additionalItemsSchema => _additionalItemsSchema;

  /// List of example instances for the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-7.4
  List get examples => defaultValue != null
      ? ([]
        ..addAll(_examples)
        ..add(defaultValue))
      : _examples;

  /// The maximum number of items allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.11
  int? get maxItems => _maxItems;

  /// The minimum number of items allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.12
  int? get minItems => _minItems;

  /// Whether the items in the list must be unique.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.13
  bool get uniqueItems => _uniqueItems;

  /// The minimum number of elements in the list that are valid against the schema for [contains]
  ///
  /// https://json-schema.org/draft/2019-09/json-schema-validation.html#rfc.section.6.4.4
  int? get minContains => _minContains;

  /// The maximum number of elements in the list that are valid against the schema for [contains]
  ///
  /// https://json-schema.org/draft/2019-09/json-schema-validation.html#rfc.section.6.4.4
  int? get maxContains => _maxContains;

  // --------------------------------------------------------------------------
  // Schema Sub-Property Related Getters
  // --------------------------------------------------------------------------

  /// Map of [JsonSchema]s for properties, by [String] key.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.18
  Map<String, JsonSchema> get properties => _properties;

  /// [JsonSchema] that property names must conform to.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.22
  JsonSchema? get propertyNamesSchema => _propertyNamesSchema;

  /// Whether additional properties, other than those specified, are allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.20
  bool? get additionalPropertiesBool => _additionalProperties;

  /// [JsonSchema] that additional properties must conform to.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.20
  JsonSchema? get additionalPropertiesSchema => _additionalPropertiesSchema;

  /// [JsonSchema] that unevaluated properties must conform to.
  ///
  /// Spec: https://json-schema.org/draft/2019-09/json-schema-core.html#rfc.section.9.3.2.4
  JsonSchema? get unevaluatedProperties => _unevaluatedProperties;

  /// [JsonSchema] definition that at least one item must match to be valid.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.14
  JsonSchema? get contains => _contains;

  /// The maximum number of properties allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.15
  int? get maxProperties => _maxProperties;

  /// The minimum number of properties allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.16
  int get minProperties => _minProperties;

  /// Map of [JsonSchema]s for properties, based on [RegExp]s keys.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.19
  Map<RegExp, JsonSchema> get patternProperties => _patternProperties;

  /// Map of property dependencies by property name.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.21
  Map<String, List<String>> get propertyDependencies => _propertyDependencies;

  /// Properties that must be inclueded for the [JsonSchema] to be valid.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.17
  List<String>? get requiredProperties => _requiredProperties;

  /// Map of schema dependencies by property name.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.21
  Map<String, JsonSchema> get schemaDependencies => _schemaDependencies;

  /// [JsonSchema] of unevaluated items
  ///
  /// Spec: https://json-schema.org/draft/2019-09/json-schema-core.html#rfc.section.9.3.1.3
  JsonSchema? get unevaluatedItems => _unevaluatedItems;

  /// The set of functions to validate custom keywords.
  @Deprecated("For internal use by the Validator only")
  Map<String, ValidationContext Function(ValidationContext, Object)> get customAttributeValidators =>
      _customAttributeValidators;

  /// The set of functions to validate custom formats.
  @Deprecated("For internal use by the Validator only")
  Map<String, ValidationContext Function(ValidationContext, String)> get customFormats => _customFormats;

  Map<SchemaPathPair, JsonSchema>? get _memomizedResults => _rootMemomizedPathResults ?? _root?._memomizedResults;

  // --------------------------------------------------------------------------
  // Convenience Methods
  // --------------------------------------------------------------------------

  void _addRefRetrievals(Uri? ref) {
    final JsonSchema? Function(JsonSchema?) addSchemaFunction = (JsonSchema? schema) {
      if (schema != null) {
        // Set referenced schema's path should be equivalent to the $ref value.
        // Otherwise it's set as `/`, which doesn't help track down
        // the source of validation errors.
        schema._path = ref.toString() + '/';

        final String rootRef = '${ref!.removeFragment()}#';
        _addSchemaToRefMap(rootRef, schema._root);
        return null;
      } else {
        String exceptionMessage = 'Couldn\'t resolve ref: ${ref} ';
        if (_refProvider != null) {
          exceptionMessage += 'using the provided ref provider';
        } else {
          exceptionMessage += _isSync ? 'due to null ref provider' : 'using the default HTTP(S) ref provider';
        }
        throw FormatExceptions.error(exceptionMessage);
      }
    };

    final AsyncRetrievalOperation asyncRefSchemaOperation = _refProvider != null
        ? () => _fetchRefSchemaFromAsyncProvider(ref).then(addSchemaFunction)
        : () => _fetchRefSchemaFromAsyncProvider(ref, refProvider: defaultUrlRefProvider).then(addSchemaFunction);

    final SyncRetrievalOperation? syncRefSchemaOperation =
        _refProvider != null && ref != null ? (() => addSchemaFunction(_fetchRefSchemaFromSyncProvider(ref))) : null;

    /// Always add sub-schema retrieval requests to the [_root], as this is where the promise resolves.
    _root!._retrievalRequests.add(RetrievalRequest()
      ..schemaUri = ref
      ..asyncRetrievalOperation = asyncRefSchemaOperation
      ..syncRetrievalOperation = syncRefSchemaOperation);
  }

  /// Prepends inherited Uri data to the ref if necessary.
  Uri _translateLocalRefToFullUri(Uri ref) {
    // TODO: add a more advanced check to find out if the $ref is local.
    // Does it have a fragment? Append the base and check if it exists in the _refMap
    // Does it have a path? Append the base and check if it exists in the _refMap
    if (ref.scheme.isEmpty && ref.path != _root!._uri?.path) {
      /// If the ref has a path, append it to the inheritedUriBase
      if (ref.path != '/' && ref.path.isNotEmpty) {
        final String path = ref.path.startsWith('/') ? ref.path : '/${ref.path}';
        String template = '${_uriBase ?? _inheritedUriBase ?? ''}$path';

        if (ref.fragment.isNotEmpty) {
          template += '#${ref.fragment}';
        }
        ref = Uri.parse(template);
      } else {
        // If the ref has a fragment, append it to the _uri or _inheritedUri, or use it alone.
        ref = Uri.parse('${_uri ?? _inheritedUri ?? ''}#${ref.fragment}');
      }
    }

    return ref;
  }

  /// Name of the property of the current [JsonSchema] within its parent.
  String? get propertyName {
    final pathUri = Uri.tryParse(path!);
    final pathFragments = pathUri?.fragment.split('/');
    return (pathFragments?.length ?? 0) > 2 ? pathFragments?.last : null;
  }

  /// Whether a given property is required for the [JsonSchema] instance to be valid.
  bool propertyRequired(String? property) => _requiredProperties != null && _requiredProperties!.contains(property);

  /// Whether the [JsonSchema] is required on its parent.
  bool get requiredOnParent => _parent?.propertyRequired(propertyName) ?? false;

  @Deprecated('4.0, to be removed in 5.0, use validate() instead.')
  ValidationResults validateWithResults(dynamic instance, {bool parseJson = false, bool? validateFormats}) =>
      Validator(this)
          .validate(instance, reportMultipleErrors: true, parseJson: parseJson, validateFormats: validateFormats);

  /// Validate [instance] against this schema, returning the result
  /// with information about any validation errors or warnings that occurred.
  ValidationResults validate(dynamic instance, {bool parseJson = false, bool? validateFormats}) => Validator(this)
      .validate(instance, reportMultipleErrors: true, parseJson: parseJson, validateFormats: validateFormats);

  // --------------------------------------------------------------------------
  // JSON Schema Internal Operations
  // --------------------------------------------------------------------------

  /// Function to determine whether a given [schemaDefinition] is a remote $ref.
  bool _isRemoteRef(dynamic schemaDefinition) {
    Map schemaDefinitionMap;
    try {
      schemaDefinitionMap = TypeValidators.object('NA', schemaDefinition);
    } catch (e) {
      // If the schema definition isn't an object, return early, since it can't be a ref.
      return false;
    }

    if (schemaDefinitionMap[r'$ref'] is String) {
      final String? ref = schemaDefinitionMap[r'$ref'];
      if (ref != null) {
        TypeValidators.nonEmptyString(r'$ref', ref);
        // If the ref begins with "#" it is a local ref, so we return false.
        if (ref.startsWith('#')) return false;
        return true;
      }
    }
    return false;
  }

  /// Add a ref'd JsonSchema to the map of available Schemas.
  JsonSchema? _addSchemaToRefMap(String path, JsonSchema? schema) => _refMap[path] = schema!;

  // Create a [JsonSchema] from a sub-schema of the root.
  _createOrRetrieveSchema(String path, dynamic schema, SchemaAssigner assigner, {mustBeValid = true}) {
    var throwError;

    if (schema is bool && !(schemaVersion >= SchemaVersion.draft6))
      throwError = () => throw FormatExceptions.schema(path, schema);
    if (schema is! Map && schema is! bool) throwError = () => throw FormatExceptions.schema(path, schema);

    if (throwError != null) {
      if (mustBeValid) throwError();
      return;
    }

    final isRemoteReference = _isRemoteRef(schema);

    /// If this sub-schema is a ref within the root schema,
    /// add it to the map of local schema assignments.
    /// Otherwise, call the assigner function and create a new [JsonSchema].
    if (isRemoteReference) {
      final schemaDefinitionMap = TypeValidators.object(path, schema);
      Uri ref = TypeValidators.uri(r'$ref', schemaDefinitionMap[r'$ref']);

      // Add any relevant inherited Uri information.
      ref = _translateLocalRefToFullUri(ref);

      // Add retrievals to _root schema.
      _addRefRetrievals(ref);

      if (schemaVersion < SchemaVersion.draft2019_09) {
        _schemaAssignments.add(() => assigner(_getSchemaFromPath(ref)));
      } else {
        // References can't overwrite the reference node in draft 2019 or later.
        assigner(_createSubSchema(schema, path));
      }
    } else {
      // Sub schema can be created immediately.
      assigner(_createSubSchema(schema, path));
    }
  }

  // --------------------------------------------------------------------------
  // Internal Property Validators
  // --------------------------------------------------------------------------

  void _validateListOfSchema(String key, dynamic value, SchemaAdder schemaAdder) {
    TypeValidators.nonEmptyList(key, value);
    for (int i = 0; i < value.length; i++) {
      _createOrRetrieveSchema('$_path/$key/$i', value[i], (rhs) => schemaAdder(rhs));
    }
  }

  // --------------------------------------------------------------------------
  // Root Schema Property Setters
  // --------------------------------------------------------------------------

  /// Validate, calculate and set the value of the 'allOf' JSON Schema keyword.
  _setAllOf(dynamic value) => _validateListOfSchema('allOf', value, (schema) => _allOf.add(schema));

  /// Validate, calculate and set the value of the 'anyOf' JSON Schema keyword.
  _setAnyOf(dynamic value) => _validateListOfSchema('anyOf', value, (schema) => _anyOf.add(schema));

  /// Validate, calculate and set the value of the 'const' JSON Schema keyword.
  _setConst(dynamic value) {
    _hasConst = true;
    _constValue = value; // Any value is valid for const, even null.
  }

  /// Validate, calculate and set the value of the 'defaultValue' JSON Schema keyword.
  _setDefault(dynamic value) => _defaultValue = value;

  /// Validate, calculate and set the value of the 'definitions' JSON Schema keyword.
  _setDefinitions(dynamic value) => (TypeValidators.object('definition', value))
      .forEach((k, v) => _createOrRetrieveSchema('$_path/definitions/$k', v, (rhs) => _definitions[k] = rhs));

  /// Validate, calculate and set the value of the '$defs' JSON Schema keyword.
  _setDefs(dynamic value) => (TypeValidators.object(r'$defs', value))
      .forEach((k, v) => _createOrRetrieveSchema('$_path/\$defs/$k', v, (rhs) => _defs[k] = rhs));

  /// Validate, calculate and set the value of the 'deprecated' JSON Schema keyword.
  _setDeprecated(dynamic value) => _deprecated = TypeValidators.boolean('deprecated', value);

  /// Validate, calculate and set the value of the 'description' JSON Schema keyword.
  _setDescription(dynamic value) => _description = TypeValidators.string('description', value);

  /// Validate, calculate and set the value of the '$comment' JSON Schema keyword.
  _setComment(dynamic value) => _comment = TypeValidators.string(r'$comment', value);

  /// Validate, calculate and set the value of the 'contentMediaType' JSON Schema keyword.
  _setContentMediaType(dynamic value) => _contentMediaType = TypeValidators.string('contentMediaType', value);

  /// Validate, calculate and set the value of the 'contentEncoding' JSON Schema keyword.
  _setContentEncoding(dynamic value) => _contentEncoding = TypeValidators.string('contentEncoding', value);

  /// Validate, calculate and set the value of the 'contentSchema' JSON Schema keyword.
  _setContentSchema(dynamic value) => _contentSchema = TypeValidators.string('contentSchema', value);

  /// Validate, calculate and set the value of the 'else' JSON Schema keyword.
  _setElse(dynamic value) {
    if (value is Map || value is bool && schemaVersion >= SchemaVersion.draft6) {
      _createOrRetrieveSchema('$_path/else', value, (rhs) => _elseSchema = rhs);
    } else {
      throw FormatExceptions.error('items must be object (or boolean in draft6 and later): $value');
    }
  }

  /// Validate, calculate and set the value of the 'enum' JSON Schema keyword.
  _setEnum(dynamic value) => _enumValues = TypeValidators.uniqueList('enum', value);

  /// Validate, calculate and set the value of the 'exclusiveMaximum' JSON Schema keyword.
  _setExclusiveMaximum(dynamic value) => _exclusiveMaximum = TypeValidators.boolean('exclusiveMaximum', value);

  /// Validate, calculate and set the value of the 'exclusiveMaximum' JSON Schema keyword.
  _setExclusiveMaximumV6(dynamic value) => _exclusiveMaximumV6 = TypeValidators.number('exclusiveMaximum', value);

  /// Validate, calculate and set the value of the 'exclusiveMinimum' JSON Schema keyword.
  _setExclusiveMinimum(dynamic value) => _exclusiveMinimum = TypeValidators.boolean('exclusiveMinimum', value);

  /// Validate, calculate and set the value of the 'exclusiveMinimum' JSON Schema keyword.
  _setExclusiveMinimumV6(dynamic value) => _exclusiveMinimumV6 = TypeValidators.number('exclusiveMinimum', value);

  /// Validate, calculate and set the value of the 'format' JSON Schema keyword.
  _setFormat(dynamic value) => _format = TypeValidators.string('format', value);

  /// Validate, calculate and set the value of the 'id' JSON Schema keyword.
  Uri? _setId(dynamic value) {
    // First, just add the ref directly, as a fallback, and in case the ID has its own
    // unique origin (i.e. http://example1.com vs http://example2.com/)
    _id = TypeValidators.uri('id', value);

    // If the current schema $id has no scheme.
    if (_id!.scheme.isEmpty) {
      // If the $id has a path and the root has a base, append it to the base.
      if (_inheritedUriBase != null && _id!.path != '/' && _id!.path.isNotEmpty) {
        final path = _id!.path.startsWith('/') ? _id!.path : '/${_id!.path}';
        _id = Uri.parse('${_inheritedUriBase.toString()}$path');

        // If the $id has a fragment, append it to the base, or use it alone.
      } else if (_id!.fragment.isNotEmpty) {
        if (schemaVersion >= SchemaVersion.draft2019_09) {
          throw FormatExceptions.error('\$id may only be a URI-references without a fragment: $value');
        }
        _id = Uri.parse('${_inheritedId ?? ''}#${_id!.fragment}');
      }
    }

    try {
      _idBase = JsonSchemaUtils.getBaseFromFullUri(_id!);
    } catch (e) {
      // ID base can't be set for schemes other than HTTP(S).
      // This is expected behavior.
    }

    // Add the current schema to the ref map by its id, so it can be referenced elsewhere.
    final String refMapString = '$_id${_id!.hasFragment ? '' : '#'}';
    _addSchemaToRefMap(refMapString, this);
    return _id;
  }

  /// Validate, calculate and set the value of the '$schema' JSON Schema keyword.
  _setSchema(dynamic value) {
    _schema = TypeValidators.uri(r'$schema', value);
    // Retrieve the metaschema so it can be introspected for properties such as vocabularies.
    _addRefRetrievals(_schema);
  }

  /// Validate, set, and register the value of the '$anchor' JSON Schema keyword.
  _setAnchor(dynamic value) {
    _anchor = TypeValidators.anchorString(r"$anchor", value);
    final uri = _uri ?? _inheritedUri ?? '';
    final String refMapString = '$uri#$_anchor';
    _addSchemaToRefMap(refMapString, this);
    return _anchor;
  }

  _setDynamicAnchor(dynamic value) {
    _dynamicAnchor = TypeValidators.anchorString(r"$dynamicAnchor", value);
    final uri = _uri ?? _inheritedUri ?? '';
    final String refMapString = '$uri#$_dynamicAnchor';
    _addSchemaToRefMap(refMapString, this);
    return _dynamicAnchor;
  }

  /// Validate, set the value of the '$recursiveAnchor' JSON Schema keyword.
  _setRecursiveAnchor(dynamic value) {
    _recursiveAnchor = TypeValidators.boolean(r'$recursiveAnchor', value);
  }

  /// Validate, calculate and set the value of the 'if' JSON Schema keyword.
  _setIf(dynamic value) {
    if (value is Map || value is bool && schemaVersion >= SchemaVersion.draft6) {
      _createOrRetrieveSchema('$_path/if', value, (rhs) => _ifSchema = rhs);
    } else {
      throw FormatExceptions.error('items must be object (or boolean in draft6 and later): $value');
    }
  }

  /// Validate, calculate and set the value of the 'minimum' JSON Schema keyword.
  _setMinimum(Object value) => _minimum = TypeValidators.number('minimum', value);

  /// Validate, calculate and set the value of the 'maximum' JSON Schema keyword.
  _setMaximum(dynamic value) => _maximum = TypeValidators.number('maximum', value);

  /// Validate, calculate and set the value of the 'maxLength' JSON Schema keyword.
  _setMaxLength(dynamic value) => _maxLength = TypeValidators.nonNegativeInt('maxLength', value);

  /// Validate, calculate and set the value of the 'minLength' JSON Schema keyword.
  _setMinLength(dynamic value) => _minLength = TypeValidators.nonNegativeInt('minLength', value);

  /// Validate, calculate and set the value of the 'multiple' JSON Schema keyword.
  _setMultipleOf(Object value) => _multipleOf = TypeValidators.nonNegativeNum('multiple', value);

  /// Validate, calculate and set the value of the 'not' JSON Schema keyword.
  _setNot(Object? value) {
    if (value is Map || value is bool && schemaVersion >= SchemaVersion.draft6) {
      _createOrRetrieveSchema('$_path/not', value, (rhs) => _notSchema = rhs);
    } else {
      throw FormatExceptions.error('items must be object (or boolean in draft6 and later): $value');
    }
  }

  /// Validate, calculate and set the value of the 'oneOf' JSON Schema keyword.
  _setOneOf(Object value) => _validateListOfSchema('oneOf', value, (schema) => _oneOf.add(schema));

  /// Validate, calculate and set the value of the 'pattern' JSON Schema keyword.
  _setPattern(Object value) => _pattern = RegExp(TypeValidators.string('pattern', value), unicode: true);

  /// Validate, calculate and set the value of the 'propertyNames' JSON Schema keyword.
  _setPropertyNames(Object value) {
    if (value is Map || value is bool && schemaVersion >= SchemaVersion.draft6) {
      _createOrRetrieveSchema('$_path/propertyNames', value, (rhs) => _propertyNamesSchema = rhs);
    } else {
      throw FormatExceptions.error('items must be object (or boolean in draft6 and later): $value');
    }
  }

  /// Validate, calculate and set the value of the 'readOnly' JSON Schema keyword.
  _setReadOnly(Object value) => _readOnly = TypeValidators.boolean('readOnly', value);

  /// Validate, calculate and set the value of the 'writeOnly' JSON Schema keyword.
  _setWriteOnly(Object value) => _writeOnly = TypeValidators.boolean('writeOnly', value);

  /// Validate, calculate and set the value of the '$ref' JSON Schema keyword.
  _setRef(Object value) {
    // Add any relevant inherited Uri information.
    _ref = _translateLocalRefToFullUri(TypeValidators.uri(r'$ref', value));

    // The ref's base is a relative file path, so it should be treated as a relative file URI
    final isRelativeFileUri = _inheritedUriBase != null && _inheritedUriBase!.scheme.isEmpty;
    if (_ref!.scheme.isNotEmpty || isRelativeFileUri) {
      // Add retrievals to _root schema.
      _addRefRetrievals(_ref);
    } else {
      // Add _ref to _localRefs to be validated during schema path resolution.
      _root?._localRefs.add(_ref);
    }
  }

  /// Validate, calculate and set the value of the '$recursiveRef' JSON Schema keyword.
  _setRecursiveRef(Object value) {
    _recursiveRef = _translateLocalRefToFullUri(TypeValidators.uri(r'$recursiveRef', value));

    // The ref's base is a relative file path, so it should be treated as a relative file URI
    final isRelativeFileUri = _inheritedUriBase != null && _inheritedUriBase!.scheme.isEmpty;
    if (_recursiveRef!.scheme.isNotEmpty || isRelativeFileUri) {
      // Add retrievals to _root schema.
      _addRefRetrievals(_recursiveRef);
    } else {
      // Add _ref to _localRefs to be validated during schema path resolution.
      _root?._localRefs.add(_recursiveRef);
    }
  }

  /// Validate, calculate and set the value of the '$dynamicRef' JSON Schema keyword.
  _setDynamicRef(Object value) {
    _dynamicRef = _translateLocalRefToFullUri(TypeValidators.uri(r'$dynamicRef', value));

    // The ref's base is a relative file path, so it should be treated as a relative file URI
    final isRelativeFileUri = _inheritedUriBase != null && _inheritedUriBase!.scheme.isEmpty;
    final isLocalRef = _inheritedUri!.removeFragment() == _dynamicRef!.removeFragment();
    if ((_dynamicRef!.scheme.isNotEmpty && !isLocalRef) || isRelativeFileUri) {
      // Add retrievals to _root schema.
      _addRefRetrievals(_dynamicRef);
    } else {
      // Add _ref to _localRefs to be validated during schema path resolution.
      _root?._localRefs.add(_dynamicRef);
    }
  }

  /// Determine which schema version to use.
  ///
  /// Note: Uses the user specified version first, then the version set on the schema JSON, then the default.
  static SchemaVersion _getSchemaVersion(SchemaVersion? userSchemaVersion, Object? schema) {
    if (userSchemaVersion != null) {
      return TypeValidators.builtInSchemaVersion(r'$schema', userSchemaVersion.toString());
    } else if (schema is Map && schema[r'$schema'] is String) {
      return TypeValidators.builtInSchemaVersion(r'$schema', schema[r'$schema']);
    }
    return SchemaVersion.defaultVersion;
  }

  /// Validate, calculate and set the value of the 'title' JSON Schema keyword.
  _setTitle(Object value) => _title = TypeValidators.string('title', value);

  /// Validate, calculate and set the value of the 'then' JSON Schema keyword.
  _setThen(Object value) {
    if (value is Map || value is bool && schemaVersion >= SchemaVersion.draft6) {
      _createOrRetrieveSchema('$_path/then', value, (rhs) => _thenSchema = rhs);
    } else {
      throw FormatExceptions.error('items must be object (or boolean in draft6 and later): $value');
    }
  }

  /// Validate, calculate and set the value of the 'type' JSON Schema keyword.
  _setType(dynamic value) => _typeList = TypeValidators.typeList('type', value);

  /// Validate, calculate and set the value of the '$vocabulary' JSON Schema keyword.
  _setVocabulary(dynamic value) {
    try {
      _vocabulary = TypeValidators.object(r'$vocabulary', value)
          .cast<String, bool>()
          .map<Uri, bool>((key, value) => MapEntry(Uri.parse(key), value));
    } catch (RuntimeException) {
      throw FormatExceptions.error('\$vocabulary must be a map from URI to bool: $value');
    }
  }

  _setMetaschemaVocabulary(dynamic value) {
    try {
      _metaschemaVocabulary =
          TypeValidators.object(r'$vocabulary', value).cast<String, bool>().map<Uri, bool>((key, required) {
        // Check to see if the vocabulary is required to validate and if we are able to validate the vocabulary.
        if (required && !(_vocabMaps.containsKey(key.toString()) || _customVocabMap.containsKey(key.toString()))) {
          throw FormatExceptions.error(
              '\$vocabulary ${key} is required by the schema but is unknown to this validator');
        }
        return MapEntry(Uri.parse(key), required);
      });
    } on FormatException catch (e) {
      throw e;
    } catch (e) {
      throw FormatExceptions.error('\$vocabulary must be a map from URI to bool: $value');
    }
  }

  // --------------------------------------------------------------------------
  // Schema List Item Related Property Setters
  // --------------------------------------------------------------------------

  /// Validate, calculate and set items of the 'pattern' JSON Schema prop that are also [JsonSchema]s.
  _setItems(dynamic value) {
    if (value is Map || (value is bool && schemaVersion >= SchemaVersion.draft6)) {
      _createOrRetrieveSchema('$_path/items', value, (rhs) => _items = rhs);
    } else if (value is List) {
      int index = 0;
      _itemsList = [];
      for (int i = 0; i < value.length; i++) {
        _createOrRetrieveSchema('$_path/items/${index++}', value[i], (rhs) => _itemsList!.add(rhs));
      }
    } else {
      throw FormatExceptions.error('items must be object or array (or boolean in draft6 and later): $value');
    }
  }

  // Prefix Items has the same semantics as the old Items when Items is a list.
  _setPrefixItems(dynamic value) {
    if (value is List) {
      int index = 0;
      _prefixItems = [];
      for (int i = 0; i < value.length; i++) {
        _createOrRetrieveSchema('$_path/prefixItems/${index++}', value[i], (rhs) => _prefixItems!.add(rhs));
      }
    } else {
      throw FormatExceptions.error('prefixItems must be a list: $value');
    }
  }

  /// Validate, calculate and set the value of the 'additionalItems' JSON Schema keyword.
  _setAdditionalItems(dynamic value) {
    if (value is bool) {
      _additionalItemsBool = value;
    } else if (value is Map) {
      _createOrRetrieveSchema('$_path/additionalItems', value, (rhs) => _additionalItemsSchema = rhs);
    } else {
      throw FormatExceptions.error('additionalItems must be boolean or object: $value');
    }
  }

  /// Items in draft 2020 has the same semantics as additionalItems in previous drafts
  _setItemsDraft2020(dynamic value) {
    if (value is Map || value is bool) {
      _createOrRetrieveSchema('$_path/items', value, (rhs) => _items = rhs);
    } else {
      throw FormatExceptions.error('items must be boolean or object: $value');
    }
  }

  /// Validate, calculate and set the value of the 'contains' JSON Schema keyword.
  _setContains(Object value) => _createOrRetrieveSchema('$_path/contains', value, (rhs) => _contains = rhs);

  /// Validate, calculate and set the value of the 'minContains' JSON Schema keyword.
  _setMinContains(Object value) => _minContains = TypeValidators.nonNegativeInt('minContains', value);

  /// Validate, calculate and set the value of the 'maxContains' JSON Schema keyword.
  _setMaxContains(Object value) => _maxContains = TypeValidators.nonNegativeInt('maxContains', value);

  /// Validate, calculate and set the value of the 'examples' JSON Schema keyword.
  _setExamples(Object value) => _examples = TypeValidators.list('examples', value);

  /// Validate, calculate and set the value of the 'maxItems' JSON Schema keyword.
  _setMaxItems(Object value) => _maxItems = TypeValidators.nonNegativeInt('maxItems', value);

  /// Validate, calculate and set the value of the 'minItems' JSON Schema keyword.
  _setMinItems(Object value) => _minItems = TypeValidators.nonNegativeInt('minItems', value);

  /// Validate, calculate and set the value of the 'uniqueItems' JSON Schema keyword.
  _setUniqueItems(Object value) => _uniqueItems = TypeValidators.boolean('uniqueItems', value);

  // --------------------------------------------------------------------------
  // Schema Sub-Property Related Property Setters
  // --------------------------------------------------------------------------

  /// Validate, calculate and set sub-items or properties of the schema that are also [JsonSchema]s.
  _setProperties(Object value) => (TypeValidators.object('properties', value)).forEach((property, subSchema) =>
      _createOrRetrieveSchema('$_path/properties/$property', subSchema, (rhs) => _properties[property] = rhs));

  /// Validate, calculate and set the value of the 'additionalProperties' JSON Schema keyword.
  _setAdditionalProperties(dynamic value) {
    if (value is bool) {
      _additionalProperties = value;
    } else if (value is Map) {
      _createOrRetrieveSchema('$_path/additionalProperties', value, (rhs) => _additionalPropertiesSchema = rhs);
    } else {
      throw FormatExceptions.error('additionalProperties must be a bool or valid schema object: $value');
    }
  }

  /// Validate, calculate and set the value of the 'unevaluatedProperties' JSON Schema keyword.
  _setUnevaluatedProperties(Object value) {
    _createOrRetrieveSchema('$_path/unevaluatedProperties', value, (rhs) => _unevaluatedProperties = rhs);
  }

  /// Validate, calculate and set the value of the 'dependencies' JSON Schema keyword.
  _setDependencies(Object value) => (TypeValidators.object('dependencies', value)).forEach((k, v) {
        if (v is Map || v is bool && schemaVersion >= SchemaVersion.draft6) {
          _createOrRetrieveSchema('$_path/dependencies/$k', v, (rhs) => _schemaDependencies[k] = rhs);
        } else if (v is List) {
          // Dependencies must have contents in draft4, but can be empty in draft6 and later
          if (schemaVersion == SchemaVersion.draft4) {
            if (v.isEmpty) throw FormatExceptions.error('property dependencies must be non-empty array');
          }

          final Set uniqueDeps = Set();
          v.forEach((propDep) {
            if (propDep is! String) throw FormatExceptions.string('propertyDependency', v);

            if (uniqueDeps.contains(propDep)) throw FormatExceptions.error('property dependencies must be unique: $v');

            _propertyDependencies.putIfAbsent(k, () => []).add(propDep);
            uniqueDeps.add(propDep);
          });
        } else {
          throw FormatExceptions.error(
              'dependency values must be object or array (or boolean in draft6 and later): $v');
        }
      });

  _setDependentSchemas(Object value) => (TypeValidators.object('dependentSchemas', value)).forEach((k, v) {
        if (v is Map || v is bool && schemaVersion >= SchemaVersion.draft6) {
          _createOrRetrieveSchema('$_path/dependentSchemas/$k', v, (rhs) => _schemaDependencies[k] = rhs);
        } else {
          throw FormatExceptions.error('dependentSchemas values must be object (or boolean in draft6 and later): $v');
        }
      });

  _setDependentRequired(Object value) => (TypeValidators.object('dependentRequired', value)).forEach((k, v) {
        if (v is List) {
          // Dependencies must have contents in draft4, but can be empty in draft6 and later
          if (schemaVersion == SchemaVersion.draft4) {
            if (v.isEmpty) throw FormatExceptions.error('dependentRequired must be non-empty array');
          }

          final Set uniqueDeps = Set();
          v.forEach((propDep) {
            if (propDep is! String) throw FormatExceptions.string('propertyDependency', v);

            if (uniqueDeps.contains(propDep))
              throw FormatExceptions.error('dependentRequired items must be unique: $v');

            _propertyDependencies.putIfAbsent(k, () => []).add(propDep);
            uniqueDeps.add(propDep);
          });
        } else {
          throw FormatExceptions.error('dependentRequired values must an array: $v');
        }
      });

  /// Validate, calculate and set the value of the 'maxProperties' JSON Schema keyword.
  _setMaxProperties(Object value) => _maxProperties = TypeValidators.nonNegativeInt('maxProperties', value);

  /// Validate, calculate and set the value of the 'minProperties' JSON Schema keyword.
  _setMinProperties(Object value) => _minProperties = TypeValidators.nonNegativeInt('minProperties', value);

  /// Validate, calculate and set the value of the 'patternProperties' JSON Schema keyword.
  _setPatternProperties(Object value) =>
      (TypeValidators.object('patternProperties', value)).forEach((k, v) => _createOrRetrieveSchema(
          '$_path/patternProperties/$k', v, (rhs) => _patternProperties[RegExp(k, unicode: true)] = rhs));

  /// Validate, calculate and set the value of the 'required' JSON Schema keyword.
  _setRequired(Object value) =>
      _requiredProperties = (TypeValidators.nonEmptyList('required', value)).map((value) => value as String).toList();

  /// Validate, calculate and set the value of the 'required' JSON Schema keyword.
  _setRequiredV6(Object value) =>
      _requiredProperties = (TypeValidators.list('required', value)).map((value) => value as String).toList();

  _setUnevaluatedItems(Object value) {
    if (value is Map || (value is bool && schemaVersion >= SchemaVersion.draft6)) {
      _createOrRetrieveSchema('$_path/unevaluatedItems', value, (rhs) => _unevaluatedItems = rhs);
    } else {
      throw FormatExceptions.error('unevaluatedItems must be object (or boolean in draft6 and later): $value');
    }
  }
}
