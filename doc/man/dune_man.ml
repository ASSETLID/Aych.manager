let gen_topic target_basename dline t =
  Printf.printf "\n\
                 (rule\n\
                \  (with-stdout-to %s-%s.1 (run %s %s --help=groff)))\n\
                "
    target_basename t dline t

let () =
  let cmd,args = match Array.to_list Sys.argv with
    | _::cmd::args -> cmd, args
    | [] | [_]  -> invalid_arg "Missing command argument"
  in
  let cline = String.concat " " (cmd :: args) ^ " help topics" in
  let topics =
    let ic = Unix.open_process_in cline in
    set_binary_mode_in ic false;
    let rec aux () =
      match input_line ic with
      | "" -> aux ()
      | s -> s :: aux ()
      | exception _ -> close_in ic; []
    in
    aux ()
  in
  let target_basename = String.concat "-" ("opam" :: args) in
  let dline = String.concat " " ("%{bin:opam}" :: args) in
  print_string ";; Generated by dune_man\n";
  List.iter (gen_topic target_basename dline) topics;
  Printf.printf "\n\
                 (install\n\
                \  (section man)\n\
                \  (package opam)\n\
                \  (files%s))\n"
    (String.concat " "
       (List.map (Printf.sprintf "\n    %s-%s.1" target_basename) topics))
