(* File: lbfgs.mli

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
   LICENSE.txt for more details. *)

(** Binding to
    {{http://users.eecs.northwestern.edu/~nocedal/lbfgsb.html}L-BFGS-B}.
    These are respectively limited-memory quasi-Newton code for
    unconstrained optimization and for bound-constrained optimization.

    The authors of the original FORTRAN code expect that if you use
    their software in a publication, you quote one of these references:

    - R. H. Byrd, P. Lu and J. Nocedal. A Limited Memory Algorithm for
    Bound Constrained Optimization, (1995), SIAM Journal on
    Scientific and Statistical Computing , 16, 5, pp. 1190-1208.
    - C. Zhu, R. H. Byrd and J. Nocedal. L-BFGS-B: Algorithm 778:
    L-BFGS-B, FORTRAN routines for large scale bound constrained
    optimization (1997), ACM Transactions on Mathematical Software,
    Vol 23, Num. 4, pp. 550-560.
*)

type 'l vec = (float, Bigarray.float64_elt, 'l) Bigarray.Array1.t

type work

exception Abnormal of float * string
(** [Abnormal(f,msg)] is raised if the routine terminated abnormally
    without being able to satisfy the termination conditions.  In such
    an event, the variable [x] (see {!min}) will contain the current
    best approximation found and [f] is the value of the target
    function at [x].  [msg] is a message containing additional
    information. *)

val min : ?iprint:int -> ?work:work ->
  ?corrections:int -> ?factr:float -> ?pgtol:float ->
  ?l:'l vec -> ?u:'l vec -> ('l vec -> 'l vec -> float) -> 'l vec -> float
(** [min f_df x] compute the minimum of the function [f] given by
    [f_df].  [x] is an intial estimate of the solution vector.  On
    termination, [x] will contain the best approximation found.  [f_df
    x df] is a function that computes f(x) and its gradiant f'(x),
    returns f(x) and stores f'(x) in [df].  Can raise {!Abnormal}.

    @param l lower bound for each component of the vector [x].  Set
    [l.(i)] to [neg_infinity] to indicate that no lower bound is desired.
    Default: no lower bounds.

    @param u upper bound for each component of the vector [x].  Set
    [u.(i)] to [infinity] to indicate that no upper bound is desired.
    Default: no upper bounds.

    @param factr tolerance in the termination test for the algorithm.
    The iteration will stop when
    [(f^k - f^{k+1})/max{|f^k|,|f^{k+1}|,1} <= factr*epsilon_float].
    Set e.g. [factr] to [1e12] for low accuracy, [1e7] for moderate
    accuracy and [1e1] for extremely high accuracy.  Setting [factr] to
    [0.] suppresses this termination test.  Default: [1e7].

    @param pgtol The iteration will stop when
    [max{|proj g_i| : i = 1,..., n} <= pgtol]
    where [proj g_i] is the ith component of the projected gradient.
    Setting [pgtol] to [0.] suppresses this termination test.
    Default: [1e-5].

    @param corrections maximum number of variable metric corrections
    used to define the limited memory matrix.  Values < 3 are not
    recommended, and large values of m can result in excessive
    computing time.  The range 3 <= corrections <= 20 is recommended.
    Default: [10].

    @param iprint *)
