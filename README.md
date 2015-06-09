[![Build Status](https://travis-ci.org/Chris00/L-BFGS-ocaml.svg?branch=master)](https://travis-ci.org/Chris00/L-BFGS-ocaml)

OCaml bindings for L-BFGS
=========================

[L-BFGS](https://en.wikipedia.org/wiki/Limited-memory_BFGS) is an
optimization algorithm in the family of quasi-Newton methods that
approximates the
[Broyden–Fletcher–Goldfarb–Shanno](https://en.wikipedia.org/wiki/Broyden%E2%80%93Fletcher%E2%80%93Goldfarb%E2%80%93Shanno_algorithm)
(BFGS) algorithm using a limited amount of computer memory.

This library is a binding to Nocedal's implementation of
[L-BFGS-B](http://users.eecs.northwestern.edu/~nocedal/lbfgsb.html)
which adds the possibility of setting bounds on the variables.

Install
-------

The easiest way to install the library is to use
[opam](https://opam.ocaml.org/):

    opam install lbfgs

If you clone this repository, download
[Lbfgsb.3.0](http://users.iems.northwestern.edu/~nocedal/Software/Lbfgsb.3.0.tar.gz)
and extract it in `src/` (it should create `src/Lbfgsb.3.0/`).
Then issue `make` and `make install`.


Documentation
-------------

If you cloned this repository, issue

    ocaml setup.ml -doc

You can also consult it
[online](http://lbfgs.forge.ocamlcore.org/API.docdir/Lbfgs.html).
