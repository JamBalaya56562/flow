(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

val func_details :
  jsdoc:Jsdoc.t option ->
  exact_by_default:bool ->
  ts_syntax:bool ->
  (string option * Ty.t * Ty.fun_param) Base.List.t ->
  (string option * Ty.t) option ->
  Ty.return_t ->
  ServerProt.Response.func_details_result

val find_signatures :
  loc_of_aloc:(ALoc.t -> Loc.t) ->
  get_ast_from_shared_mem:(File_key.t -> (Loc.t, Loc.t) Flow_ast.Program.t option) ->
  cx:Context.t ->
  file_sig:File_sig.t ->
  ast:(Loc.t, Loc.t) Flow_ast.Program.t ->
  typed_ast:(ALoc.t, ALoc.t * Type.t) Flow_ast.Program.t ->
  Loc.t ->
  ((ServerProt.Response.func_details_result list * int) option, Ty_normalizer.error) result
