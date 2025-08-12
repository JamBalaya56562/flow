(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

module Ast = Flow_ast

(*
 * type refinements on expressions - wraps Env API
 *)

(* if expression is syntactically eligible for type refinement,
   return Some (access key), otherwise None.
   Eligible expressions are simple ids and chains of property|index
   lookups from an id base
*)

module Keys = struct
  let rec key ~allow_optional =
    let open Ast.Expression in
    function
    | (_, This _) ->
      (* treat this as a property chain, in terms of refinement lifetime *)
      Some (Key.This, [])
    | (_, Super _) ->
      (* treat this as a property chain, in terms of refinement lifetime *)
      Some (Key.Super, [])
    | (_, Identifier id) -> key_of_identifier id
    | (_, OptionalMember { OptionalMember.member; _ }) when allow_optional ->
      key_of_member ~allow_optional member
    | (_, Member member) -> key_of_member ~allow_optional member
    | _ ->
      (* other LHSes unsupported currently/here *)
      None

  and key_of_identifier (_, { Ast.Identifier.name; comments = _ }) =
    if name = "undefined" then
      None
    else
      Some (Key.OrdinaryIdentifier name, [])

  and key_of_member ~allow_optional { Ast.Expression.Member._object; property; _ } =
    let open Ast.Expression.Member in
    match property with
    | PropertyIdentifier (_, { Ast.Identifier.name; comments = _ })
    | PropertyExpression (_, Ast.Expression.StringLiteral { Ast.StringLiteral.value = name; _ }) ->
      (match key ~allow_optional _object with
      | Some (base, chain) -> Some (base, Key.Prop name :: chain)
      | None -> None)
    | PropertyExpression
        (_, Ast.Expression.NumberLiteral { Ast.NumberLiteral.value; raw = _; comments = _ }) ->
      if Js_number.is_float_safe_integer value then
        let name = Dtoa.ecma_string_of_float value in
        match key ~allow_optional _object with
        | Some (base, chain) -> Some (base, Key.Prop name :: chain)
        | None -> None
      else
        None
    | PropertyPrivateName (_, { Ast.PrivateName.name; comments = _ }) ->
      (match key ~allow_optional _object with
      | Some (base, chain) -> Some (base, Key.PrivateField name :: chain)
      | None -> None)
    | PropertyExpression index ->
      (* foo.bar[baz] -> Chain [Index baz; Id bar; Id foo] *)
      (match key ~allow_optional _object with
      | Some (base, chain) ->
        (match key ~allow_optional index with
        | Some key -> Some (base, Key.Elem key :: chain)
        | None -> None)
      | None -> None)
end

include Keys

(* get type refinement for expression, if it exists *)
let get ~allow_optional cx expr loc =
  match key ~allow_optional expr with
  | Some k -> Type_env.get_refinement cx (Key.reason_desc k) loc
  | None -> None
