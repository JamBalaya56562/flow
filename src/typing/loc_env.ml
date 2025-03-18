(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

(** New Environment:
    New environment maps locs to types using the ssa builder
 **)

open Loc_collections
module EnvMap = Env_api.EnvMap

type type_entry =
  | TypeEntry of {
      t: Type.t;
      state: Type.t lazy_t ref;
    }

type t = {
  types: type_entry EnvMap.t;
  tparams: (Subst_name.t * Type.typeparam * Type.t) ALocMap.t;
  class_bindings: Type.class_binding ALocMap.t;
  class_stack: ALoc.t list;
  scope_kind: Name_def.scope_kind;
  ast_hint_map: Name_def.hint_map;
  hint_map: Type.lazy_hint_t ALocMap.t;
  var_info: Env_api.env_info;
  pred_func_map: Type.pred_funcall_info Lazy.t ALocMap.t;
  name_defs: Name_def.env_entries_map;
}

let initialize info def_loc_kind loc state =
  let types =
    EnvMap.update
      (def_loc_kind, loc)
      (function
        | Some _ -> failwith (Utils_js.spf "%s already initialized" (Reason.string_of_aloc loc))
        | None -> Some state)
      info.types
  in
  { info with types }

let update_reason ({ types; _ } as info) def_loc_kind loc reason =
  let f _ = reason in
  let types =
    EnvMap.update
      (def_loc_kind, loc)
      (function
        | Some (TypeEntry { t; state }) ->
          Some (TypeEntry { t = TypeUtil.mod_reason_of_t f t; state })
        | None -> failwith "Cannot update reason on non-existent entry")
      types
  in
  { info with types }

let find_write { types; _ } def_loc_kind loc = EnvMap.find_opt (def_loc_kind, loc) types

let find_ordinary_write env loc = find_write env Env_api.OrdinaryNameLoc loc

let empty scope_kind =
  {
    types = EnvMap.empty;
    var_info = Env_api.empty;
    tparams = ALocMap.empty;
    class_bindings = ALocMap.empty;
    class_stack = [];
    scope_kind;
    ast_hint_map = ALocMap.empty;
    hint_map = ALocMap.empty;
    pred_func_map = ALocMap.empty;
    name_defs = EnvMap.empty;
  }

let with_info scope_kind ast_hint_map hint_map var_info pred_func_map name_defs =
  let env = empty scope_kind in
  { env with ast_hint_map; hint_map; var_info; pred_func_map; name_defs }
