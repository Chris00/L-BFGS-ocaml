/* File: lbfgs_stubs.c

   Copyright (C) 2011

     Christophe Troestler <Christophe.Troestler@umons.ac.be>
     WWW: http://math.umons.ac.be/an/software/

   This library is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License version 3 or
   later as published by the Free Software Foundation.  See the file
   LICENCE for more details.

   This library is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
   LICENSE for more details. */

#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/callback.h>
#include <caml/bigarray.h>
#include <caml/signals.h>

#include "f2c.h"

#define FUN(name) ocaml_lbfgs_ ## name

/* Fetch vector parameters from bigarray */
#define VEC_PARAMS(V) \
  struct caml_ba_array *big_##V = Caml_ba_array_val(v##V); \
  integer dim_##V = *big_##V->dim; \
  double *V##_data = ((double *) big_##V->data) /*+ (Long_val(vOFS##V) - 1)*/

#define VEC_DATA(V) \
  ((double *) Caml_ba_array_val(v##V)->data)

#define INT_VEC_DATA(V) \
  ((int *) Caml_ba_array_val(v##V)->data)


/*
 * Declaring Fortran functions
 **********************************************************************/

extern void setulb_(integer *n,        /* dimension of the problem */
                    integer *m,        /* metric corrections */
                    doublereal *x,     /* approximation to the solution */
                    doublereal *l,
                    doublereal *u,
                    integer *nbd,
                    doublereal *f,
                    doublereal *g,
                    doublereal *factr,
                    doublereal *pgtol,
                    doublereal *wa,
                    integer *iwa,
                    char *task,
                    integer *iprint,
                    char *csave,
                    logical *lsave,
                    integer *isave,
                    doublereal *dsave);

CAMLexport
value ocaml_lbfgs_setulb(value vm, value vx, value vl, value vu, value vnbd,
                         value vf, value vg, value vfactr, value vpgtol,
                         value vwa, value viwa, value vtask, value viprint,
                         value vcsave, value vlsave, value visave,
                         value vdsave)
{
  /* noalloc */
  integer m = Int_val(vm); /* FIXME: is there any problem with
                              bigendian machines with 64 bits?  Only
                              the first 32 will be used by FORTRAN */
  VEC_PARAMS(x);
  doublereal f = Double_val(vf);
  doublereal factr = Double_val(vfactr);
  doublereal pgtol = Double_val(vpgtol);
  integer iprint = Int_val(viprint);

  setulb_(&dim_x, &m, x_data, VEC_DATA(l), VEC_DATA(u), INT_VEC_DATA(nbd),
          &f, VEC_DATA(g), &factr, &pgtol, VEC_DATA(wa), INT_VEC_DATA(iwa),
          String_val(vtask), /* shared content with OCaml */
          &iprint, String_val(vcsave),
          INT_VEC_DATA(lsave), INT_VEC_DATA(isave), VEC_DATA(dsave));
  /* The following may allocate but we do not need Caml arguments anymore: */
  return(copy_double(f));
}

CAMLexport
value ocaml_lbfgs_setulb_bc(value * argv, int argn)
{
  return ocaml_lbfgs_setulb(
    argv[0], argv[1], argv[2], argv[3], argv[4], argv[5], argv[6],
    argv[7], argv[8], argv[9], argv[10], argv[11], argv[12], argv[13],
    argv[14], argv[15], argv[16]);
}

