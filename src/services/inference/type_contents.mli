(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

val parse_contents :
  options:Options.t ->
  profiling:Profiling_js.running ->
  (* contents *)
  string ->
  (* fake file-/module name *)
  File_key.t ->
  Types_js_types.parse_artifacts option * Flow_error.ErrorSet.t

val type_parse_artifacts :
  options:Options.t ->
  profiling:Profiling_js.running ->
  Context.master_context ->
  (* fake file-/module name *)
  File_key.t ->
  Types_js_types.parse_artifacts option * Flow_error.ErrorSet.t ->
  (Types_js_types.file_artifacts, Flow_error.ErrorSet.t) result

val printable_errors_of_file_artifacts_result :
  options:Options.t ->
  env:ServerEnv.env ->
  (* fake file-/module name *)
  File_key.t ->
  (Types_js_types.file_artifacts, Flow_error.ErrorSet.t) result ->
  (* errors *)
  Flow_errors_utils.ConcreteLocPrintableErrorSet.t
  * (* warnings *)
    Flow_errors_utils.ConcreteLocPrintableErrorSet.t

val compute_env_of_contents :
  options:Options.t ->
  profiling:Profiling_js.running ->
  reader:Parsing_heaps.Reader.reader ->
  Context.master_context ->
  File_key.t ->
  Docblock.t ->
  (Loc.t, Loc.t) Flow_ast.Program.t ->
  Flow_import_specifier.t array ->
  File_sig.t ->
  Context.t * (ALoc.t, ALoc.t) Flow_ast.Program.t

val check_contents :
  options:Options.t ->
  profiling:Profiling_js.running ->
  reader:Parsing_heaps.Reader.reader ->
  Context.master_context ->
  File_key.t ->
  Docblock.t ->
  (Loc.t, Loc.t) Flow_ast.Program.t ->
  Flow_import_specifier.t array ->
  File_sig.t ->
  Context.t * (ALoc.t, ALoc.t * Type.t) Flow_ast.Program.t
