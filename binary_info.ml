open Elfreader
open Dwarfreader

type var_decl =
  {
    vardecl_type : Ctype.ctype;
    vardecl_extern : bool
  }

type cu_info = {
  (* The directory the CU was built in.  *)
  mutable ci_directory : string;
  (* Base address of this compilation unit in the binary.  *)
  ci_baseaddr : int32;
  (* Address size for CU.  *)
  ci_addrsize : int;
  (* Debug info entries for compilation unit, indexed by offset into table.  *)
  ci_dietab : (int, tag_attr_die) Hashtbl.t;
  (* Symbols defined in CU, indexed by symbol address.  *)
  ci_symtab : (int32, elf_sym) Hashtbl.t;
  (* Debug info entries for symbol address, indexed by "low PC".  *)
  ci_dieaddr : (int32, tag_attr_die) Hashtbl.t;
  (* Just the parsed dies.  *)
  ci_dies : tag_attr_die;
  (* Table mapping type names (strings) to C types for this CU.  *)
  ci_ctypes : Ctype.ctype_info;
  (* Parsed line number info for compilation unit.  *)
  ci_lines : Line.line_prog_hdr;
  (* Global variables -- indexed by name.  *)
  ci_globalvars : (string, var_decl) Hashtbl.t
}

type lib_info =
  {
    lib_name : string;
    lib_info : binary_info
  }

and binary_info = {
  elfbits : Bitstring.bitstring;
  ehdr : elf_ehdr;
  shdr_arr : elf_shdr array;
  debug_info : Bitstring.bitstring;
  debug_abbrev : Bitstring.bitstring;
  debug_str_sec : Bitstring.bitstring;
  debug_line : Bitstring.bitstring;
  debug_pubnames : Bitstring.bitstring;
  debug_aranges : Bitstring.bitstring;
  debug_ranges : Bitstring.bitstring;
  debug_loc : Bitstring.bitstring;
  text : Bitstring.bitstring;
  rodata : Bitstring.bitstring;
  strtab : Bitstring.bitstring;
  symtab : Bitstring.bitstring;
  plt : Bitstring.bitstring;
  rel_plt : Bitstring.bitstring;
  dynsym : Bitstring.bitstring;
  dynstr : Bitstring.bitstring;
  symbols : elf_sym list;
  dyn_symbols : elf_sym list;
  mapping_syms : elf_sym Coverage.coverage;
  rodata_sliced : Slice_section.slicetype Coverage.coverage;
  (* Parsed arange data.  *)
  parsed_aranges : (aranges_header * (int32 * int32) list) list;
  (* Parsed range data.  *)
  parsed_ranges : (int32, int32 -> (int32 * int32) list) Hashtbl.t;
  (* Relocations from the .rel.plt section.  *)
  parsed_rel_plt : elf_rel array;
  (* Hashtbl of cu_infos, indexed by debug_info offset.  *)
  cu_hash : (int32, cu_info) Hashtbl.t;
  (* External libraries used by this binary.  *)
  mutable libs : lib_info list
}

let index_dies_by_low_pc cu_inf dies =
  let dieaddr_ht = cu_inf.ci_dieaddr in
  (*Log.printf 3 "index_dies_by_low_pc\n";*)
  let rec scan = function
    Die_node ((DW_TAG_compile_unit, attrs), children) ->
      let dir =
        try get_attr_string attrs DW_AT_comp_dir with Not_found -> "" in
      cu_inf.ci_directory <- dir;
      scan children
  | Die_tree ((DW_TAG_subprogram, sp_attrs), children, sibl) as die ->
      begin try
        let name = get_attr_string sp_attrs DW_AT_name in
        let lowpc = get_attr_address sp_attrs DW_AT_low_pc in
	(*Log.printf 3 "name: '%s', low pc: %lx\n" name lowpc;*)
	Hashtbl.add dieaddr_ht lowpc die
      with Not_found -> ()
      end;
      scan children;
      scan sibl
  | Die_node ((DW_TAG_subprogram, sp_attrs), sibl) as die ->
      begin try
        let name = get_attr_string sp_attrs DW_AT_name in
        let lowpc = get_attr_address sp_attrs DW_AT_low_pc in
	(*Log.printf 3 "name: '%s', low pc: %lx\n" name lowpc;*)
	Hashtbl.add dieaddr_ht lowpc die
      with Not_found -> ()
      end;
      scan sibl
  | Die_tree ((_, attrs), children, sibl) ->
      let name = try get_attr_string attrs DW_AT_name
      with Not_found -> "unknown name" in
      (*Log.printf 4 "tree (%s)\n" name;*)
      scan children;
      scan sibl
  | Die_node ((_, attrs), sibl) ->
      let name = try get_attr_string attrs DW_AT_name
      with Not_found -> "unknown name" in
      (*Log.printf 4 "node (%s)\n" name;*)
      scan sibl
  | Die_empty -> ()
  in
  scan dies

(* Assumes DW_TAG_compile_unit comes first... hm.  *)

let base_addr_for_comp_unit cu_die =
  match cu_die with
    Die_node ((DW_TAG_compile_unit, attrs), _) ->
      get_attr_address attrs DW_AT_low_pc
  | _ -> raise Not_found

let debug_lines_for_comp_unit cu_die =
  match cu_die with
    Die_node ((DW_TAG_compile_unit, attrs), _) ->
      get_attr_int32 attrs DW_AT_stmt_list
  | _ -> raise Not_found

let index_debug_data binf parsed_data =
  List.iter
    (fun (ar_hdr, ranges) ->
      let debug_inf_for_hdr =
        offset_section binf.debug_info ar_hdr.ar_debug_info_offset in
	let cu_header, after_cu_hdr =
	  parse_comp_unit_header debug_inf_for_hdr in
	  let debug_abbr_offset = cu_header.debug_abbrev_offset in
	  let debug_abbr = offset_section binf.debug_abbrev debug_abbr_offset in
	  let abbrevs = parse_abbrevs debug_abbr in
	  Log.printf 4 "Parsed %d abbrevs\n" (Array.length abbrevs);
	  let cu_dies, die_hash, _ =
	    parse_die_for_cu after_cu_hdr
	      ~length:(Bitstring.bitstring_length debug_inf_for_hdr)
	      ~abbrevs:abbrevs ~addr_size:cu_header.address_size
	      ~string_sec:binf.debug_str_sec in
	  let lines, _ =
	    Line.parse_lines (offset_section binf.debug_line
				(debug_lines_for_comp_unit cu_dies)) in
	  let cu_inf = {
	    ci_directory = ""; (* Set properly in index_dies_by_low_pc.  *)
	    ci_baseaddr = base_addr_for_comp_unit cu_dies;
	    ci_addrsize = cu_header.address_size;
	    ci_dietab = die_hash;
	    ci_symtab = Hashtbl.create 10;
	    ci_dieaddr = Hashtbl.create 10;
	    ci_dies = cu_dies;
	    ci_ctypes = {
	      Ctype.ct_typedefs = Hashtbl.create 10;
	      ct_typetags = Hashtbl.create 10
	    };
	    ci_lines = lines;
	    ci_globalvars = Hashtbl.create 10
	  } in
	  List.iter
	    (fun (start, len) ->
	      let syms =
	        Symbols.find_symbols_for_addr_range binf.symbols start
						    (Int32.add start len) in
	      List.iter
	        (fun sym ->
		  match Symbols.symbol_type sym with
		    Symbols.STT_FUNC ->
		      Hashtbl.add cu_inf.ci_symtab sym.st_value sym
		  | _ -> ())
		syms)
	    ranges;
	  index_dies_by_low_pc cu_inf cu_dies;
	  Hashtbl.add binf.cu_hash ar_hdr.ar_debug_info_offset cu_inf)
    parsed_data

let open_file filename =
  let elfbits, ehdr = read_file filename in
  let shdr_arr = get_section_headers elfbits ehdr in
  let debug_info = get_section_by_name elfbits ehdr shdr_arr ".debug_info" in
  let debug_abbrev = get_section_by_name elfbits ehdr shdr_arr
					 ".debug_abbrev" in
  let debug_str_sec = get_section_by_name elfbits ehdr shdr_arr ".debug_str" in
  let debug_line = get_section_by_name elfbits ehdr shdr_arr ".debug_line" in
  let debug_pubnames = get_section_by_name elfbits ehdr shdr_arr
					   ".debug_pubnames" in
  let debug_aranges = get_section_by_name elfbits ehdr shdr_arr
					  ".debug_aranges" in
  let debug_ranges = get_section_by_name elfbits ehdr shdr_arr
					 ".debug_ranges" in
  let debug_loc = get_section_by_name elfbits ehdr shdr_arr ".debug_loc" in
  let text = get_section_by_name elfbits ehdr shdr_arr ".text" in
  let rodata = get_section_by_name elfbits ehdr shdr_arr ".rodata" in
  let strtab = get_section_by_name elfbits ehdr shdr_arr ".strtab" in
  let symtab = get_section_by_name elfbits ehdr shdr_arr ".symtab" in
  let plt = get_section_by_name elfbits ehdr shdr_arr ".plt" in
  let rel_plt = get_section_by_name elfbits ehdr shdr_arr ".rel.plt" in
  let dynsym = get_section_by_name elfbits ehdr shdr_arr ".dynsym" in
  let dynstr = get_section_by_name elfbits ehdr shdr_arr ".dynstr" in
  let symbols = Symbols.read_symbols symtab in
  let dyn_symbols = Symbols.read_symbols dynsym in
  let mapping_syms = Mapping.get_mapping_symbols elfbits ehdr shdr_arr strtab
		     symbols ".text" in
  let rodata_shdrnum = get_section_number elfbits ehdr shdr_arr ".rodata" in
  let rodata_sliced = Coverage.create_coverage
    shdr_arr.(rodata_shdrnum).sh_addr shdr_arr.(rodata_shdrnum).sh_size in
  let ar = parse_all_arange_data debug_aranges in
  let ranges = parse_ranges debug_ranges in
  let plt_rels = parse_rel_sec rel_plt in
  let binf = {
    elfbits = elfbits;
    ehdr = ehdr;
    shdr_arr = shdr_arr;
    debug_info = debug_info;
    debug_abbrev = debug_abbrev;
    debug_str_sec = debug_str_sec;
    debug_line = debug_line;
    debug_pubnames = debug_pubnames;
    debug_aranges = debug_aranges;
    debug_ranges = debug_ranges;
    debug_loc = debug_loc;
    text = text;
    rodata = rodata;
    strtab = strtab;
    symtab = symtab;
    plt = plt;
    rel_plt = rel_plt;
    dynsym = dynsym;
    dynstr = dynstr;
    symbols = symbols;
    dyn_symbols = dyn_symbols;
    mapping_syms = mapping_syms;
    rodata_sliced = rodata_sliced;
    parsed_aranges = ar;
    parsed_ranges = ranges;
    parsed_rel_plt = plt_rels;
    cu_hash = Hashtbl.create 10;
    libs = []
  } in
  index_debug_data binf ar;
  binf

(* Given an address, find the compilation unit offset into the debug_info
   section.  This can be used to lookup CU_HASH in BINF.  *)

let cu_offset_for_address binf addr =
  let ar_hdr, _ = List.find
    (fun (ar_hdr, ranges) ->
      List.exists (fun (lo, len) -> addr >= lo && addr < (Int32.add lo len))
		  ranges)
    binf.parsed_aranges in
  ar_hdr.ar_debug_info_offset

