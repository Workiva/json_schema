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

class SchemaVersion implements Comparable<SchemaVersion> {
  const SchemaVersion._(this.value);

  static const SchemaVersion draft4 = SchemaVersion._(0);

  static const SchemaVersion draft6 = SchemaVersion._(1);

  static const SchemaVersion draft7 = SchemaVersion._(2);

  static const SchemaVersion draft2019_09 = SchemaVersion._(3);

  static const SchemaVersion draft2020_12 = SchemaVersion._(4);

  static List<SchemaVersion> get values => const <SchemaVersion>[draft4, draft6, draft7, draft2019_09, draft2020_12];

  final int value;

  @override
  int get hashCode => value;

  @override
  bool operator ==(Object other) => other is SchemaVersion && other.hashCode == hashCode;

  SchemaVersion copy() => this;

  @override
  int compareTo(SchemaVersion other) => value.compareTo(other.value);

  bool operator <(Object other) => other is SchemaVersion && this.compareTo(other) < 0;
  bool operator >(Object other) => other is SchemaVersion && this.compareTo(other) > 0;
  bool operator <=(Object other) => other is SchemaVersion && this.compareTo(other) <= 0;
  bool operator >=(Object other) => other is SchemaVersion && this.compareTo(other) >= 0;

  @override
  String toString() {
    final draftToStringMap = {
      draft4: 'http://json-schema.org/draft-04/schema#',
      draft6: 'http://json-schema.org/draft-06/schema#',
      draft7: 'http://json-schema.org/draft-07/schema#',
      draft2019_09: 'https://json-schema.org/draft/2019-09/schema',
      draft2020_12: 'https://json-schema.org/draft/2020-12/schema',
    };
    return draftToStringMap[this]!;
  }

  static SchemaVersion? fromString(String? s) {
    if (s == null) return null;
    switch (s) {
      case 'http://json-schema.org/draft-04/schema#':
        return draft4;
      case 'http://json-schema.org/draft-06/schema#':
        return draft6;
      case 'http://json-schema.org/draft-07/schema#':
        return draft7;
      case 'https://json-schema.org/draft-04/schema#':
        return draft4;
      case 'https://json-schema.org/draft-06/schema#':
        return draft6;
      case 'https://json-schema.org/draft-07/schema#':
        return draft7;
      case 'https://json-schema.org/draft/2019-09/schema':
        return draft2019_09;
      case 'https://json-schema.org/draft/2019-09/schema#':
        return draft2019_09;
      case 'https://json-schema.org/draft/2020-12/schema':
        return draft2020_12;
      case 'https://json-schema.org/draft/2020-12/schema#':
        return draft2020_12;
      default:
        return null;
    }
  }
}
