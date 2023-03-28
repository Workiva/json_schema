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

class SchemaType implements Comparable<SchemaType> {
  const SchemaType._(this.value);

  static const SchemaType array = SchemaType._(0);

  static const SchemaType boolean = SchemaType._(1);

  static const SchemaType integer = SchemaType._(2);

  static const SchemaType number = SchemaType._(3);

  static const SchemaType nullValue = SchemaType._(4);

  static const SchemaType object = SchemaType._(5);

  static const SchemaType string = SchemaType._(6);

  static List<SchemaType> get values => const <SchemaType>[array, boolean, integer, number, nullValue, object, string];

  final int value;

  @override
  int get hashCode => value;

  @override
  bool operator ==(Object other) => other is SchemaType && other.hashCode == hashCode;

  SchemaType copy() => this;

  @override
  int compareTo(SchemaType other) => value.compareTo(other.value);

  @override
  String toString() {
    final typeToStringMap = {
      array: 'array',
      boolean: 'boolean',
      integer: 'integer',
      number: 'number',
      nullValue: 'null',
      object: 'object',
      string: 'string'
    };

    return typeToStringMap[this]!;
  }

  static SchemaType? fromString(String s) {
    if (s == null) return null;
    switch (s) {
      case 'array':
        return array;
      case 'boolean':
        return boolean;
      case 'integer':
        return integer;
      case 'number':
        return number;
      case 'null':
        return nullValue;
      case 'object':
        return object;
      case 'string':
        return string;
      default:
        return null;
    }
  }
}
