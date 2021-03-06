exception Elf_read_error of string

type elf_ehdr =
{
  e_type : int;
  e_machine : int;
  e_version: int32;
  e_entry : int32;
  e_phoff : int32;
  e_shoff : int32;
  e_flags : int32;
  e_ehsize : int;
  e_phentsize : int;
  e_phnum : int;
  e_shentsize : int;
  e_shnum : int;
  e_shstrndx : int
}

let parse_ehdr elfbits =
  bitmatch elfbits with
  | { 0x7f : 8; "ELF" : 24 : string;	(* ELF magic number.  *)
      _ : 12 * 8 : bitstring;		(* ELF identifier.  *)
      e_type : 16 : littleendian;	(* Object file type.  *)
      e_machine : 16 : littleendian;	(* Architecture.  *)
      e_version : 32 : littleendian;	(* Object file version.  *)
      e_entry : 32 : littleendian;	(* Entry point.  *)
      e_phoff : 32 : littleendian;	(* Program header table file offset.  *)
      e_shoff : 32 : littleendian;	(* Section header table offset.  *)
      e_flags : 32 : littleendian;	(* Processor-specific flags.  *)
      e_ehsize : 16 : littleendian;	(* ELF header size in bytes.  *)
      e_phentsize : 16 : littleendian;	(* Program header table entry size.  *)
      e_phnum : 16 : littleendian;	(* PHT entry count.  *)
      e_shentsize : 16 : littleendian;	(* Section header table entry size.  *)
      e_shnum : 16 : littleendian;	(* SHT entry count.  *)
      e_shstrndx : 16 : littleendian } -> (* Section header string table.  *)
      { e_type = e_type;
	e_machine = e_machine;
	e_version = e_version;
	e_entry = e_entry;
	e_phoff = e_phoff;
	e_shoff = e_shoff;
	e_flags = e_flags;
	e_ehsize = e_ehsize;
	e_phentsize = e_phentsize;
	e_phnum = e_phnum;
	e_shentsize = e_shentsize;
	e_shnum = e_shnum;
	e_shstrndx = e_shstrndx }
  | { _ } ->
      raise (Elf_read_error "Can't parse Elf Ehdr")

type elf_sht = SHT_NULL
	     | SHT_PROGBITS
	     | SHT_SYMTAB
	     | SHT_STRTAB
	     | SHT_RELA
	     | SHT_HASH
	     | SHT_DYNAMIC
	     | SHT_NOTE
	     | SHT_NOBITS
	     | SHT_REL
	     | SHT_SHLIB
	     | SHT_DYNSYM
	     | SHT_INIT_ARRAY
	     | SHT_FINI_ARRAY
	     | SHT_PREINIT_ARRAY
	     | SHT_GROUP
	     | SHT_SYMTAB_SHNDX
	     | SHT_NUM
	     | SHT_LOOS
	     | SHT_GNU_ATTRIBUTES
	     | SHT_GNU_HASH
	     | SHT_GNU_LIBLIST
	     | SHT_GNU_CHECKSUM
	     | SHT_CHECKSUM
	     | SHT_GNU_verdef
	     | SHT_GNU_verneed
	     | SHT_GNU_versym
	     | SHT_LOPROC
	     | SHT_ARM_EXIDX
	     | SHT_ARM_PREEMPTMAP
	     | SHT_ARM_ATTRIBUTES
	     | SHT_HIPROC
	     | SHT_LOUSER
	     | SHT_HIUSER

let decode_sht = function
    0l -> SHT_NULL
  | 1l -> SHT_PROGBITS
  | 2l -> SHT_SYMTAB
  | 3l -> SHT_STRTAB
  | 4l -> SHT_RELA
  | 5l -> SHT_HASH
  | 6l -> SHT_DYNAMIC
  | 7l -> SHT_NOTE
  | 8l -> SHT_NOBITS
  | 9l -> SHT_REL
  | 10l -> SHT_SHLIB
  | 11l -> SHT_DYNSYM
  | 14l -> SHT_INIT_ARRAY
  | 15l -> SHT_FINI_ARRAY
  | 16l -> SHT_PREINIT_ARRAY
  | 17l -> SHT_GROUP
  | 18l -> SHT_SYMTAB_SHNDX
  | 19l -> SHT_NUM
  | 0x60000000l -> SHT_LOOS
  | 0x6ffffff5l -> SHT_GNU_ATTRIBUTES
  | 0x6ffffff6l -> SHT_GNU_HASH
  | 0x6ffffff7l -> SHT_GNU_LIBLIST
  | 0x6ffffff8l -> SHT_CHECKSUM
  | 0x6ffffffdl -> SHT_GNU_verdef
  | 0x6ffffffel -> SHT_GNU_verneed
  | 0x6fffffffl -> SHT_GNU_versym
  | 0x70000000l -> SHT_LOPROC
  | 0x70000001l -> SHT_ARM_EXIDX
  | 0x70000002l -> SHT_ARM_PREEMPTMAP
  | 0x70000003l -> SHT_ARM_ATTRIBUTES
  | 0x7fffffffl -> SHT_HIPROC
  | 0x80000000l -> SHT_LOUSER
  | 0x8fffffffl -> SHT_HIUSER
  | _ -> failwith "decode_sht"

type elf_shdr =
{
  sh_name : int32;
  sh_type : elf_sht;
  sh_flags : int32;
  sh_addr : int32;
  sh_offset : int32;
  sh_size : int32;
  sh_link : int32;
  sh_info : int32;
  sh_addralign : int32;
  sh_entsize : int32
}

let parse_shdr elfbits =
  bitmatch elfbits with
    { sh_name : 32 : littleendian;	(* Section name (string tbl index).  *)
      sh_type : 32 : littleendian;	(* Section type.  *)
      sh_flags : 32 : littleendian;	(* Section flags.  *)
      sh_addr : 32 : littleendian;	(* Section virtual addr at
					   execution. *)
      sh_offset : 32 : littleendian;	(* Section file offset.  *)
      sh_size : 32 : littleendian;	(* Section size in bytes.  *)
      sh_link : 32 : littleendian;	(* Link to another section.  *)
      sh_info : 32 : littleendian;	(* Additional section information.  *)
      sh_addralign : 32 : littleendian;	(* Section alignment.  *)
      sh_entsize : 32 : littleendian } ->
					(* Entry size if section holds
					   table.  *)
      { sh_name = sh_name;
        sh_type = decode_sht sh_type;
	sh_flags = sh_flags;
	sh_addr = sh_addr;
	sh_offset = sh_offset;
	sh_size = sh_size;
	sh_link = sh_link;
	sh_info = sh_info;
	sh_addralign = sh_addralign;
	sh_entsize = sh_entsize }
  | { _ } ->
      raise (Elf_read_error "Can't parse Elf Shdr")

type elf_sym =
{
  st_name : int32;
  st_value : int32;
  st_size : int32;
  st_info : int;
  st_other : int;
  st_shndx : int
}

let parse_sym elfbits =
  bitmatch elfbits with
    { st_name : 32 : littleendian;	(* Symbol name (string tbl index).  *)
      st_value : 32 : littleendian;	(* Symbol value.  *)
      st_size : 32 : littleendian;	(* Symbol size.  *)
      st_info : 8 : littleendian;	(* Symbol type and binding.  *)
      st_other : 8 : littleendian;	(* Symbol visibility.  *)
      st_shndx : 16 : littleendian;	(* Section index.  *)
      rest : -1 : bitstring } ->
      { st_name = st_name;
        st_value = st_value;
	st_size = st_size;
	st_info = st_info;
	st_other = st_other;
	st_shndx = st_shndx }, rest
  | { _ } ->
      raise (Elf_read_error "Can't parse symbol")

type elf_syminfo =
{
  si_boundto : int;
  si_flags : int
}

let parse_syminfo elfbits =
  bitmatch elfbits with
    { si_boundto : 16 : littleendian;	(* Direct bindings, symbol bound to.  *)
      si_flags : 16 : littleendian } ->	(* Per symbol flags.  *)
      { si_boundto = si_boundto;
        si_flags = si_flags }
  | { _ } ->
      raise (Elf_read_error "Can't parse syminfo")

type arm_rel = R_ARM_NONE
	     | R_ARM_PC24
	     | R_ARM_ABS32
	     | R_ARM_REL32
	     | R_ARM_PC13
	     | R_ARM_ABS16
	     | R_ARM_ABS12
	     | R_ARM_THM_ABS5
	     | R_ARM_ABS8
	     | R_ARM_SBREL32
	     | R_ARM_THM_PC22
	     | R_ARM_THM_PC8
	     | R_ARM_AMP_VCALL9
	     | R_ARM_SWI24
	     | R_ARM_THM_SWI8
	     | R_ARM_XPC25
	     | R_ARM_THM_XPC22
	     | R_ARM_TLS_DTPMOD32
	     | R_ARM_TLS_DTPOFF32
	     | R_ARM_TLS_TPOFF32
	     | R_ARM_COPY
	     | R_ARM_GLOB_DAT
	     | R_ARM_JUMP_SLOT
	     | R_ARM_RELATIVE
	     | R_ARM_GOTOFF
	     | R_ARM_GOTPC
	     | R_ARM_GOT32
	     | R_ARM_PLT32
	     | R_ARM_ALU_PCREL_7_0
	     | R_ARM_ALU_PCREL_15_8
	     | R_ARM_ALU_PCREL_23_15
	     | R_ARM_ALU_SBREL_11_0
	     | R_ARM_ALU_SBREL_19_12
	     | R_ARM_ALU_SBREL_27_20
	     | R_ARM_TARGET1
	     | R_ARM_SBREL31
	     | R_ARM_V4BX
	     | R_ARM_TARGET2
	     | R_ARM_PREL31
	     | R_ARM_MOVW_ABS_NC
	     | R_ARM_MOVT_ABS
	     | R_ARM_MOVW_PREL_NC
	     | R_ARM_MOVT_PREL
	     | R_ARM_THM_MOVW_ABS_NC
	     | R_ARM_THM_MOVT_ABS
	     | R_ARM_THM_MOVW_PREL_NC
	     | R_ARM_THM_MOVT_PREL
	     | R_ARM_THM_JUMP19
	     | R_ARM_THM_JUMP6
	     | R_ARM_THM_ALU_PREL_11_0
	     | R_ARM_THM_PC12
	     | R_ARM_ABS32_NOI
	     | R_ARM_REL32_NOI
	     | R_ARM_ALU_PC_G0_NC
	     | R_ARM_ALU_PC_G0
	     | R_ARM_ALU_PC_G1_NC
	     | R_ARM_ALU_PC_G1
	     | R_ARM_ALU_PC_G2
	     | R_ARM_LDR_PC_G1
	     | R_ARM_LDR_PC_G2
	     | R_ARM_LDRS_PC_G0
	     | R_ARM_LDRS_PC_G1
	     | R_ARM_LDRS_PC_G2
	     | R_ARM_LDC_PC_G0
	     | R_ARM_LDC_PC_G1
	     | R_ARM_LDC_PC_G2
	     | R_ARM_ALU_SB_G0_NC
	     | R_ARM_ALU_SB_G0
	     | R_ARM_ALU_SB_G1_NC
	     | R_ARM_ALU_SB_G1
	     | R_ARM_ALU_SB_G2
	     | R_ARM_LDR_SB_G0
	     | R_ARM_LDR_SB_G1
	     | R_ARM_LDR_SB_G2
	     | R_ARM_LDRS_SB_G0
	     | R_ARM_LDRS_SB_G1
	     | R_ARM_LDRS_SB_G2
	     | R_ARM_LDC_SB_G0
	     | R_ARM_LDC_SB_G1
	     | R_ARM_LDC_SB_G2
	     | R_ARM_MOVW_BREL_NC
	     | R_ARM_MOVT_BREL
	     | R_ARM_MOVW_BREL
	     | R_ARM_THM_MOVW_BREL_NC
	     | R_ARM_THM_MOVT_BREL
	     | R_ARM_THM_MOVW_BREL
	     | R_ARM_TLS_GOTDESC
	     | R_ARM_TLS_CALL
	     | R_ARM_TLS_DESCSEQ
	     | R_ARM_THM_TLS_CALL
	     | R_ARM_PLT32_ABS
	     | R_ARM_GOT_ABS
	     | R_ARM_GOT_PREL
	     | R_ARM_GOT_BREL12
	     | R_ARM_GOTOFF12
	     | R_ARM_GOTRELAX
	     | R_ARM_GNU_VTENTRY
	     | R_ARM_GNU_VTINHERIT
	     | R_ARM_THM_PC11
	     | R_ARM_THM_PC9
	     | R_ARM_TLS_GD32
	     | R_ARM_TLS_LDM32
	     | R_ARM_TLS_LDO32
	     | R_ARM_TLS_IE32
	     | R_ARM_TLS_LE32
	     | R_ARM_PRIVATE of int
	     | R_ARM_RXPC25
	     | R_ARM_RSBREL32
	     | R_ARM_THM_RPC22
	     | R_ARM_RREL32
	     | R_ARM_RABS22
	     | R_ARM_RPC24
	     | R_ARM_RBASE

let decode_arm_rel = function
    0 -> R_ARM_NONE
  | 1 -> R_ARM_PC24
  | 2 -> R_ARM_ABS32
  | 3 -> R_ARM_REL32
  | 4 -> R_ARM_PC13
  | 5 -> R_ARM_ABS16
  | 6 -> R_ARM_ABS12
  | 7 -> R_ARM_THM_ABS5
  | 8 -> R_ARM_ABS8
  | 9 -> R_ARM_SBREL32
  | 10 -> R_ARM_THM_PC22
  | 11 -> R_ARM_THM_PC8
  | 12 -> R_ARM_AMP_VCALL9
  | 13 -> R_ARM_SWI24
  | 14 -> R_ARM_THM_SWI8
  | 15 -> R_ARM_XPC25
  | 16 -> R_ARM_THM_XPC22
  | 17 -> R_ARM_TLS_DTPMOD32
  | 18 -> R_ARM_TLS_DTPOFF32
  | 19 -> R_ARM_TLS_TPOFF32
  | 20 -> R_ARM_COPY
  | 21 -> R_ARM_GLOB_DAT
  | 22 -> R_ARM_JUMP_SLOT
  | 23 -> R_ARM_RELATIVE
  | 24 -> R_ARM_GOTOFF
  | 25 -> R_ARM_GOTPC
  | 26 -> R_ARM_GOT32
  | 27 -> R_ARM_PLT32
  | 32 -> R_ARM_ALU_PCREL_7_0
  | 33 -> R_ARM_ALU_PCREL_15_8
  | 34 -> R_ARM_ALU_PCREL_23_15
  | 35 -> R_ARM_ALU_SBREL_11_0
  | 36 -> R_ARM_ALU_SBREL_19_12
  | 37 -> R_ARM_ALU_SBREL_27_20
  | 57 -> R_ARM_ALU_PC_G0_NC
  | 100 -> R_ARM_GNU_VTENTRY
  | 101 -> R_ARM_GNU_VTINHERIT
  | 102 -> R_ARM_THM_PC11
  | 103 -> R_ARM_THM_PC9
  | 104 -> R_ARM_TLS_GD32
  | 105 -> R_ARM_TLS_LDM32
  | 106 -> R_ARM_TLS_LDO32
  | 107 -> R_ARM_TLS_IE32
  | 108 -> R_ARM_TLS_LE32
  | x when x >= 112 && x <= 127 -> R_ARM_PRIVATE (x - 112)
  | 249 -> R_ARM_RXPC25
  | 250 -> R_ARM_RSBREL32
  | 251 -> R_ARM_THM_RPC22
  | 252 -> R_ARM_RREL32
  | 253 -> R_ARM_RABS22
  | 254 -> R_ARM_RPC24
  | 255 -> R_ARM_RBASE
  | x -> raise (Elf_read_error (Printf.sprintf "decode_arm_rel (%d)" x))

type elf_rel =
{
  rel_offset : int32;
  rel_type : arm_rel;
  rel_sym_index : int
}

let parse_rel elfbits =
  bitmatch elfbits with
    { r_offset : 32 : littleendian;	(* Address.  *)
      r_info : 32 : littleendian;
      rest : -1 : bitstring } ->	(* Relocation type and symbol index.  *)
      { rel_offset = r_offset;
        rel_type = decode_arm_rel ((Int32.to_int r_info) land 255);
	rel_sym_index = (Int32.to_int (Int32.shift_right_logical r_info 8))},
      rest
  | { _ } ->
      raise (Elf_read_error "Can't parse rel")

let parse_rel_sec elfbits =
  let rec scan acc bits =
    let rel, more = parse_rel bits in
    let acc' = rel::acc in
    if Bitstring.bitstring_length more = 0 then begin
      Log.printf 3 "Parsed %d relocations\n" (List.length acc');
      Array.of_list (List.rev acc')
    end else
      scan acc' more in
  scan [] elfbits

type elf_rela =
{
  rela_offset : int32;
  rela_info : int32;
  rela_addend : int32
}

let parse_rela elfbits =
  bitmatch elfbits with
    { r_offset : 32 : littleendian;	(* Address.  *)
      r_info : 32 : littleendian;	(* Relocation type and symbol index.  *)
      r_addend : 32 : littleendian } ->	(* Addend.  *)
      { rela_offset = r_offset;
        rela_info = r_info;
	rela_addend = r_addend }
  | { _ } ->
      raise (Elf_read_error "Can't parse rela")

type elf_phdr =
{
  p_type : int32;
  p_offset : int32;
  p_vaddr : int32;
  p_paddr : int32;
  p_filesz : int32;
  p_memsz : int32;
  p_flags : int32;
  p_align : int32
}

let parse_phdr elfbits =
  bitmatch elfbits with
    { p_type : 32 : littleendian;	(* Segment type.  *)
      p_offset : 32 : littleendian;	(* Segment file offset.  *)
      p_vaddr : 32 : littleendian;	(* Segment virtual address.  *)
      p_paddr : 32 : littleendian;	(* Segment physical address.  *)
      p_filesz : 32 : littleendian;	(* Segment size in file.  *)
      p_memsz : 32 : littleendian;	(* Segment size in memory.  *)
      p_flags : 32 : littleendian;	(* Segment flags.  *)
      p_align : 32 : littleendian } ->	(* Segment alignment.  *)
      { p_type = p_type;
        p_offset = p_offset;
	p_vaddr = p_vaddr;
	p_paddr = p_paddr;
	p_filesz = p_filesz;
	p_memsz = p_memsz;
	p_flags = p_flags;
	p_align = p_align }
  | { _ } ->
      raise (Elf_read_error "Can't parse phdr")

(*
let parse_dyn elfbits =
  bitmatch elfbits with
    { d_tag : 32 : littleendian;	(* Dynamic entry type.  *)
      d_val : 32 : littleendian } ->	(* Integer value (or address value).  *)
  | { _ } ->
      raise (Elf_read_error "Can't parse dyn")
*)

let bits n = Int32.mul 8l n

let extract_section elfbits shdr =
  Bitstring.subbitstring elfbits (Int32.to_int (bits shdr.sh_offset))
    (Int32.to_int (bits shdr.sh_size))

let get_string stringsec offset =
  let b = Buffer.create 10 in
  let rec gather bits =
    bitmatch bits with
      { "\000" : 8 : string } -> Buffer.contents b
    | { c : 8 : string } ->
        Buffer.add_string b c;
	gather (Bitstring.dropbits 8 bits) in
  gather (Bitstring.dropbits (offset * 8) stringsec)

let read_file filename =
  let elfbits = Bitstring.bitstring_of_file filename in
  let ehdr = parse_ehdr elfbits in
  Printf.printf "Number of program headers: %d\n" ehdr.e_phnum;
  Printf.printf "Program header offset: %ld\n" ehdr.e_phoff;
  Printf.printf "Number of section headers: %d\n" ehdr.e_shnum;
  Printf.printf "Section header offset: %ld\n" ehdr.e_shoff;
  elfbits, ehdr

let get_section_headers elfbits ehdr =
  Array.init ehdr.e_shnum
    (fun i ->
      let shdr_bits = Bitstring.subbitstring elfbits
        (8 * ((Int32.to_int ehdr.e_shoff) + i * ehdr.e_shentsize))
	(8 * ehdr.e_shentsize) in
      parse_shdr shdr_bits)

let get_program_headers elfbits ehdr =
  Array.init ehdr.e_phnum
    (fun i ->
      let phdr_bits = Bitstring.subbitstring elfbits
        (8 * ((Int32.to_int ehdr.e_phoff) + i * ehdr.e_phentsize))
	(8 * ehdr.e_phentsize) in
      parse_phdr phdr_bits)

let get_section_name elfbits ehdr shdr_arr num =
  let sec_string_tab = extract_section elfbits shdr_arr.(ehdr.e_shstrndx) in
  get_string sec_string_tab (Int32.to_int shdr_arr.(num).sh_name)

let print_section_names elfbits ehdr shdr_arr =
  let sec_string_tab = extract_section elfbits shdr_arr.(ehdr.e_shstrndx) in
  for i = 0 to (Array.length shdr_arr - 1) do
    Printf.printf "Section %d: name '%s'\n" i
      (get_string sec_string_tab (Int32.to_int shdr_arr.(i).sh_name))
  done

let get_section_by_name elfbits ehdr shdr_arr name =
  let sec_string_tab = extract_section elfbits shdr_arr.(ehdr.e_shstrndx) in
  let found_sec = ArrayLabels.fold_left
    ~f:(fun found shdr ->
      match found with
        Some _ -> found
      | None ->
          let this_section_name =
	    get_string sec_string_tab (Int32.to_int shdr.sh_name) in
	  if this_section_name = name then Some shdr else found)
    ~init:None
    shdr_arr in
  match found_sec with
    None ->
      Log.printf 1 "Warning: section '%s' not found, substituting dummy\n" name;
      Bitstring.empty_bitstring
  | Some shdr -> extract_section elfbits shdr

let get_section_number elfbits ehdr shdr_arr name =
  let sec_string_tab = extract_section elfbits shdr_arr.(ehdr.e_shstrndx) in
  let found = ref None in
  for i = 1 to Array.length shdr_arr - 1 do
    let this_section_name = get_string sec_string_tab
			      (Int32.to_int shdr_arr.(i).sh_name) in
    if this_section_name = name then
      found := Some i
  done;
  match !found with
    None -> raise Not_found
  | Some n -> n

let get_section_num_by_addr elfbits ehdr shdr_arr addr =
  let found_sec = ref None in
  for i = 1 to Array.length shdr_arr - 1 do
    if addr >= shdr_arr.(i).sh_addr
       && addr < (Int32.add shdr_arr.(i).sh_addr shdr_arr.(i).sh_size)
       && !found_sec = None && shdr_arr.(i).sh_type = SHT_PROGBITS then
      found_sec := Some i
  done;
  match !found_sec with
    None -> raise Not_found
  | Some n -> n

(* Return bits from SECTION offset by OFFSET bytes.  *)

let offset_section secbits offset =
  Bitstring.dropbits (8 * (Int32.to_int offset)) secbits

let section_writable sec =
  (Int32.logand sec.sh_flags 0x1l) <> 0l

let get_word shdr section addr =
  let start_offset = Int32.sub addr shdr.sh_addr in
  let sec_bits = Bitstring.dropbits (8 * (Int32.to_int start_offset)) section in
  bitmatch sec_bits with
    { word : 32 : littleendian } -> word
  | { _ } -> failwith "can't read word"
