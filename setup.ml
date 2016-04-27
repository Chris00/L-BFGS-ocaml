(* OASIS_START *)
(* DO NOT EDIT (digest: 9852805d5c19ca1cb6abefde2dcea323) *)
(******************************************************************************)
(* OASIS: architecture for building OCaml libraries and applications          *)
(*                                                                            *)
(* Copyright (C) 2011-2013, Sylvain Le Gall                                   *)
(* Copyright (C) 2008-2011, OCamlCore SARL                                    *)
(*                                                                            *)
(* This library is free software; you can redistribute it and/or modify it    *)
(* under the terms of the GNU Lesser General Public License as published by   *)
(* the Free Software Foundation; either version 2.1 of the License, or (at    *)
(* your option) any later version, with the OCaml static compilation          *)
(* exception.                                                                 *)
(*                                                                            *)
(* This library is distributed in the hope that it will be useful, but        *)
(* WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY *)
(* or FITNESS FOR A PARTICULAR PURPOSE. See the file COPYING for more         *)
(* details.                                                                   *)
(*                                                                            *)
(* You should have received a copy of the GNU Lesser General Public License   *)
(* along with this library; if not, write to the Free Software Foundation,    *)
(* Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA              *)
(******************************************************************************)

let () =
  try
    Topdirs.dir_directory (Sys.getenv "OCAML_TOPLEVEL_PATH")
  with Not_found -> ()
;;
#use "topfind";;
#require "oasis.dynrun";;
open OASISDynRun;;

(* OASIS_STOP *)

open Printf

(* Naive substring detection *)
let rec is_substring_pos j p lenp i s lens =
  if j >= lenp then true
  else if i >= lens then false
  else if p.[j] = s.[i] then is_substring_pos (j+1) p lenp (i+1) s lens
  else false
let rec is_substring_loop p lenp i s lens =
  if is_substring_pos 0 p lenp i s lens then true
  else if i >= lens then false
  else is_substring_loop p lenp (i+1) s lens
let is_substring p s =
  is_substring_loop p (String.length p) 0 s (String.length s)



let fortran_compilers =
  let fortran = ["gfortran"; "g95"; "g77"] in
  try
    (* Guess name of the appropriate FORTRAN compiler for the OCaml compiler. *)
    let target = BaseOCamlcConfig.var_define "target" () in
    let arch, os, toolset = match OASISString.nsplit target '-' with
      | [arch; _; os; toolset] -> (* Linux, example: x86_64-pc-linux-gnu *)
         arch, os, toolset
      | [arch; mach; toolset] -> (* Windows, example: x86_64-w64-mingw32 *)
         arch, mach, toolset
      | _ -> failwith(sprintf "target %S not understood" target) in
    let ext = if Sys.win32 then ".exe" else "" in
    let default = sprintf "%s-%s-%s-gfortran%s" arch os toolset ext in
    default :: fortran
  with Failure msg ->
    OASISMessage.warning ~ctxt:!OASISContext.default "%s" msg;
    fortran

let fortran_lib() =
  try
    let fortran = BaseCheck.prog_best "fortran" fortran_compilers () in
    if is_substring "gfortran" fortran then "gfortran"
    else ""
  with _ ->
    printf "Please install one of these fortran compilers: %s.\nIf you use \
      a different compiler, send its name to the author (see _oasis file).\n%!"
      (String.concat ", " fortran_compilers);
    exit 1

let _ = BaseEnv.var_define "fortran_library" fortran_lib

let fortran_lib_location() =
  let is_macosx = BaseEnv.var_get "system" = "macosx" in
  let is_gfortran = fortran_lib () = "gfortran" in
  if is_macosx && is_gfortran then
    let path = OASISExec.run_read_one_line
                 ~ctxt:!OASISContext.default
                 "gfortran" ["--print-file-name"; "libgfortran.dylib"] in
    Filename.dirname path
  else
    ""

let _ = BaseEnv.var_define "fortran_lib_location" fortran_lib_location

let lbfgsb_ver =
  if Sys.file_exists "src/Lbfgsb.3.0/lbfgsb.f" then "3.0"
  else if Sys.file_exists "src/Lbfgsb.2.1/routines.f" then "2.1"
  else (
    printf "You must download the fortran code from\n\
            http://users.eecs.northwestern.edu/~nocedal/lbfgsb.html\n\
            and unpack it in src/";
    exit 1
  )

let _ = BaseEnv.var_define "lbfgsb_ver" (fun () -> lbfgsb_ver)
let _ = BaseEnv.var_define "lbfgsb_wa_coef_n1" (* function of [m] *)
                           (fun () -> match lbfgsb_ver with
                                   | "2.1" -> "(2 * m + 4)"
                                   | "3.0" -> "(2 * m + 5)"
                                   | _ -> assert false)
let _ = BaseEnv.var_define "lbfgsb_wa_coef_n0" (* function of [m] *)
                           (fun () -> match lbfgsb_ver with
                                   | "2.1" -> "12 * m * (m + 1)"
                                   | "3.0" -> "m * (11 * m + 8)"
                                   | _ -> assert false)


let () = setup ()
