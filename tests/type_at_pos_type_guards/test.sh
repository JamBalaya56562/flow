#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

queries_in_file "type-at-pos" "decls.js"
queries_in_file "type-at-pos" "test.js"
queries_in_file "type-at-pos" "inferred.js"
