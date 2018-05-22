
build:
	jbuilder build @install @runtest #--dev

install uninstall:
	jbuilder $@

doc:
	sed -e 's/%%VERSION%%/$(PKGVERSION)/' src/lbfgs.mli \
	  > _build/default/src/lbfgs.mli
	jbuilder build @doc
	echo '.def { background: #f9f9de; }' >> _build/default/_doc/odoc.css

dist tar: setup.ml
	mkdir -p $(DIR)
	for f in $(DISTFILES); do \
	  cp -r --parents $$f $(DIR); \
	done
#	Generate a setup.ml independent of oasis
	cd $(DIR) && oasis setup
	tar -zcvf $(TARBALL) $(DIR)
	$(RM) -r $(DIR)

lint:
	opam lint lbfgs.opam

get-lbfgs:
	cd src && \
	test -d Lbfgsb.3.0 || (curl http://users.iems.northwestern.edu/~nocedal/Software/Lbfgsb.3.0.tar.gz | tar zx)
	jbuilder exec config/rename_c_prims.exe

clean:
	jbuilder clean


.PHONY: build tests install uninstall doc dist tar lint get-lbfgs clean
