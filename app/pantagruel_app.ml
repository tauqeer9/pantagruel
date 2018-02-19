open Core
open Pantagruel
open Bistro_utils

let logger = Console_logger.create ()

let with_workflow w ~f =
  let open Term in
  run ~logger ~keep_all:true ~np:8 ~mem:(`GB 8) (
    pure (fun (Term.Path p) -> f p) $ pureW w
  )

let run ~outdir ~assembly_folder () =
  let stage1 = Pipeline.stage1 assembly_folder in
  let stage2 = with_workflow stage1#protein_families ~f:(fun path ->
      Pipeline.stage2 ~assembly_folder stage1 path
    ) in
  (* let stage2 = object end in *)
  let repo = Pipeline.repo stage1 stage2 in
  (* Lwt_main.run (Entrez.assembly_request ~taxid) ; *)
  Repo.build ~outdir ~logger repo

let command1 =
  let open Command.Let_syntax in
  Command.basic
    ~summary:"Pantagruel"
    [%map_open
      let outdir =
        flag "--outdir" (required string) ~doc:"PATH Destination directory."
      and taxid =
        flag "--taxid"  (required int) ~doc:"INTEGER NCBI taxid" in
      fun () ->
        (* run ~outdir ~taxid *) ()
    ]

let command =
  let open Command.Let_syntax in
  Command.basic
    ~summary:"Pantagruel"
    [%map_open
      let outdir =
        flag "--outdir" (required string) ~doc:"PATH Destination directory."
      and assembly_folder =
        flag "--input"  (required string) ~doc:"PATH Assembly folder" in
      fun () ->
        run ~outdir ~assembly_folder ()
    ]

let () = Command.run ~version:"dev" command
