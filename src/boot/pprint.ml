
(*
   Miking is licensed under the MIT license.
   Copyright (C) David Broman. See file LICENSE.txt
*)

open Ast
open Ustring.Op
open Printf


(* Debug options *)
let enable_debug_debruijn_print = true


(* Print out a variable, either in debug mode or not *)
let varDebugPrint x n =
  if enable_debug_debruijn_print
  then x ^. us(sprintf "'%d" n) else x



(* Print the kind of unified collection (UC) type. *)
let pprintUCKind ordered uniqueness =
  match ordered, uniqueness with
  | UCUnordered, UCUnique      -> us"Set"      (* Set *)
  | UCUnordered, UCMultivalued -> us"MSet"     (* Multivalued Set *)
  | UCOrdered,   UCUnique      -> us"USeq"     (* Unique Sequence *)
  | UCOrdered,   UCMultivalued -> us"Seq"      (* Sequence *)
  | UCSorted,    UCUnique      -> us"SSet"     (* Sorted Set *)
  | UCSorted,    UCMultivalued -> us"SMSet"    (* Sorted Multivalued Set *)

(* Pretty printing for precedence *)
let left inside = if inside then us"(" else us""
let right inside = if inside then us")" else us""


(* Pretty print "true" or "false" *)
let usbool x = us (if x then "true" else "false")

(* Collapses the UC structure into a revered ordered list *)
let uct2revlist uc =
  let rec apprev lst acc =
    match lst with
    | l::ls -> apprev ls (l::acc)
    | [] -> acc
  in
  let rec work uc acc =
    match uc with
    | UCLeaf(lst) -> apprev lst acc
    | UCNode(uc1,uc2) -> work uc2 (work uc1 acc)
  in work uc []

(* Translate a unified collection (UC) structure into a list *)
let uct2list uct = uct2revlist uct |> List.rev

(* Pretty print a pattern *)
let rec pprint_pat pat =
  match pat with
  | PatIdent(_,s) -> s
  | PatChar(_,c) -> us"'" ^. list2ustring [c] ^. us"'"
  | PatUC(_,plst,_,_)
      -> us"[" ^. (Ustring.concat (us",") (List.map pprint_pat plst)) ^. us"]"
  | PatBool(_,b) -> us(if b then "true" else "false")
  | PatInt(_,i) -> us(sprintf "%d" i)
  | PatConcat(_,p1,p2) -> (pprint_pat p1) ^. us"++" ^. (pprint_pat p2)

(* Converts a UC to a ustring *)
let uc2ustring uclst =
    List.map
      (fun x -> match x with
      |TmChar(_,i) -> i
      | _ -> failwith "Not a string list") uclst


(* Pretty print match cases *)
let rec pprint_cases basic cases =
   Ustring.concat (us" else ") (List.map
    (fun (Case(_,p,t)) -> pprint_pat p ^. us" => " ^. pprint basic t) cases)

(* Pretty print constants *)
and pprint_const c =
  match c with
  (* MCore Intrinsic Booleans *)
  | CBool(b) -> if b then us"true" else us"false"
  | Cnot -> us"not"
  | Cand(None) -> us"and"
  | Cand(Some(v)) -> us"and(" ^. usbool v ^. us")"
  | Cor(None) -> us"or"
  | Cor(Some(v)) -> us"or(" ^. usbool v ^. us")"
  (* MCore Intrinsic Integers *)
  | CInt(v) -> us(sprintf "%d" v)
  | Caddi(None) -> us"addi"
  | Caddi(Some(v)) -> us(sprintf "addi(%d)" v)
  | Csubi(None) -> us"subi"
  | Csubi(Some(v)) -> us(sprintf "subi(%d)" v)
  | Cmuli(None) -> us"muli"
  | Cmuli(Some(v)) -> us(sprintf "muli(%d)" v)
  | Cdivi(None) -> us"divi"
  | Cdivi(Some(v)) -> us(sprintf "divi(%d)" v)
  | Cmodi(None) -> us"modi"
  | Cmodi(Some(v)) -> us(sprintf "modi(%d)" v)
  | Cnegi -> us"negi"
  | Clti(None) -> us"lti"
  | Clti(Some(v)) -> us(sprintf "lti(%d)" v)
  | Cleqi(None) -> us"leqi"
  | Cleqi(Some(v)) -> us(sprintf "leqi(%d)" v)
  | Cgti(None) -> us"gti"
  | Cgti(Some(v)) -> us(sprintf "gti(%d)" v)
  | Cgeqi(None) -> us"geqi"
  | Cgeqi(Some(v)) -> us(sprintf "geqi(%d)" v)
  | Ceqi(None) -> us"eqi"
  | Ceqi(Some(v)) -> us(sprintf "eqi(%d)" v)
  | Cneqi(None) -> us"neqi"
  | Cneqi(Some(v)) -> us(sprintf "neqi(%d)" v)
  | Cslli(None) -> us"slli"
  | Cslli(Some(v)) -> us(sprintf "slli(%d)" v)
  | Csrli(None) -> us"srli"
  | Csrli(Some(v)) -> us(sprintf "srli(%d)" v)
  | Csrai(None) -> us"srai"
  | Csrai(Some(v)) -> us(sprintf "srai(%d)" v)
  (* MCore intrinsic: Floating-point number constant and operations *)
  | CFloat(v) -> us(sprintf "%f" v)
  | Caddf(None) -> us"addf"
  | Caddf(Some(v)) -> us(sprintf "addf(%f)" v)
  | Csubf(None) -> us"subf"
  | Csubf(Some(v)) -> us(sprintf "subf(%f)" v)
  | Cmulf(None) -> us"mulf"
  | Cmulf(Some(v)) -> us(sprintf "mulf(%f)" v)
  | Cdivf(None) -> us"divf"
  | Cdivf(Some(v)) -> us(sprintf "divf(%f)" v)
  | Cnegf -> us"negf"
  (* Mcore intrinsic: Polymorphic integer and floating-point numbers *)
  | Cadd(TInt(v)) -> us(sprintf "add(%d)" v)
  | Cadd(TFloat(v)) -> us(sprintf "add(%f)" v)
  | Cadd(TNone) -> us"add"
  | Csub(TInt(v)) -> us(sprintf "sub(%d)" v)
  | Csub(TFloat(v)) -> us(sprintf "sub(%f)" v)
  | Csub(TNone) -> us"sub"
  | Cmul(TInt(v)) -> us(sprintf "mul(%d)" v)
  | Cmul(TFloat(v)) -> us(sprintf "mul(%f)" v)
  | Cmul(TNone) -> us"mul"
  | Cdiv(TInt(v)) -> us(sprintf "div(%d)" v)
  | Cdiv(TFloat(v)) -> us(sprintf "div(%f)" v)
  | Cdiv(TNone) -> us"div"
  | Cneg -> us"neg"
  (* MCore debug and stdio intrinsics *)
  | CDStr -> us"dstr"
  | CDPrint -> us"dprint"
  | CPrint -> us"print"
  | CArgv  -> us"argv"
  (* MCore unified collection type (UCT) intrinsics *)
  | CConcat(None) -> us"concat"
  | CConcat(Some(v)) -> us"concat(" ^. (pprint true v) ^. us")"
  (* Ragnar polymorpic temps *)
  | CPolyEq(None) -> us"polyeq"
  | CPolyEq(Some(v)) -> us"polyeq(" ^. (pprint true v) ^. us")"
  | CPolyNeq(None) -> us"polyneq"
  | CPolyNeq(Some(v)) -> us"polyneq(" ^. (pprint true v) ^. us")"
  (* Atom - an untyped lable that can be used to implement
     domain specific constructs *)
  | CAtom(id,tms) -> us"[" ^. (ustring_of_sid id) ^. us"]" ^.
      (if List.length tms = 0 then us""
       else us"(" ^. Ustring.concat (us",") (List.map (pprint true) tms) ^. us")")


(* Pretty print a term. The boolean parameter 'basic' is true when
   the pretty printing should be done in basic form. Use e.g. Set(1,2) instead of {1,2} *)
and pprint basic t =
  let rec ppt inside t =
  match t with
  | TmVar(_,x,n,_) -> varDebugPrint x n
  | TmLam(_,x,ty,t1) -> left inside ^.
      us"lam " ^. x ^. us":" ^. pprint_ty ty ^. us". " ^. ppt false t1 ^. right inside
  | TmClos(_,x,_,t,_,false) -> left inside ^. us"clos " ^. x ^. us". " ^.
       ppt false t ^. right inside
  | TmClos(_,x,_,t,_,true) -> left inside ^. us"peclos " ^.
       x ^. us". " ^. ppt false t ^. right inside
  | TmApp(_,t1,t2) ->
       left inside ^. ppt true t1  ^. us" " ^. ppt true t2 ^. right inside
  | TmConst(_,c) -> pprint_const c
  | TmFix(_) -> us"fix"
  | TmTyLam(_,x,kind,t1) -> left inside ^. us"Lam " ^. x ^. us"::"
      ^. pprint_kind kind ^. us". " ^. ppt false t1  ^. us"" ^. right inside
  | TmTyApp(_,t1,ty1) ->
      left inside ^. ppt false t1 ^. us" [" ^. pprint_ty ty1 ^. us"]" ^. right inside
  | TmDive(_) -> us"dive"
  | TmIfexp(_,None,_) -> us"ifexp"
  | TmIfexp(_,Some(g),Some(t2)) ->
      us"ifexp(" ^. usbool g ^. us"," ^. ppt false t2 ^. us")"
  | TmIfexp(_,Some(g),_) -> us"ifexp(" ^. usbool g ^. us")"
  | TmChar(_,c) -> us"'" ^. list2ustring [c] ^. us"'"
  | TmUC(_,uct,ordered,uniqueness) -> (
    match ordered, uniqueness with
    | UCOrdered,UCMultivalued when not basic ->
      let lst = uct2list uct in
      (match lst with
      | TmChar(_,_)::_ ->
        let intlst = uc2ustring lst in
        us"\"" ^. list2ustring intlst ^.  us"\""
      | _ -> us"[" ^. (Ustring.concat (us",") (List.map (ppt false) lst)) ^. us"]")
    | _,_ ->
        (pprintUCKind ordered uniqueness) ^. us"(" ^.
          (Ustring.concat (us",") (List.map (ppt false) (uct2list uct))) ^. us")")
  | TmUtest(_,t1,t2,_) -> us"utest " ^. ppt false t1  ^. us" " ^. ppt false t2
  | TmNop -> us"Nop"
  in ppt false t

(* Pretty prints the environment *)
and pprint_env env =
  us"[" ^. (List.mapi (fun i t -> us(sprintf " %d -> " i) ^. pprint true t) env
            |> Ustring.concat (us",")) ^. us"]"

(* Pretty prints the typing environment *)
and pprint_tyenv env =
  us"[" ^.
    (List.mapi (fun i t -> us(sprintf " %d -> " i) ^.
      (match t with
      | TyenvTmvar(x,ty) -> x ^. us":" ^. pprint_ty ty
      | TyenvTyvar(x,ki) -> x ^. us":" ^. us"::" ^. pprint_kind ki)
     ) env
            |> Ustring.concat (us",")) ^. us"]"




(* Pretty print a type *)
and pprint_ty ty =
  let rec ppt inside ty =
  match ty with
  | TyGround(_,gt) ->
    (match gt with
    | GBool -> us"Bool"
    | GInt -> us"Int"
    | GFloat -> us"Float"
    | GVoid -> us"Void")
  | TyArrow(_,ty1,ty2) ->
      left inside ^. ppt true ty1 ^. us"->" ^. ppt false ty2 ^. right inside
  | TyVar(_,x,n) -> varDebugPrint x n
  | TyAll(_,x,kind,ty1) -> left inside ^. us"all " ^. x ^. us"::" ^.
         pprint_kind kind ^. us". " ^. ppt false ty1 ^. right inside
  | TyLam(_,x,kind,ty1) -> left inside ^. us"lam " ^. x ^. us"::" ^.
         pprint_kind kind ^. us". " ^. ppt false ty1 ^. right inside
  | TyApp(_,ty1,ty2) ->
    left inside ^. ppt true ty1 ^. us" " ^. ppt true ty2 ^. right inside
 | TyDyn -> us"Dyn"
  in
    ppt true ty

(* Pretty print kinds *)
and pprint_kind k =
  let rec ppt inside k =
  match k with
  | KindStar(_) -> us"*"
  | KindArrow(_,k1,k2) ->
    left inside ^. ppt true k1 ^. us"->" ^. ppt false k2 ^. right inside
  in ppt false k
