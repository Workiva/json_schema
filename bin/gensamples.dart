// Copyright 2013-2018 Workiva Inc.
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

import 'dart:io';

import 'package:path/path.dart';
import 'package:json_schema/json_schema.dart';
import 'package:json_schema/vm.dart';
import 'package:json_schema/schema_dot.dart';

main() {
  configureJsonSchemaForVm();

  final sourcePath = join(dirname(dirname(absolute(Platform.script.toFilePath()))), 'dot_samples', 'schemas');
  final outPath = join(dirname(sourcePath), 'schemaout');
  Directory(sourcePath).listSync().forEach((jsonFile) {
    final fname = jsonFile.path;
    final base = basenameWithoutExtension(fname);
    final dotFilename = join(outPath, '$base.dot');
    final pngOut = join(outPath, '$base.png');

    JsonSchema.createSchemaFromUrl(fname).then((schema) {
      schema.refMap.forEach((key, ref) => print('$key : $ref'));
      File(dotFilename).writeAsStringSync(createDot(schema));
    }).then((_) {
      Process.run('dot', ['-Tpng', '-o$pngOut', dotFilename]).then((ProcessResult processResult) {
        if (processResult.exitCode == 0) {
          print('Finished running dot -Tpng -o$pngOut $fname');
        } else {
          print('FAILED: running dot -Tpng -o$pngOut $fname');
        }
      });
    });
  });
}
