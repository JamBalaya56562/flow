(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

(* Destructuring visitor for tree-shaped patterns, parameteric over an action f
   to perform at the leaves. A type for the pattern is passed, which is taken
   apart as the visitor goes deeper. *)

module Ast = Flow_ast
module Tast_utils = Typed_ast_utils
open Reason
open Type
open TypeUtil

module Make (Statement : Statement_sig.S) : Destructuring_sig.S = struct
  type state = {
    has_parent: bool;
    init: (ALoc.t, ALoc.t) Flow_ast.Expression.t option;
    default: Type.t Default.t option;
  }

  type callback =
    use_op:Type.use_op -> name_loc:ALoc.t -> string -> Type.t Default.t option -> Type.t -> Type.t

  let empty ?init ?default ~annot:_ _current = { has_parent = false; init; default }

  let pattern_default cx (acc : state) = function
    | None -> (acc, None)
    | Some e ->
      let default = acc.default in
      let (((_, t), _) as e) = Statement.expression cx e in
      let default = Some (Default.expr ?default t) in
      let acc = { acc with default } in
      (acc, Some e)

  let array_element cx acc i loc =
    let { init; default; _ } = acc in
    let key = DefT (mk_reason RNumber loc, NumT_UNSOUND (None, (float i, string_of_int i))) in
    let reason = mk_reason (RArrayNthElement i) loc in
    let init =
      Base.Option.map init ~f:(fun init ->
          ( loc,
            let open Ast.Expression in
            Member
              {
                Member._object = init;
                property =
                  Member.PropertyExpression
                    ( loc,
                      Ast.Expression.NumberLiteral
                        {
                          Ast.NumberLiteral.value = float i;
                          raw = string_of_int i;
                          comments = None;
                        }
                    );
                comments = None;
              }
          )
      )
    in
    let refinement =
      Base.Option.bind init ~f:(fun init -> Refinement.get ~allow_optional:true cx init loc)
    in
    let has_parent = Base.Option.is_none refinement in
    let default = Base.Option.map default ~f:(Default.elem key reason) in
    { has_parent; init; default }

  let array_rest_element (acc : state) i loc =
    let default = acc.default in
    let reason = mk_reason RArrayPatternRestProp loc in
    let default = Base.Option.map default ~f:(Default.arr_rest i reason) in
    { acc with has_parent = true; default }

  let object_named_property ~has_default ~parent_loc cx acc loc x comments =
    let { init; default; _ } = acc in
    let reason = mk_reason (RProperty (Some (OrdinaryName x))) loc in
    let init =
      Base.Option.map init ~f:(fun init ->
          ( loc,
            let open Ast.Expression in
            Member
              {
                Member._object = init;
                property = Member.PropertyIdentifier (loc, { Ast.Identifier.name = x; comments });
                comments = None;
              }
          )
      )
    in
    let refinement =
      Base.Option.bind init ~f:(fun init -> Refinement.get ~allow_optional:true cx init loc)
    in
    let default =
      Base.Option.map default ~f:(fun default ->
          let d = Default.prop x reason has_default default in
          if has_default then
            Default.default reason d
          else
            d
      )
    in
    let parent_loc =
      match refinement with
      | Some _ -> None
      | None -> Some parent_loc
    in
    let has_parent = Base.Option.is_some parent_loc in
    { has_parent; init; default }

  let object_computed_property cx acc e =
    let { init; default; _ } = acc in
    let (((loc, t), _) as e') = Statement.expression cx e in
    let reason = mk_reason (RProperty None) loc in
    let init =
      Base.Option.map init ~f:(fun init ->
          ( loc,
            Ast.Expression.(
              Member Member.{ _object = init; property = PropertyExpression e; comments = None }
            )
          )
      )
    in
    let default = Base.Option.map default ~f:(Default.elem t reason) in
    ({ has_parent = true; init; default }, e')

  let object_rest_property (acc : state) xs loc =
    let default = acc.default in
    let reason = mk_reason RObjectPatternRestProp loc in
    let default = Base.Option.map default ~f:(Default.obj_rest xs reason) in
    { acc with has_parent = true; default }

  let object_property
      cx
      ~has_default
      ~parent_loc
      ~current
      (acc : state)
      xs
      (key : (ALoc.t, ALoc.t) Ast.Pattern.Object.Property.key) :
      state * string list * (ALoc.t, ALoc.t * Type.t) Ast.Pattern.Object.Property.key =
    let open Ast.Pattern.Object in
    match key with
    | Property.Identifier (loc, { Ast.Identifier.name = x; comments }) ->
      let acc = object_named_property ~has_default ~parent_loc cx acc loc x comments in
      (acc, x :: xs, Property.Identifier ((loc, current), { Ast.Identifier.name = x; comments }))
    | Property.StringLiteral (loc, ({ Ast.StringLiteral.value = x; _ } as lit)) ->
      let acc = object_named_property ~has_default ~parent_loc cx acc loc x None in
      (acc, x :: xs, Property.StringLiteral (loc, lit))
    | Property.Computed (loc, { Ast.ComputedKey.expression; comments }) ->
      let (acc, e) = object_computed_property cx acc expression in
      (acc, xs, Property.Computed (loc, { Ast.ComputedKey.expression = e; comments }))
    | Property.NumberLiteral (loc, ({ Ast.NumberLiteral.value; comments; _ } as lit))
      when Js_number.is_float_safe_integer value ->
      let name = Dtoa.ecma_string_of_float value in
      let acc = object_named_property ~has_default ~parent_loc cx acc loc name comments in
      (acc, name :: xs, Property.NumberLiteral (loc, lit))
    | Property.NumberLiteral (loc, _)
    | Property.BigIntLiteral (loc, _) ->
      Flow_js.add_output
        cx
        (Error_message.EUnsupportedSyntax
           (loc, Flow_intermediate_error_types.DestructuringObjectPropertyInvalidLiteral)
        );
      (acc, xs, Tast_utils.error_mapper#pattern_object_property_key key)

  let identifier cx ~f acc name_loc name =
    let { init; default; _ } = acc in
    let reason = mk_reason (RIdentifier (OrdinaryName name)) name_loc in
    let current =
      mod_reason_of_t
        (update_desc_reason (function
            | RDefaultValue
            | RArrayPatternRestProp
            | RObjectPatternRestProp ->
              RIdentifier (OrdinaryName name)
            | desc -> desc
            )
            )
        (Type_env.find_write cx Env_api.OrdinaryNameLoc reason)
    in
    let use_op =
      Op
        (AssignVar
           {
             var = Some reason;
             init =
               (match (default, init) with
               | (Some (Default.Expr t), _) -> reason_of_t t
               | (_, Some init) -> mk_expression_reason init
               | _ -> reason_of_t current);
           }
        )
    in
    f ~use_op ~name_loc name default current

  let current_type cx (loc, p) =
    match p with
    | Ast.Pattern.Identifier
        { Ast.Pattern.Identifier.name = (name_loc, { Ast.Identifier.name; _ }); _ } ->
      Type_env.find_write
        cx
        Env_api.OrdinaryNameLoc
        (mk_reason (RIdentifier (OrdinaryName name)) name_loc)
    | Ast.Pattern.Expression _ ->
      (* Expression in pattern destructuring is unsupported syntax,
         so we shouldn't read the environment. *)
      AnyT.untyped (mk_reason RDestructuring loc)
    | _ when Flow_ast_utils.pattern_has_binding (loc, p) ->
      Type_env.find_write cx Env_api.PatternLoc (mk_reason RDestructuring loc)
    | _ -> Unsoundness.at Type.NonBindingPattern loc

  let rec pattern cx ~(f : callback) acc (loc, p) =
    let check_for_invalid_annot annot =
      match (acc.has_parent, annot) with
      | (true, Ast.Type.Available (loc, _)) ->
        Flow_js.add_output
          cx
          (Error_message.EUnsupportedSyntax
             (loc, Flow_intermediate_error_types.AnnotationInsideDestructuring)
          )
      | _ -> ()
    in
    let open Ast.Pattern in
    ( (loc, current_type cx (loc, p)),
      match p with
      | Array { Array.elements; annot; comments } ->
        check_for_invalid_annot annot;
        let elements = array_elements cx ~f acc elements in
        let annot = Tast_utils.unimplemented_mapper#type_annotation_hint annot in
        Array { Array.elements; annot; comments }
      | Object { Object.properties; annot; comments } ->
        check_for_invalid_annot annot;
        let properties = object_properties cx ~f ~parent_loc:loc acc properties in
        let annot = Tast_utils.unimplemented_mapper#type_annotation_hint annot in
        Object { Object.properties; annot; comments }
      | Identifier { Identifier.name = id; optional; annot } ->
        let (id_loc, { Ast.Identifier.name; comments }) = id in
        check_for_invalid_annot annot;
        let annot = Tast_utils.unimplemented_mapper#type_annotation_hint annot in
        let id_ty = identifier cx ~f acc id_loc name in
        let id = ((id_loc, id_ty), { Ast.Identifier.name; comments }) in
        Identifier { Identifier.name = id; optional; annot }
      | Expression e ->
        Flow_js.add_output
          cx
          (Error_message.EUnsupportedSyntax
             (loc, Flow_intermediate_error_types.DestructuringExpressionPattern)
          );
        Expression (Tast_utils.error_mapper#expression e)
    )

  and array_elements cx ~f acc =
    let open Ast.Pattern.Array in
    Base.List.mapi ~f:(fun i -> function
      | Hole loc -> Hole loc
      | Element (loc, { Element.argument = p; default = d }) ->
        let acc = array_element cx acc i loc in
        let (acc, d) = pattern_default cx acc d in
        let p = pattern cx ~f acc p in
        Element (loc, { Element.argument = p; default = d })
      | RestElement (loc, { Ast.Pattern.RestElement.argument = (arg_loc, _) as p; comments }) ->
        let acc = array_rest_element acc i arg_loc in
        let p = pattern cx ~f acc p in
        RestElement (loc, { Ast.Pattern.RestElement.argument = p; comments })
    )

  and object_properties =
    let open Ast.Pattern.Object in
    let prop cx ~f ~parent_loc acc xs p =
      match p with
      | Property (loc, { Property.key; pattern = p; default = d; shorthand }) ->
        let has_default = d <> None in
        let current = current_type cx p in
        let (acc, xs, key) = object_property cx ~has_default ~parent_loc ~current acc xs key in
        let (acc, d) = pattern_default cx acc d in
        let p = pattern cx ~f acc p in
        (xs, Property (loc, { Property.key; pattern = p; default = d; shorthand }))
      | RestElement (loc, { Ast.Pattern.RestElement.argument = (arg_loc, _) as p; comments }) ->
        let acc = object_rest_property acc xs arg_loc in
        let p = pattern cx ~f acc p in
        (xs, RestElement (loc, { Ast.Pattern.RestElement.argument = p; comments }))
    in
    let rec loop cx ~f ~parent_loc acc xs rev_ps = function
      | [] -> List.rev rev_ps
      | p :: ps ->
        let (xs, p) = prop cx ~f ~parent_loc acc xs p in
        loop cx ~f ~parent_loc acc xs (p :: rev_ps) ps
    in
    (fun cx ~f ~parent_loc acc ps -> loop cx ~f ~parent_loc acc [] [] ps)

  let type_of_pattern (_, p) =
    let open Ast.Pattern in
    match p with
    | Array { Array.annot; _ }
    | Object { Object.annot; _ }
    | Identifier { Identifier.annot; _ } ->
      annot
    | _ -> Ast.Type.Missing ALoc.none

  (* instantiate pattern visitor for assignments *)
  let assignment cx rhs_t init =
    let acc = empty ~init ~annot:false rhs_t in
    let f ~use_op ~name_loc name _default t =
      (* TODO destructuring+defaults unsupported in assignment expressions *)
      ignore Type_env.(set_var cx ~use_op name t name_loc);
      Type_env.constraining_type ~default:t cx name name_loc
    in
    pattern cx ~f acc
end
