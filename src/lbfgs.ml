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
  x:'l vec -> l:'l vec -> u:'l vec -> nbd:'l int_vec ->
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

(* Macro so the final code is monomorphic for speed *)
DEFINE NBD_OF_LU(n, first, last, lopt, uopt, empty_vec) =
  match lopt, uopt with
  | None, None -> Array1.fill nbd 0l; (empty_vec, empty_vec)
  | Some l, None ->
    if Array1.dim l < n then
      invalid_arg(sprintf "Lbfgs.min: dim l = %i < dim x = %i"
                    (Array1.dim l) n);
    for i = first to last do
      nbd.{i} <- if l.{i} = neg_infinity then 0l else 1l
    done;
    (l, empty_vec)
  | None, Some u ->
    if Array1.dim u < n then
      invalid_arg(sprintf "Lbfgs.min: dim u = %i < dim x = %i"
                    (Array1.dim u) n);
    for i = first to last do
      nbd.{i} <- if u.{i} = infinity then 0l else 3l
    done;
    (empty_vec, u)
  | Some l, Some u ->
    if Array1.dim l < n then
      invalid_arg(sprintf "Lbfgs.min: dim l = %i < dim x = %i"
                    (Array1.dim l) n);
    if Array1.dim u < n then
      invalid_arg(sprintf "Lbfgs.min: dim u = %i < dim x = %i"
                    (Array1.dim u) n);
    for i = first to last do
      nbd.{i} <-
        if l.{i} = neg_infinity then (if u.{i} = infinity then 0l else 3l)
        else (if u.{i} = infinity then 1l else 2l)
    done;
    (l, u)
;;

let empty_vec_c = Array1.create float64 c_layout 0
let empty_vec_fortran = Array1.create float64 fortran_layout 0

let nbd_of_lu (layout: 'l layout) n (l: 'l vec option) (u: 'l vec option) =
  let nbd = Array1.create int32 layout n in
  let l, u =
    if (Obj.magic layout: 'a layout) = fortran_layout then
      (Obj.magic
         (NBD_OF_LU(n, 1, n, (Obj.magic l: fortran_layout vec option),
                   (Obj.magic u: fortran_layout vec option), empty_vec_fortran)
            : fortran_layout vec * fortran_layout vec) : 'l vec * 'l vec)
    else
      (Obj.magic
         (NBD_OF_LU(n, 0, n - 1, (Obj.magic l: c_layout vec option),
                (Obj.magic u: c_layout vec option), empty_vec_c)
            : c_layout vec * c_layout vec) : 'l vec * 'l vec) in
  l, u, nbd

let rec strip_final_spaces s i =
  if i <= 0 then ""
  else if s.[i] = ' ' || s.[i] = '\t' || s.[i] = '\n' then
    strip_final_spaces s (i - 1)
  else String.sub s 0 i

let extract_c_string s =
  try strip_final_spaces s (String.index s '\000')
  with Not_found -> strip_final_spaces s (String.length s - 1)


let min ?(iprint=0) ?work ?(nsteps=max_int)
    ?(corrections=10) ?(factr=1e7) ?(pgtol=1e-5)
    ?l ?u f_df (x: 'l vec) =
  let n = Array1.dim x in
  let m =
    if corrections > 0 then corrections
    else failwith "Lbfgs.min: corrections must be > 0" in
  let layout : 'l layout = Array1.layout x in
  let l, u, nbd = nbd_of_lu layout n l u in
  let w = match work with
    | None -> unsafe_work n m
    | Some w -> check_work n m w; w in
  set_start w.task; (* task = "START" *)
  let continue = ref true in
  let f = ref nan
  and g = Array1.create float64 layout n in
  while !continue do
    f := setulb ~m ~x ~l ~u ~nbd ~f:!f ~g ~factr ~pgtol
      ~wa:w.wa ~iwa:w.iwa ~task:w.task ~iprint ~csave:w.csave
      ~lsave:w.lsave ~isave:w.isave ~dsave:w.dsave;
    match w.task.[0] with
    | 'F' (* FG *) -> f := f_df x g
    | 'C' (* CONV *) ->
      (* the termination test in L-BFGS-B has been satisfied. *)
      continue := false
    | 'A' (* ABNO *) -> raise(Abnormal(!f, extract_c_string w.task))
    | 'E' (* ERROR *) -> invalid_arg (extract_c_string w.task)
    | 'N' (* NEW_X *) ->
      if Int32.to_int w.isave.{30} > nsteps then
        continue := false
    | _ -> assert false
  done;
  1. *. !f (* unbox f *)


(* Local Variables: *)
(* compile-command: "make -C .." *)
(* End: *)
