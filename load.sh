ocamlfind ocamlmktop -syntax camlp4o -package camlp4.macro,num,unix,bitstring,bitstring.syntax \
  -linkpkg elfreader.cmo dwarfreader.cmo dwarfprint.cmo line.cmo insn.cmo \
  decode_arm.cmo symbols.cmo mapping.cmo emit.cmo deque.cmo ranlist.cmo \
  boolset.cmo getoption.cmo code.cmo block.cmo ir.cmo insn_to_ir.cmo dfs.cmo \
  dominator.cmo phi.cmo typedb.cmo minipool.cmo decompiler.cmo -o decomp_top
exec ledit ./decomp_top
