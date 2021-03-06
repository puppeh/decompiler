(* Opcodes & registers for optimising macro assembler.  *)

module type CODETYPES =
  sig
    type reg
    type nulop
    type unop
    type binop
    type triop
    type extop
    type mem
    type immed
    type addr
    type abi
    type entity
    
    val string_of_reg : reg -> string
    val string_of_nulop : nulop -> string
    val string_of_unop : unop -> string
    val string_of_binop : binop -> string
    val string_of_triop : triop -> string
    val string_of_extop : extop -> string
    val string_of_mem : mem -> string
    val string_of_immed : immed -> string
    val string_of_addr : addr -> string
    val string_of_abi : abi -> string
    val string_of_entity : entity -> string
    
    (* Properties of registers.  So far unused!  *)
    val reg_overlaps : reg -> reg list
    val reg_subset : reg -> reg -> bool
  end

(* We have an abstract block reference type, but we also need to impose an
   ordering on blocks for efficiency, etc. This is done with to_index and
   of_index, which should return monotonically-increasing integer indices
   per-block.
   
   This flexibility allows, e.g., blocks to be referenced by strings, if
   desired.  *)

module type BLOCKSEQ =
  sig
    type 'a t
    type blockref
    type reftable
    
    val empty : 'a t
    val is_empty : 'a t -> bool
    val cons : 'a -> 'a t -> 'a t
    val head : 'a t -> 'a
    val tail : 'a t -> 'a t
    (*val get_last : 'a t -> 'a*)
    val lookup : 'a t -> int -> 'a
    val update : 'a t -> int -> 'a -> 'a t
    val lookup_ref : 'a t -> reftable -> blockref -> 'a
    val length : 'a t -> int
    val fold_right : ('a -> 'b -> 'b) -> 'a t -> 'b -> 'b
    val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
    val iter : ('a -> unit) -> 'a t -> unit
    val map : ('a -> 'b) -> 'a t -> 'b t
    val to_index : reftable -> blockref -> int
    val of_index : reftable -> int -> blockref
    val of_list : 'a list -> 'a t
    val of_list_rev : 'a list -> 'a t
    
    val string_of_blockref : blockref -> string
  end

module type CODESEQ =
  sig
    type 'a t
    
    val empty : 'a t
    val cons : 'a -> 'a t -> 'a t
    val snoc : 'a t -> 'a -> 'a t
    val fold_right : ('a -> 'b -> 'b) -> 'a t -> 'b -> 'b
    val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
    val map : ('a -> 'b) -> 'a t -> 'b t
    val iter : ('a -> unit) -> 'a t -> unit
    val get_last : 'a t -> 'a
    val length : 'a t -> int
    val nth : 'a t -> int -> 'a
    val is_empty : 'a t -> bool
    val decon : 'a t -> ('a * 'a t) option
    val noced : 'a t -> ('a t * 'a) option
  end

module Code (CT : CODETYPES) (CS : CODESEQ) (BS : BLOCKSEQ) =
  struct
    type code =
        Reg of CT.reg
      | SSAReg of (CT.reg * int)
      | Load of CT.mem * code
      | Store of CT.mem * code * code
      | Immed of CT.immed
      | Nary of CT.extop * code list
      | Ternary of CT.triop * code * code * code
      | Binary of CT.binop * code * code
      | Unary of CT.unop * code
      | Nullary of CT.nulop
      | Set of code * code
      | Control of control
      | Phi of code array
      | Entity of CT.entity
      | Parallel of code array
      | Concat of code array
      | Call of BS.blockref * code
      | CompCall of code * code
      | Call_ext of CT.abi * CT.addr * code
      (* Just for iterating over code sequences.  Don't process "protected"
         child nodes.  *)
      | Protect of code

    (* FIXME: Seems like these need sanitizing a bit.  *)
    and control =
        TailCall of BS.blockref * code
      | Jump of BS.blockref
      | Branch of code * BS.blockref * BS.blockref
      | Return of code
      | CompTailCall of code * code
      | CompJump of code * BS.blockref list
      (* External branches to OS routines, libraries, etc.  *)
      | TailCall_ext of CT.abi * CT.addr * code
      | Jump_ext of CT.abi * CT.addr
      | CompJump_ext of CT.abi * code
      | Virtual_exit
      | Protect_ctl of control
    
    let get_last blk = CS.get_last blk
    
    let str = Printf.sprintf
    
    let rec string_of_control = function
      TailCall (tailr, targs) ->
	str "tailcall (%s, %s)" (BS.string_of_blockref tailr)
	  (string_of_code targs)
    | Jump jumpr ->
        str "jump (%s)" (BS.string_of_blockref jumpr)
    | CompJump (jumpc, targs) ->
        str "compjump (%s, {%s})" (string_of_code jumpc)
	  (String.concat ", " (List.map BS.string_of_blockref targs))
    | Branch (cond, truer, falser) ->
        str "branch (%s, %s, %s)" (string_of_code cond)
	  (BS.string_of_blockref truer) (BS.string_of_blockref falser)
    | Return code ->
        str "return (%s)" (string_of_code code)
    | CompTailCall (tailc, targs) ->
        str "tailcall_ind (%s, %s)" (string_of_code tailc)
	  (string_of_code targs)
    | TailCall_ext (abi, addr, targs) ->
        str "tailcall_ext (%s, %s, %s)" (CT.string_of_abi abi)
	  (CT.string_of_addr addr) (string_of_code targs)
    | Jump_ext (abi, addr) ->
        str "jump_ext (%s, %s)" (CT.string_of_abi abi) (CT.string_of_addr addr)
    | CompJump_ext (abi, code) ->
        str "compjump_ext (%s, %s)" (CT.string_of_abi abi) (string_of_code code)
    | Virtual_exit -> "virtual_exit"
    | Protect_ctl x -> str "protect_ctl (%s)" (string_of_control x)
    
    and string_of_code = function
      Reg r -> CT.string_of_reg r
    | SSAReg (r, n) -> str "%s_%s" (CT.string_of_reg r) (string_of_int n)
    | Load (m, c) -> str "load-%s[%s]" (CT.string_of_mem m) (string_of_code c)
    | Store (m, c, v) -> str "store-%s[%s] <- %s" (CT.string_of_mem m)
			  (string_of_code c) (string_of_code v)
    | Immed i -> CT.string_of_immed i
    | Nary (eo, cl) ->
        str "%s (%s)" (CT.string_of_extop eo)
	  (String.concat ", " (List.map string_of_code cl))
    | Ternary (triop, a, b, c) ->
        str "%s (%s, %s, %s)" (CT.string_of_triop triop) (string_of_code a)
	  (string_of_code b) (string_of_code c)
    | Binary (binop, a, b) ->
        str "%s (%s, %s)" (CT.string_of_binop binop) (string_of_code a)
	  (string_of_code b)
    | Unary (unop, a) ->
        str "%s (%s)" (CT.string_of_unop unop) (string_of_code a)
    | Nullary nul -> CT.string_of_nulop nul
    | Set (dst, src) ->
        str "%s := %s" (string_of_code dst) (string_of_code src)
    | Control ctl ->
        str "--> %s" (string_of_control ctl)
    | Phi carr ->
        str "phi (%s)" (String.concat ", " (Array.to_list
	  (Array.map string_of_code carr)))
    | Parallel arr ->
        str "par { %s }" (String.concat "; " (Array.to_list
	  (Array.map string_of_code arr)))
    | Concat arr ->
        str "concat { %s }" (String.concat "; " (Array.to_list
	  (Array.map string_of_code arr)))
    | Call (callr, cargs) ->
        str "call (%s, %s)" (BS.string_of_blockref callr) (string_of_code cargs)
    | CompCall (callc, cargs) ->
        str "call_ind (%s, %s)" (string_of_code callc) (string_of_code cargs)
    | Call_ext (abi, addr, cargs) ->
        str "call_ext (%s, %s, %s)" (CT.string_of_abi abi)
	  (CT.string_of_addr addr) (string_of_code cargs)
    | Entity e -> CT.string_of_entity e
    | Protect x -> str "*protect* (%s)" (string_of_code x)
  
    let string_of_codeseq cs =
      let buf = CS.fold_left
	(fun buf code ->
          Buffer.add_string buf (string_of_code code);
	  Buffer.add_char buf '\n';
	  buf)
	(Buffer.create 20)
	cs in
      Buffer.contents buf

    let get_control blk =
      match get_last blk with
	Control ctl -> ctl
      | x ->
	let insn = string_of_code x in
	failwith (Printf.sprintf
	  "Last instruction of block (%s) does no control flow" insn)

    (* Insert an insn at the end of a code sequence, before any control-flow
       instruction if one is present.  FIXME: This is flawed, because it will
       insert code before the function call for basic blocks which finish with
       a call (or similar) instruction.  We need to create a new block in those
       cases.  *)
    let insert_before_control cseq insn =
      match CS.noced cseq with
	None -> CS.snoc cseq insn
      | Some (upto, ((Control _) as ctl)) ->
	  let cseq' = CS.snoc upto insn in
	  CS.snoc cseq' ctl
      | Some (_, _) -> CS.snoc cseq insn

    let finishes_with_control cseq =
      match CS.noced cseq with
        None -> false
      | Some (_, Control _) -> true
      | Some (_, _) -> false

    let fold fn ?(ctl_fn = (fun ctl acc -> ctl, acc)) code acc =
      let rec scan e acc =
	let expr', acc' = fn e acc in
	match expr' with
	  Entity _ | Reg _ | SSAReg _ | Immed _ | Nullary _ ->
	    acc'
	| Nary (_, clist) ->
	    List.fold_right scan clist acc'
	| Ternary (_, a, b, c) ->
            let acc'' = scan c acc' in
	    let acc''' = scan b acc'' in
	    scan a acc'''
	| Binary (_, a, b) ->
            let acc'' = scan b acc' in
	    scan a acc''
	| Unary (_, a) | Load (_, a) ->
            scan a acc'
	| Store (_, a, b) ->
            let acc'' = scan b acc' in
	    scan a acc''
	| Set (d, s) ->
            let acc'' = scan d acc' in
	    scan s acc''
	| Control c ->
            scan_ctl c acc'
	| Phi parr ->
            Array.fold_right scan parr acc'
	| Parallel parr ->
	    Array.fold_right scan parr acc'
	| Concat carr ->
	    Array.fold_right scan carr acc'
	| Call (_, args) ->
	    scan args acc'
	| CompCall (cdst, cargs) ->
	    let acc'' = scan cdst acc' in
	    scan cargs acc''
	| Call_ext (_, _, cargs) ->
	    scan cargs acc'
	| Protect child ->
	    acc'
      and scan_ctl ctl acc =
	let ctl', acc' = ctl_fn ctl acc in
	match ctl' with
	  TailCall (_, code) | Branch (code, _, _) | CompJump (code, _)
	| TailCall_ext (_, _, code) | Return code | CompJump_ext (_, code) ->
            scan code acc'
	| CompTailCall (c1, c2) ->
            let acc'' = scan c2 acc' in
	    scan c1 acc''
	| Jump _ | Jump_ext _ | Virtual_exit | Protect_ctl _ -> acc' in
      scan code acc

    let map fn ?(ctl_fn = fun x -> x) code =
      let rec scan e =
	match fn e with
	  (Entity _ | Reg _ | SSAReg _ | Immed _ | Nullary _) as x -> x
	| Load (mem, code) ->
	    Load (mem, scan code)
	| Store (mem, code, v) ->
	    Store (mem, scan code, scan v)
	| Nary (op, clist) ->
	    Nary (op, List.map scan clist)
	| Ternary (op, a, b, c) ->
	    Ternary (op, scan a, scan b, scan c)
	| Binary (op, a, b) ->
	    Binary (op, scan a, scan b)
	| Unary (op, a) ->
	    Unary (op, scan a)
	| Set (d, s) ->
	    Set (scan d, scan s)
	| Control c ->
	    Control (scan_ctl c)
	| Phi parr ->
	    Phi (Array.map scan parr)
	| Parallel parr ->
	    Parallel (Array.map scan parr)
	| Concat carr ->
	    Concat (Array.map scan carr)
	| Call (br, args) ->
	    Call (br, scan args)
	| CompCall (dst, args) ->
	    CompCall (scan dst, scan args)
	| Call_ext (abi, dst, args) ->
	    Call_ext (abi, dst, scan args)
	| Protect child ->
	    child
      and scan_ctl e =
	match ctl_fn e with
	  TailCall (br, code) ->
	    TailCall (br, scan code)
	| Jump _ as c -> c
	| Branch (code, tr, fa) ->
	    Branch (scan code, tr, fa)
	| Return code ->
	    Return (scan code)
	| CompTailCall (dst, arg) ->
	    CompTailCall (scan dst, scan arg)
	| CompJump (code, dl) ->
	    CompJump (scan code, dl)
	| TailCall_ext (abi, addr, code) ->
	    TailCall_ext (abi, addr, scan code)
	| Jump_ext _ as c -> c
	| CompJump_ext (abi, dst) ->
	    CompJump_ext (abi, scan dst)
	| Virtual_exit -> Virtual_exit
	| Protect_ctl ctl -> ctl in
      scan code
    
    let iter fn ?(ctl_fn = fun x -> ()) code =
      ignore (map (fun x -> fn x; x) ~ctl_fn:(fun c -> ctl_fn c; c) code)
    
    let id = ref 0
    
    let create_id () =
      incr id;
      !id
    
    let reset_id () =
      id := 0
  end

