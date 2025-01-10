(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

module Ast = Flow_ast
module LocMap = Loc_collections.LocMap

let get_rename_order name new_name ref_kind =
  match ref_kind with
  | FindRefsTypes.PropertyDefinition
  | FindRefsTypes.PropertyAccess ->
    (new_name, name)
  | FindRefsTypes.Local -> (name, new_name)

class rename_mapper
  ~global ~(targets : FindRefsTypes.ref_kind Loc_collections.LocMap.t) ~(new_name : string) =
  object (this)
    inherit [Loc.t] Flow_ast_mapper.mapper as super

    method! identifier id =
      let open Flow_ast.Identifier in
      let (loc, { comments; name = _ }) = id in
      if LocMap.mem loc targets then
        (loc, { name = new_name; comments })
      else
        id

    method! import_named_specifier ~import_kind specifier =
      let open Flow_ast.Statement.ImportDeclaration in
      let { local; remote = (loc, _) as remote; remote_name_def_loc; kind } = specifier in
      if global then
        match local with
        | Some _ -> super#import_named_specifier ~import_kind specifier
        | None ->
          let new_remote = Ast_builder.Identifiers.identifier new_name in
          if LocMap.mem loc targets then
            { local = None; remote = new_remote; remote_name_def_loc; kind }
          else
            specifier
      else
        match local with
        | Some _ -> super#import_named_specifier ~import_kind specifier
        | None ->
          if LocMap.mem loc targets then
            let localName = Ast_builder.Identifiers.identifier new_name in
            { local = Some localName; remote; remote_name_def_loc; kind }
          else
            specifier

    method! export_named_declaration_specifier specifier =
      let open Ast.Statement.ExportNamedDeclaration.ExportSpecifier in
      let (specifier_loc, { local = (loc, local_id); exported; from_remote; imported_name_def_loc })
          =
        specifier
      in
      match exported with
      | Some _ -> super#export_named_declaration_specifier specifier
      | None ->
        if LocMap.mem loc targets then
          let export_specifier =
            {
              local = Ast_builder.Identifiers.identifier new_name;
              exported = Some (Loc.none, local_id);
              from_remote;
              imported_name_def_loc;
            }
          in
          (specifier_loc, export_specifier)
        else
          specifier

    method! pattern_object_property ?kind prop =
      let open Ast.Pattern.Object.Property in
      match prop with
      | (_loc, { key; shorthand = true; pattern = _; default = _ }) ->
        (match key with
        | Identifier (loc, { Ast.Identifier.name; comments }) when LocMap.mem loc targets ->
          let ref_kind = LocMap.find loc targets in
          let (from_name, to_name) = get_rename_order name new_name ref_kind in
          let new_ast =
            {
              key = Identifier (Loc.none, { Ast.Identifier.name = from_name; comments });
              pattern = Ast_builder.Patterns.identifier to_name;
              shorthand = false;
              default = None;
            }
          in
          (loc, new_ast)
        | Computed _
        | StringLiteral _
        | NumberLiteral _
        | BigIntLiteral _
        | Identifier _ ->
          super#pattern_object_property ?kind prop)
      | (_loc, { shorthand = false; key = _; pattern = _; default = _ }) ->
        super#pattern_object_property ?kind prop

    method! object_property prop =
      let open Ast.Expression.Object.Property in
      let (obj_loc, prop') = prop in
      match prop' with
      | Init
          { key = Identifier (loc, { Ast.Identifier.name; comments }); shorthand = true; value = _ }
        ->
        if LocMap.mem loc targets then
          let ref_kind = LocMap.find loc targets in
          let (from_name, to_name) = get_rename_order name new_name ref_kind in
          let new_prop' =
            Ast.Expression.Object.Property.Init
              {
                key = Identifier (Loc.none, { Ast.Identifier.name = from_name; comments });
                value = Ast_builder.Expressions.identifier to_name;
                shorthand = false;
              }
          in
          (obj_loc, new_prop')
        else
          prop
      | Init _
      | Method _
      | Get _
      | Set _ ->
        super#object_property prop

    method! member_property p =
      let open Ast.Expression.Member in
      match p with
      | PropertyPrivateName (loc, { Ast.PrivateName.comments; name = _ })
        when LocMap.mem loc targets ->
        if Base.String.is_prefix ~prefix:"#" new_name then
          PropertyPrivateName
            ( loc,
              { Ast.PrivateName.name = Base.String.chop_prefix_exn ~prefix:"#" new_name; comments }
            )
        else
          PropertyIdentifier (loc, { Ast.Identifier.name = new_name; comments })
      | _ -> super#member_property p

    method! object_key key =
      let open Ast.Expression.Object.Property in
      match key with
      | PrivateName (loc, { Ast.PrivateName.comments; name = _ }) when LocMap.mem loc targets ->
        if Base.String.is_prefix ~prefix:"#" new_name then
          PrivateName
            ( loc,
              { Ast.PrivateName.name = Base.String.chop_prefix_exn ~prefix:"#" new_name; comments }
            )
        else
          Identifier (loc, { Ast.Identifier.name = new_name; comments })
      | _ -> super#object_key key

    method! class_element elem =
      let open Ast.Class in
      match elem with
      | Body.PrivateField
          ( field_loc,
            {
              PrivateField.key = (key_loc, { Ast.PrivateName.name = _; comments = name_comments });
              value;
              annot;
              static;
              variance;
              decorators;
              comments;
            }
          )
        when LocMap.mem key_loc targets ->
        if Base.String.is_prefix ~prefix:"#" new_name then
          Body.PrivateField
            ( field_loc,
              this#class_private_field
                field_loc
                {
                  PrivateField.key =
                    ( key_loc,
                      {
                        Ast.PrivateName.name = Base.String.chop_prefix_exn ~prefix:"#" new_name;
                        comments = name_comments;
                      }
                    );
                  value;
                  annot;
                  static;
                  variance;
                  decorators;
                  comments;
                }
            )
        else
          Body.Property
            ( field_loc,
              this#class_property
                field_loc
                {
                  Property.key =
                    Ast.Expression.Object.Property.Identifier
                      (key_loc, { Ast.Identifier.name = new_name; comments = name_comments });
                  value;
                  annot;
                  static;
                  variance;
                  decorators;
                  comments;
                }
            )
      | _ -> super#class_element elem

    method! jsx_element_name_identifier id =
      let open Ast.JSX.Identifier in
      let (loc, { name = _; comments }) = id in
      if LocMap.mem loc targets then
        (loc, { name = new_name; comments })
      else
        id

    method! jsx_attribute_name name =
      let open Ast.JSX.Attribute in
      match name with
      | Identifier (loc, { Ast.JSX.Identifier.name = _; comments }) when LocMap.mem loc targets ->
        Identifier (loc, { Ast.JSX.Identifier.name = new_name; comments })
      | _ -> super#jsx_attribute_name name
  end

let rename ~global ~targets ~new_name ast =
  let s = new rename_mapper ~global ~targets ~new_name in
  s#program ast
