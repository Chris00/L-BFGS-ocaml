(* File: lbfgs.ml

   Copyright (C) 2011

     Christophe Troestler <Christophe.Troestler@umons.ac.be>
     WWW: http://math.umons.ac.be/an/software/

   This library is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License version 3 or
   later as published by the Free Software Foundation, with the special
   exception on linking described in the file LICENSE.

   This library is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
   LICENSE for more details. *)


open Bigarray
open Printf

type 'l vec = (float, float64_elt, 'l) Array1.t
type wvec = fortran_layout vec (* working vectors *)
(* FORTRAN 77 "integer" is mandated to be half the size of DOUBLE PRECISION  *)
type 'l int_vec = (int32, int32_elt, 'l) Array1.t
type wint_vec = fortran_layout int_vec (* working int vectors *)

external setulb :
  (* n = dim(x) *)
  m:int ->
  (* BEWARE: C-style offsets *)
  c_ofsx:int -> x:'l vec ->
  c_ofsl:int -> l:'l vec ->
  c_ofsu:int -> u:'l vec -> nbd:'l int_vec ->
  f:float -> g:'l vec -> factr:float -> pgtol:float ->
  wa:wvec ->      (* dim: (2m + 4)n + 12m^2 + 12m *)
  iwa:wint_vec -> (* dim: 3n *)
  task:string ->  (* length: 60 *)
  iprint:int ->
  csave:string -> (* length: 60 *)
  lsave:wint_vec -> (* logical working array of dimension 4 *)
  isave:wint_vec -> (* dim: 44 *)
  dsave:wvec ->   (* dim: 29 *)
  float
    = "ocaml_lbfgs_setulb_bc" "ocaml_lbfgs_setulb"
(* Return the value of the function 'f'. *)


type work = {
  n: int;   (* dimension of the problem used to create this work *)
  wa: wvec;
  iwa: wint_vec;
  task: string;
  csave: string;
  lsave: wint_vec;
  isave: wint_vec;
  dsave: wvec;
}

let wvec ty n = Array1.create ty fortran_layout n

let unsafe_work n m =
  { n = n;
    wa = wvec float64 ((2 * m + 4) * n + 12 * m * (m + 1));
    iwa = wvec int32 (3 * n);
    (* FORTRAN requires the strings to be initialized with spaces: *)
    task = String.make 60 ' ';
    csave = String.make 60 ' ';
    lsave = wvec int32 4;
    isave = wvec int32 44;
    dsave = wvec float64 29;
  }

let work ?(corrections=10) n =
  if corrections <= 0 then
    failwith "Lbfgs.work: corrections must be > 0";
  if n <= 0 then
    failwith "Lbfgs.work: n must be > 0";
  unsafe_work n corrections

let ceil_div n d = (n + d - 1) / d
let max i j = if (i: int) > j then i else j (* specialized version *)

(* Check that the work is large enough for the current problem. *)
let check_work n m work =
  if Array1.dim work.wa < (2 * m + 4) * n + 12 * m * (m + 1)
    || Array1.dim work.iwa < 3 * n then
    let n_min =
      max 1 (max (ceil_div (Array1.dim work.wa - 12 * m * (m + 1)) (2 * m + 4))
                 (ceil_div (Array1.dim work.iwa) 3)) in
    failwith(sprintf
               "Lbfgs.min: dim of work too small: got n = %i, valid n >= %i"
               n n_min)

let set_start s =
  (* No final '\000' for FORTRAN *)
  s.[0] <- 'S'; s.[1] <- 'T'; s.[2] <- 'A'; s.[3] <- 'R'; s.[4] <- 'T'

exception Abnormal of float * string;;


let rec strip_final_spaces s i =
  if i <= 0 then ""
  else if s.[i] = ' ' || s.[i] = '\t' || s.[i] = '\n' then
    strip_final_spaces s (i - 1)
  else String.sub s 0 i

let extract_c_string s =
  try strip_final_spaces s (String.index s '\000')
  with Not_found -> strip_final_spaces s (String.length s - 1)

type print =
| No
| Last
| Every of int
| Details
| All
| Full

let int_of_print = function
| No -> -1
| Last -> 0
| Every i ->
  if i <= 0 then -1
  else if i >= 98 then 98
  else i
| Details -> 99
| All -> 100
| Full -> 101

type state = work
(* Distinguish it from the first to avoid questionning a workspace not
   being used.  This information is only available when task=NEW_X. *)

let is_constrained w = w.lsave.{2} <> 0l
let nintervals w = Int32.to_int w.isave.{22}
let nskipped_updates w = Int32.to_int w.isave.{26}
let iter w = Int32.to_int w.isave.{30}
let nupdates w = Int32.to_int w.isave.{31}
let nintervals_current w = Int32.to_int w.isave.{33}
let neval w = Int32.to_int w.isave.{34}
let neval_current w = Int32.to_int w.isave.{36}

let previous_f w = w.dsave.{2}
let norm_dir w = w.dsave.{4}
let eps w = w.dsave.{5}
let time_cauchy w = w.dsave.{7}
let time_subspace_min w = w.dsave.{8}
let time_line_search w = w.dsave.{9}
let slope w = w.dsave.{11}
let normi_grad w = w.dsave.{13}
let slope_init w = w.dsave.{15}

module F =
struct
  type vec = (float, float64_elt, fortran_layout) Array1.t
  type layout = fortran_layout
  let layout = fortran_layout
  ;;
  DEFINE MOD = "Lbfgs.F";;
  DEFINE FIRST = 1;;
  DEFINE LAST(n) = n;;
  INCLUDE "src/lbfgs_FC.ml";; (* ocamlbuild compiles from ".." *)
end

module C =
struct
  type vec = (float, float64_elt, c_layout) Array1.t
  type layout = c_layout
  let layout = c_layout

  DEFINE MOD = "Lbfgs.C";;
  DEFINE FIRST = 0;;
  DEFINE LAST(n) = n - 1;;
  INCLUDE "src/lbfgs_FC.ml";;
end

(* Local Variables: *)
(* compile-command: "make -k -C .." *)
(* End: *)
