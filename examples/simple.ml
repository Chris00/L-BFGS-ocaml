(* Elementary test function *)

open Printf
open Bigarray

let () =
  let f x = x *. x -. 2.
  and f' x = 2. *. x in
  let u0 = Array1.create float64 fortran_layout 1 in
  u0.{1} <- 1.;
  let m = Lbfgs.min (fun u df -> df.{1} <- f' u.{1}; f u.{1}) u0 in
  printf "min = %g\n" m
