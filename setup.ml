let () =
  try Topdirs.dir_directory (Sys.getenv "OCAML_TOPLEVEL_PATH")
  with Not_found -> ();;

(* OASIS_START *)
(* DO NOT EDIT (digest: 7f47a529f70709161149c201ccd90f0b) *)
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


let fortran_compilers = ["gfortran"; "g95"; "g77"]

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
