(* OASIS_START *)
(* OASIS_STOP *)
# 464 "myocamlbuild.ml"

open Ocamlbuild_plugin;;

let env = BaseEnvLight.load() (* setup.data *)

let fortran =
  try BaseEnvLight.var_get "fortran" env with _ -> failwith "XXX"
let fortran_lib = BaseEnvLight.var_get "fortran_library" env
let lbfgsb_ver = BaseEnvLight.var_get "lbfgsb_ver" env
;;
dispatch
  (MyOCamlbuildBase.dispatch_combine [
    dispatch_default;
    begin function
    | After_rules ->
      (* Select the right FORTRAN files depending on the version. *)
      let lbfgsb =
        if lbfgsb_ver = "2.1" then [ "src" / "Lbfgsb.2.1" / "routines.o" ]
        else if lbfgsb_ver = "3.0" then
          [ "src" / "Lbfgsb.3.0" / "timer.o";
            "src" / "Lbfgsb.3.0" / "blas.o";
            "src" / "Lbfgsb.3.0" / "linpack.o";
            "src" / "Lbfgsb.3.0" / "lbfgsb.o" ]
        else assert false in
      dep ["ocaml"; "compile"] ["src"/"lbfgs_FC.ml"];
      dep ["c"; "compile"] ("src" / "f2c.h" :: lbfgsb);

      (* Add the correct Lbfgsb files for the detected version. *)
      flag ["ocamlmklib"; "c"] (S(List.map (fun p -> P p) lbfgsb));

      rule "Fortran to object" ~prod:"%.o" ~dep:"%.f"
        begin fun env _build ->
          let f = env "%.f" and o = env "%.o" in
          let tags = tags_of_pathname f ++ "compile"++"fortran" in

          let cmd = Cmd(S[A fortran; A"-c"; A"-o"; P o; A"-fPIC";
                          A"-O3"; T tags; P f ]) in
          Seq[cmd]
        end;

      if fortran_lib <> "" then (
        let flib = (S[A"-cclib"; A("-l" ^ fortran_lib)]) in
        flag ["ocamlmklib"]  flib;
        flag ["extension:cma"]  flib;
        flag ["extension:cmxa"] flib;
      );

      flag ["program"; "byte"] (A"-custom");
      flag ["compile"; "native"] (S[A"-inline"; A"10"]);
    | _ -> ()
    end;
  ]);;
