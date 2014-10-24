(**************************************************************************)
(*                                                                        *)
(*    Copyright 2012-2013 OCamlPro                                        *)
(*    Copyright 2012 INRIA                                                *)
(*                                                                        *)
(*  All rights reserved.This file is distributed under the terms of the   *)
(*  GNU Lesser General Public License version 3.0 with linking            *)
(*  exception.                                                            *)
(*                                                                        *)
(*  OPAM is distributed in the hope that it will be useful, but WITHOUT   *)
(*  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY    *)
(*  or FITNESS FOR A PARTICULAR PURPOSE.See the GNU General Public        *)
(*  License for more details.                                             *)
(*                                                                        *)
(**************************************************************************)

(** Shell commands *)
type command = {
  cmd: string;
  args: string list;
  cmd_text: string option;
  cmd_dir: string option;
  cmd_env: string array option;
  cmd_stdin: bool option;
  cmd_verbose: bool option;
  cmd_name: string option;
  cmd_metadata: (string * string) list option;
}

let command ?env ?verbose ?name ?metadata ?dir ?allow_stdin ?text cmd args =
  { cmd; args;
    cmd_env=env; cmd_verbose=verbose; cmd_name=name; cmd_metadata=metadata;
    cmd_dir=dir; cmd_stdin=allow_stdin; cmd_text=text; }

let string_of_command c = String.concat " " (c.cmd::c.args)
let text_of_command c = c.cmd_text

(** Running processes *)

type t = {
  p_name   : string;
  p_args   : string list;
  p_pid    : int;
  p_cwd    : string;
  p_time   : float;
  p_stdout : string option;
  p_stderr : string option;
  p_env    : string option;
  p_info   : string option;
  p_metadata: (string * string) list;
}

let open_flags =  [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_APPEND]

let output_lines oc lines =
  List.iter (fun line ->
    output_string oc line;
    output_string oc "\n";
    flush oc;
  ) lines;
  output_string oc "\n";
  flush oc

let option_map fn = function
  | None   -> None
  | Some o -> Some (fn o)

let option_default d = function
  | None   -> d
  | Some v -> v

let make_info ?code ~cmd ~args ~cwd ~env_file ~stdout_file ~stderr_file ~metadata () =
  let b = ref [] in
  let print name str = b := (name, str) :: !b in
  let print_opt name = function
    | None   -> ()
    | Some s -> print name s in

  print     "opam-version" (OpamVersion.to_string OpamVersion.full);
  print     "os"           (OpamGlobals.os_string ());
  print     "command"      (String.concat " " (cmd :: args));
  print     "path"         cwd;
  List.iter (fun (k,v) -> print k v) metadata;
  print_opt "exit-code"    (option_map string_of_int code);
  print_opt "env-file"     env_file;
  print_opt "stdout-file"  stdout_file;
  print_opt "stderr-file"  stderr_file;

  List.rev !b

let string_of_info ?(color=`yellow) info =
  let b = Buffer.create 1024 in
  List.iter
    (fun (k,v) -> Printf.bprintf b "%s %-20s %s\n"
        (OpamGlobals.colorise color "#")
        (OpamGlobals.colorise color k) v) info;
  Buffer.contents b

(** [create cmd args] create a new process to execute the command
    [cmd] with arguments [args]. If [stdout_file] or [stderr_file] are
    set, the channels are redirected to the corresponding files.  The
    outputs are discarded is [verbose] is set to false. The current
    environment can also be overriden if [env] is set. The environment
    which is used to run the process is recorded into [env_file] (if
    set). *)
let create ?info_file ?env_file ?(allow_stdin=true) ?stdout_file ?stderr_file ?env ?(metadata=[]) ?dir
    ~verbose cmd args =
  Printf.eprintf "Command%s: \"%s\"\n%!"
    (match dir with None -> "" | Some d -> "["^d^"]")
    (String.concat "\" \"" (cmd::args));
  let nothing () = () in
  let tee f =
    let fd = Unix.openfile f open_flags 0o644 in
    let close_fd () = Unix.close fd in
    if verbose then (
      flush stderr;
      let chan = Unix.open_process_out ("tee -a " ^ Filename.quote f) in
      let close () =
        match Unix.close_process_out chan with
        | _ -> close_fd () in
      Unix.descr_of_out_channel chan, close
    ) else
      fd, close_fd in
  let oldcwd = Sys.getcwd () in
  let cwd = OpamMisc.Option.default oldcwd dir in
  OpamMisc.Option.iter Unix.chdir dir;
  let stdin_fd =
    if allow_stdin then Unix.stdin else
    let fd,outfd = Unix.pipe () in
    Unix.close outfd; fd
  in
  let stdout_fd, close_stdout = match stdout_file with
    | None   -> Unix.stdout, nothing
    | Some f -> tee f in
  let stderr_fd, close_stderr = match stderr_file with
    | None   -> Unix.stderr, nothing
    | Some f -> tee f in
  let env = match env with
    | None   -> Unix.environment ()
    | Some e -> e in
  let time = Unix.gettimeofday () in

  let () =
    (* write the env file before running the command*)
    match env_file with
    | None   -> ()
    | Some f ->
      let chan = open_out f in
      let env = Array.to_list env in
      (* Remove dubious variables *)
      let env = List.filter (fun line -> not (OpamMisc.contains line '$')) env in
      output_lines chan env;
      close_out chan in

  let () =
    (* write the info file *)
    match info_file with
    | None   -> ()
    | Some f ->
      let chan = open_out f in
      let info =
        make_info ~cmd ~args ~cwd ~env_file ~stdout_file ~stderr_file ~metadata () in
      output_string chan (string_of_info info);
      close_out chan in

  let pid =
    Unix.create_process_env
      cmd
      (Array.of_list (cmd :: args))
      env
      stdin_fd stdout_fd stderr_fd in
  close_stdout ();
  close_stderr ();
  Unix.chdir oldcwd;
  {
    p_name   = cmd;
    p_args   = args;
    p_pid    = pid;
    p_cwd    = cwd;
    p_time   = time;
    p_stdout = stdout_file;
    p_stderr = stderr_file;
    p_env    = env_file;
    p_info   = info_file;
    p_metadata = metadata;
  }

type result = {
  r_code     : int;
  r_duration : float;
  r_info     : (string * string) list;
  r_stdout   : string list;
  r_stderr   : string list;
  r_cleanup  : string list;
}

(* XXX: the function might block for ever for some channels kinds *)
let read_lines f =
  try
    let ic = open_in f in
    let lines = ref [] in
    begin
      try
        while true do
          let line = input_line ic in
          lines := line :: !lines;
        done
      with End_of_file | Sys_error _ -> ()
    end;
    close_in ic;
    List.rev !lines
  with Sys_error _ -> []

let run_background command =
  let { cmd; args;
        cmd_env=env; cmd_verbose=verbose; cmd_name=name;
        cmd_metadata=metadata; cmd_dir=dir; cmd_stdin=allow_stdin } =
    command
  in
  let verbose = OpamMisc.Option.default !OpamGlobals.verbose verbose in
  let allow_stdin = OpamMisc.Option.default false allow_stdin in
  let env = match env with Some e -> e | None -> Unix.environment () in
  let file f = match name with
    | None   -> None
    | Some n -> Some (f n) in
  let stdout_file = file (Printf.sprintf "%s.out") in
  let stderr_file = file (Printf.sprintf "%s.err") in
  let env_file    = file (Printf.sprintf "%s.env") in
  let info_file   = file (Printf.sprintf "%s.info") in
  create ~env ?info_file ?env_file ?stdout_file ?stderr_file ~verbose ?metadata
    ~allow_stdin ?dir cmd args

let exit_status p code =
  let duration = Unix.gettimeofday () -. p.p_time in
  let stdout = option_default [] (option_map read_lines p.p_stdout) in
  let stderr = option_default [] (option_map read_lines p.p_stderr) in
  let cleanup =
    OpamMisc.filter_map (fun x -> x) [ p.p_info; p.p_env; p.p_stderr; p.p_stdout ]
  in
  let info =
    make_info ~code ~cmd:p.p_name ~args:p.p_args ~cwd:p.p_cwd ~metadata:p.p_metadata
      ~env_file:p.p_env ~stdout_file:p.p_stdout ~stderr_file:p.p_stderr () in
  {
    r_code     = code;
    r_duration = duration;
    r_info     = info;
    r_stdout   = stdout;
    r_stderr   = stderr;
    r_cleanup  = cleanup;
  }

let wait p =
  let rec iter () =
    let _, status = Unix.waitpid [] p.p_pid in
    match status with
    | Unix.WEXITED code -> exit_status p code
    | _ -> iter () in
  iter ()

let rec dontwait p =
  match Unix.waitpid [Unix.WNOHANG] p.p_pid with
  | 0, _ -> None
  | _, Unix.WEXITED code -> Some (exit_status p code)
  | _, _ -> dontwait p

let dead_childs = Hashtbl.create 13
let wait_one processes =
  if processes = [] then raise (Invalid_argument "wait_one");
  try
    let p =
      List.find (fun p -> Hashtbl.mem dead_childs p.p_pid) processes
    in
    let code = Hashtbl.find dead_childs p.p_pid in
    Hashtbl.remove dead_childs p.p_pid;
    p, exit_status p code
  with Not_found ->
    (* No multiple wait on Windows. We'll need to either use some C code, or
       threads. In the meantime we could [Unix.waitpid (List.hd processes)] *)
    let rec aux () =
      match Unix.wait () with
      | pid, Unix.WEXITED code ->
        (try
           let p = List.find (fun p -> p.p_pid = pid) processes in
           p, exit_status p code
         with Not_found ->
           Hashtbl.add dead_childs pid code;
           aux ())
      | _ -> aux ()
    in
    aux ()

let run command =
  let command =
    { command with
      cmd_stdin = OpamMisc.Option.Op.(command.cmd_stdin ++ Some true) }
  in
  let p = run_background command in
  wait p

let is_success r = r.r_code = 0

let is_failure r = r.r_code <> 0

let safe_unlink f =
  try Unix.unlink f with Unix.Unix_error _ -> ()

let cleanup ?(force=false) r =
  if force || not !OpamGlobals.debug || is_success r then
    List.iter safe_unlink r.r_cleanup

let truncate_str = "[...]"

(* Truncate long lines *)
let truncate_line str =
  if String.length str <= OpamGlobals.log_line_limit then
    str
  else
    String.sub str 0 (OpamGlobals.log_line_limit - String.length truncate_str)
    ^ truncate_str

(* Take the last [n] elements of [l] *)
let rec truncate = function
  | [] -> []
  | l  ->
    if List.length l < OpamGlobals.log_limit then
      List.map truncate_line l
    else if List.length l = OpamGlobals.log_limit then
      truncate_str :: l
    else match l with
      | []     -> []
      | _ :: t -> truncate t

let string_of_result ?(color=`yellow) r =
  let b = Buffer.create 2048 in
  let print = Buffer.add_string b in
  let println str =
    print str;
    Buffer.add_char b '\n' in

  print (string_of_info ~color r.r_info);

  if r.r_stdout <> [] then
    print (OpamGlobals.colorise color "### stdout ###\n");
  List.iter (fun s ->
      print (OpamGlobals.colorise color "# ");
      println s)
    (truncate r.r_stdout);

  if r.r_stderr <> [] then
    print (OpamGlobals.colorise color "### stderr ###\n");
  List.iter (fun s ->
      print (OpamGlobals.colorise color "# ");
      println s)
    (truncate r.r_stderr);

  Buffer.contents b


(* Higher-level interface to allow parallelism *)

module Job = struct
  module Op = struct
    type 'a job = (* Open the variant type *)
      | Done of 'a
      | Run of command * (result -> 'a job)

    (* Parallelise shell commands *)
    let (@@>) command f = Run (command, f)

    (* Sequentialise jobs *)
    let rec (@@+) job1 fjob2 = match job1 with
      | Done x -> fjob2 x
      | Run (cmd,cont) -> Run (cmd, fun r -> cont r @@+ fjob2)
  end

  open Op

  let run =
    let rec aux = function
      | Done x -> x
      | Run (cmd,cont) ->
        Printf.eprintf "Sequential run: %s\n%!" (string_of_command cmd);
        aux (cont (run cmd))
    in
    aux

  let rec dry_run = function
    | Done x -> x
    | Run (_command,cont) ->
      let result = { r_code = 0;
                     r_duration = 0.;
                     r_info = [];
                     r_stdout = [];
                     r_stderr = [];
                     r_cleanup = []; }
      in dry_run (cont result)

  let rec catch handler = function
    | Done x -> Done x
    | Run (cmd,cont) ->
      let cont r =
        match
          try `Cont (cont r) with e -> `Hndl (handler e)
        with
        | `Cont job -> catch handler job
        | `Hndl job -> job
      in
      Run (cmd, cont)

  let rec finally fin = function
    | Done x -> fin (); Done x
    | Run (cmd,cont) ->
      Run (cmd, fun r -> finally fin (try cont r with e -> fin (); raise e))

  let of_list ?(keep_going=false) l =
    let rec aux err = function
      | [] -> Done err
      | cmd::commands ->
        let cont = fun r ->
          if is_success r then aux err commands
          else if keep_going then
            aux OpamMisc.Option.Op.(err ++ Some (cmd,r)) commands
          else Done (Some (cmd,r))
        in
        Run (cmd,cont)
    in
    aux None l

end

type 'a job = 'a Job.Op.job
