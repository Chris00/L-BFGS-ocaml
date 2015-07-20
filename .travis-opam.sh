
OPAM_PACKAGES='ocamlfind'

export OPAMYES=1

# $HOME/.opam is cached, hence always present.
if [ -f "$HOME/.opam/config" ]; then
    opam update
    opam upgrade --yes
else
    opam init
fi

if [ -n "${OPAM_SWITCH}" ]; then
    opam switch ${OPAM_SWITCH}
fi
eval `opam config env`
opam install -q -y ${OPAM_PACKAGES}

opam pin add lbfgs . --yes
opam remove lbfgs
