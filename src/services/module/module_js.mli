(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

type package_info = Package_json.t option

(* export and import functions for the module system *)
val exported_module :
  options:Options.t -> File_key.t -> package_info:package_info -> Haste_module_info.t option

type phantom_acc = Parsing_heaps.dependency_addr option Modulename.Map.t ref

val imported_module :
  options:Options.t ->
  reader:Abstract_state_reader.t ->
  node_modules_containers:SSet.t SMap.t ->
  importing_file:File_key.t ->
  ?phantom_acc:phantom_acc ->
  Flow_import_specifier.t ->
  Parsing_heaps.dependency_addr Parsing_heaps.resolved_module'

(* repick providers for dirty modules *)
val commit_modules :
  workers:MultiWorkerLwt.worker list option ->
  options:Options.t ->
  (* dirty modules *)
  Modulename.Set.t ->
  (* changed modules and duplicate providers *)
  (Modulename.Set.t * (File_key.t * File_key.t Nel.t) SMap.t) Lwt.t

(* filenames to error sets *)

(* resolve and add requires from context to store *)
val add_parsed_resolved_requires :
  mutator:Parsing_heaps.Resolved_requires_mutator.t ->
  reader:Mutator_state_reader.t ->
  options:Options.t ->
  node_modules_containers:SSet.t SMap.t ->
  File_key.t ->
  unit

type package_incompatible_reason =
  | New
  | Became_invalid
  | Became_valid
  | Name_changed of string option * string option
  | Main_changed of string option * string option
  | Haste_commonjs_changed of bool
  | Exports_changed
  | Unknown

val string_of_package_incompatible_reason : package_incompatible_reason -> string

type package_incompatible_return =
  | Compatible
  | Incompatible of package_incompatible_reason

val package_incompatible :
  reader:State_reader.t -> File_key.t -> (Package_json.t, _) result -> package_incompatible_return
