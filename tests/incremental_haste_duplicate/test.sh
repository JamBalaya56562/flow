#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

printf "\nInitial status:\n"
assert_ok "$FLOW" status --no-auto-start --strip-root .

printf "\nCopy A.js to nested/A.js:\n"
mkdir nested
cp A.js nested/A.js
assert_ok "$FLOW" force-recheck --no-auto-start A.js nested/A.js
assert_errors "$FLOW" status --no-auto-start --strip-root .

printf "\nMove nested/A.js to A.js:\n"
mv nested/A.js A.js
assert_ok "$FLOW" force-recheck --no-auto-start A.js nested/A.js
assert_ok "$FLOW" status --no-auto-start --strip-root .

printf "\nDone!\n"
