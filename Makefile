WEB = lbfgs.forge.ocamlcore.org:/home/groups/lbfgs/htdocs/

DIR = $(shell oasis query name)-$(shell oasis query version)
TARBALL = $(DIR).tar.gz

DISTFILES = INSTALL.txt Makefile myocamlbuild.ml _oasis setup.ml _tags \
  rename_c_prims.ml _opam \
  $(wildcard $(addprefix src/,*.ab *.ml *.mli *.clib *.mllib *.c *.h)) \
  $(addprefix src/Lbfgsb.3.0/, timer.f blas.f linpack.f lbfgsb.f) \
  $(wildcard examples/*.ml)

.PHONY: configure all byte native doc upload-doc install uninstall reinstall
all byte native: setup.data
	ocaml setup.ml -build

configure: setup.data
setup.data: setup.ml
	ocaml setup.ml -configure --enable-lacaml

setup.ml: _oasis
	oasis setup -setup-update dynamic

doc install uninstall reinstall: all
	ocaml setup.ml -$@

upload-doc: doc
	scp -C -p -r _build/API.docdir $(WEB)

.PHONY: dist tar
dist tar: setup.ml
	mkdir -p $(DIR)
	for f in $(DISTFILES); do \
	  cp -r --parents $$f $(DIR); \
	done
#	Generate a setup.ml independent of oasis
	cd $(DIR) && oasis setup
	tar -zcvf $(TARBALL) $(DIR)
	$(RM) -r $(DIR)

.PHONY: clean distclean
clean: setup.ml
	ocaml setup.ml -clean
	$(RM) $(TARBALL) iterate.dat

distclean: setup.ml
	ocaml setup.ml -distclean
	$(RM) $(wildcard *.ba[0-9] *.bak *~ *.odocl)
