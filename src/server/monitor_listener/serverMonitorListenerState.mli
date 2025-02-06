(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

type env_update = ServerEnv.env -> ServerEnv.env

(* APIs to add to the state *)
val push_new_workload : name:string -> WorkloadStream.workload -> unit

val push_new_parallelizable_workload : name:string -> WorkloadStream.parallelizable_workload -> unit

val defer_parallelizable_workload : name:string -> WorkloadStream.parallelizable_workload -> unit

val requeue_deferred_parallelizable_workloads : unit -> unit

val push_new_env_update : env_update -> unit

val push_lazy_init : ?metadata:MonitorProt.file_watcher_metadata -> SSet.t -> unit

val push_files_to_recheck : ?metadata:MonitorProt.file_watcher_metadata -> SSet.t -> unit

val push_files_to_prioritize : SSet.t -> unit

val push_files_to_force_focused_and_recheck : SSet.t -> unit

val push_global_find_ref_request :
  request:FindRefsTypes.request ->
  client:Persistent_connection.single_client ->
  references_to_lsp_response:
    ((FindRefsTypes.single_ref list, string) result -> LspProt.response * LspProt.metadata) ->
  Loc.t list ->
  unit

val push_dependencies_to_prioritize : Utils_js.FilenameSet.t -> unit

val push_after_reinit :
  ?files_to_prioritize:Utils_js.FilenameSet.t ->
  ?files_to_recheck:Utils_js.FilenameSet.t ->
  ?files_to_force:CheckedSet.t ->
  unit ->
  unit

val cancellation_requests : Lsp.IdSet.t ref

type recheck_workload = {
  files_to_prioritize: Utils_js.FilenameSet.t;
  files_to_recheck: Utils_js.FilenameSet.t;
  files_to_force: CheckedSet.t;
  find_ref_command:
    ( FindRefsTypes.request
    * Persistent_connection.single_client
    * ((FindRefsTypes.single_ref list, string) result -> LspProt.response * LspProt.metadata)
    )
    option;
  metadata: MonitorProt.file_watcher_metadata;
  require_full_check_reinit: bool;
}

type workload_changes = {
  num_files_to_prioritize: int;
  num_files_to_recheck: int;
  num_files_to_force: int;
}

type priority =
  | Priority
  | Normal

type updates =
  | NormalUpdates of Utils_js.FilenameSet.t
  | RequiredFullCheckReinit of Utils_js.FilenameSet.t

(* APIs to wait *)
val wait_for_anything :
  process_updates:(skip_incompatible:bool -> SSet.t -> updates) ->
  get_forced:(unit -> CheckedSet.t) ->
  unit Lwt.t

val wait_for_updates_for_recheck :
  process_updates:(skip_incompatible:bool -> SSet.t -> updates) ->
  get_forced:(unit -> CheckedSet.t) ->
  priority:priority ->
  workload_changes Lwt.t

val pop_next_workload : unit -> WorkloadStream.workload_handler option

val pop_next_parallelizable_workload : unit -> WorkloadStream.parallelizable_workload option

val wait_for_parallelizable_workload : unit -> unit Lwt.t

val update_env : ServerEnv.env -> ServerEnv.env

val requeue_workload : recheck_workload -> unit

val get_and_clear_recheck_workload :
  process_updates:(skip_incompatible:bool -> SSet.t -> updates) ->
  get_forced:(unit -> CheckedSet.t) ->
  priority * recheck_workload
