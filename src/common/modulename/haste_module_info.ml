(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

type t = {
  module_name: string;
  namespace_bitset: Bitset.t;
}
[@@deriving show]

let mk ~module_name ~namespace_bitset = { module_name; namespace_bitset }

let module_name { module_name; _ } = module_name

let namespace_bitset { namespace_bitset; _ } = namespace_bitset

let equal i1 i2 =
  String.equal i1.module_name i2.module_name && Bitset.equal i1.namespace_bitset i2.namespace_bitset

let compare i1 i2 =
  let c = String.compare i1.module_name i2.module_name in
  if c = 0 then
    Bitset.compare i1.namespace_bitset i2.namespace_bitset
  else
    c

let to_string { module_name; namespace_bitset } =
  module_name ^ ":" ^ Bitset.to_string namespace_bitset
