(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

type ('M, 'T) member_info = {
  prop_name: string;
  object_type: 'T;
  force_instance: bool;
}
[@@deriving show]

type ('M, 'T) t =
  | Identifier of {
      name: string;
      loc: 'M;
    }
  | Member of ('M, 'T) member_info
  | JsxAttribute of {
      component_t: 'T;
      name: string;
      loc: 'M;
    }
[@@deriving show]
