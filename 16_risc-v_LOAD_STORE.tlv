\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])



   //---------------------------------------------------------------------------------
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  x12 (a2): 10
   //  x13 (a3): 1..10
   //  x14 (a4): Sum
   // 
   m4_test_prog()
   // m4_asm(ADDI, x14, x0, 0)             // Initialize sum register a4 with 0
   // m4_asm(ADDI, x12, x0, 1010)          // Store count of 10 in register a2.
   // m4_asm(ADDI, x13, x0, 1)             // Initialize loop count register a3 with 0
   // // Loop:
   // m4_asm(ADD, x14, x13, x14)           // Incremental summation
   // m4_asm(ADDI, x13, x13, 1)            // Increment loop count by 1
   // m4_asm(BLT, x13, x12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   // // Test result value in x14, and set x31 to reflect pass/fail.
   // m4_asm(ADDI, x30, x14, 111111010100) // Subtract expected value of 44 to set x30 to 1 if and only iff the result is 45 (1 + 2 + ... + 9).
   // m4_asm(BGE, x0, x0, 0) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   // //m4_asm(ADDI, x0, x0, 111111010100) //check if x0 is hard-wired to 0
   // m4_asm_end()
   // m4_define(['M4_MAX_CYC'], 50)
   //---------------------------------------------------------------------------------



\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   
   // YOUR CODE HERE
   //PC
   $pc[31:0] = >>1$next_pc[31:0];
   $next_pc[31:0] = $reset ? 32'b0 :
                    $taken_br ? $br_tgt_pc[31:0] :
                    $is_jal ? $br_tgt_pc[31:0] :
                    $is_jalr ? $jalr_tgt_pc[31:0] : 
                            ($pc[31:0] + 32'b100);
   //IMem
   `READONLY_MEM($pc, $$instr[31:0]) //Verilog macro
   //DECODE
     //Instruction Type, assuming instr[1:0]=11
   $is_r_instr = $instr[6:2] ==? 5'b01011 ||
                 $instr[6:2] == 5'b011x0 ||
                 $instr[6:2] == 5'b10100;
   $is_i_instr = $instr[6:2] ==? 5'b0000x ||
                 $instr[6:2] == 5'b11001 ||
                 $instr[6:2] ==? 5'b001x0;
   $is_s_instr = $instr[6:2] ==? 5'b0100x;
   $is_b_instr = $instr[6:2] == 5'b11000;
   $is_u_instr = $instr[6:2] ==? 5'b0x101;
   $is_j_instr = $instr[6:2] == 5'b11011;
     //Instruction Fields, based on Instruction Type
   $opcode[6:0] = $instr[6:0];
   $rd[4:0] = $instr[11:7];
   $rs1[4:0] = $instr[19:15];
   $rs2[4:0] = $instr[24:20];
   $funct3[2:0] = $instr[14:12];
   $funct7[6:0] = $instr[31:25];
    //Instruction Fields, determines if fields are valid
   $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
   $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;
   $funct7_valid = $is_r_instr;
    //Instruction Fields, immediate value
   $imm[31:0] = $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
                $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:8], $instr[7] } :
                $is_b_instr ? { {19{$instr[31]}}, {2{$instr[7]}}, $instr[30:25], $instr[11:8], 1'b0 } :
                $is_u_instr ? { $instr[31], $instr[30:20], $instr[19:12], 12'b0 } :
                $is_j_instr ? { {11{$instr[31]}}, $instr[19:12], {2{$instr[20]}}, $instr[30:21], 1'b0 } :
                32'b0;
    //Instruction is determined by opcode, instr[30], funct3
   $dec_bits[10:0] = {$instr[30],$funct3,$opcode};
   //Recognize instructions
   $is_lui = $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
   $is_jal = $dec_bits ==? 11'bx_xxx_1101111;
   $is_jalr = $dec_bits ==? 11'bx_000_1100111;
   $is_beq = $dec_bits ==? 11'bx_000_1100011;
   $is_bne = $dec_bits ==? 11'bx_001_1100011;
   $is_blt = $dec_bits ==? 11'bx_100_1100011;
   $is_bge = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   $is_lb = $dec_bits ==? 11'bx_000_0000011;
   $is_lh = $dec_bits ==? 11'bx_001_0000011;
   $is_lw = $dec_bits ==? 11'bx_010_0000011;
   $is_lbu = $dec_bits ==? 11'bx_100_0000011;
   $is_lhu = $dec_bits ==? 11'bx_101_0000011;
   //$is_sb = $dec_bits ==? 11'bx_000_0100011;
   //$is_sh = $dec_bits ==? 11'bx_001_0100011;
   //$is_sw = $dec_bits ==? 11'bx_010_0100011;
   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_slti = $dec_bits ==? 11'bx_010_0010011;

   $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
   $is_xori = $dec_bits ==? 11'bx_100_0010011;
   $is_ori = $dec_bits ==? 11'bx_110_0010011;
   $is_andi = $dec_bits ==? 11'bx_111_0010011;
   $is_slli = $dec_bits ==? 11'b0_001_0010011;
   $is_srli = $dec_bits ==? 11'b0_101_0010011;
   $is_srai = $dec_bits ==? 11'b1_101_0010011;
   $is_add = $dec_bits ==? 11'b0_000_0110011;
   $is_sub = $dec_bits ==? 11'b1_000_0110011;
   $is_sll = $dec_bits ==? 11'b0_001_0110011;
   $is_slt = $dec_bits ==? 11'b0_010_0110011;
   $is_sltu = $dec_bits ==? 11'b0_011_0110011;
   $is_xor = $dec_bits ==? 11'b0_100_0110011;
   $is_srl = $dec_bits ==? 11'b0_101_0110011;
   $is_sra = $dec_bits ==? 11'b1_101_0110011;
   $is_or = $dec_bits ==? 11'b0_110_0110011;
   $is_and = $dec_bits ==? 11'b0_111_0110011;

   //Since we don't recognize different stores and loads (LB, LH, LW, LBU, LHU, SB, SH, SW). Store already defined as is_s_instr
   $is_load = $is_lb || $is_lh || $is_lw || $is_lbu || $is_lhu;

   //SLTU, SLTI (set if less than)
   $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value};
   $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
   //SRA and SRAI (shift right, arithmetic)
   // sign-extended src1
   $sext_src1[63:0] = { {32{$src1_value[31]}}, $src1_value};
   // 64-bit sign-extended results, to be truncated
   $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
   $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];

   //ALU
   $result[31:0] =
    $is_andi ? $src1_value & $imm :
    $is_ori ? $src1_value | $imm :
    $is_xori ? $src1_value ^ $imm :
    $is_addi ?  $src1_value + $imm :
    $is_slli ? $src1_value << $imm[5:0] :
    $is_srli ? $src1_value >> $imm[5:0] :
    $is_and ? $src1_value & $src2_value :
    $is_or ? $src1_value | $src2_value :
    $is_xor ? $src1_value ^ $src2_value :
    $is_add ? $src1_value + $src2_value :
    $is_sub ? $src1_value - $src2_value :
    $is_sll ? $src1_value << $src2_value[4:0] :
    $is_srl ? $src1_value >> $src2_value[4:0] :
    $is_sltu ? $sltu_rslt :
    $is_sltiu ? $sltiu_rslt :
    $is_lui ? {$imm[31:12], 12'b0} :
    $is_auipc ? $pc + $imm :
    $is_jal ? $pc + 32'd4 :
    $is_jalr ? $pc + 32'd4 :
    $is_slt ? ( ($src1_value[31] == $src2_value[31]) ?
            $sltu_rslt :
            {31'b0, $src1_value[31]} ) :
    $is_slti ? ( ($src1_value[31] == $imm[31]) ?
            $sltiu_rslt :
            {31'b0, $src1_value[31]} ) :
    $is_sra ? $sra_rslt[31:0] :
    $is_srai ? $srai_rslt[31:0] :
    $is_load | $is_s_instr ? $src1_value + $imm :
               32'b0; 
    
   //Hard-wire x0
   $result_RF[31:0] = $rd[4:0] == 5'd0 ? 32'd0 :
                      $is_load ? $ld_data :
                      $result[31:0];

   //Branch unit
   $taken_br = $is_beq ? ($src1_value == $src2_value) :
                     $is_bne ? ($src1_value != $src2_value) :
                     $is_blt ? ($src1_value < $src2_value ^ $src1_value[31] != $src2_value[31]) :
                     $is_bge ? ($src1_value >= $src2_value ^ $src1_value[31] != $src2_value[31]) :
                     $is_bltu ? ($src1_value < $src2_value) :
                     $is_bgeu ? ($src1_value >= $src2_value) :
                     1'b0;

   //Next instruction location for branching
   $br_tgt_pc[31:0] = $pc[31:0] + $imm[31:0];
   $jalr_tgt_pc[31:0] = $src1_value + $imm;
   //update mux of the PC (in the PC section)


    //Remove warning about unassigned outputs
   `BOGUS_USE($funct3_valid $funct7 $funct7_valid $imm_valid ) 
   // Assert these to end simulation (before Makerchip cycle limit).
   //*passed = 1'b0;
   m4+tb() 
   *failed = *cyc_cnt > M4_MAX_CYC;

   m4+rf(32, 32, $reset, $rd_valid, $rd[4:0], $result_RF[31:0], $rs1_valid, $rs1[4:0], $src1_value, $rs2_valid, $rs2[4:0], $src2_value)
   m4+dmem(32, 32, $reset, $result[6:2], $is_s_instr, $src2_value, $is_load, $ld_data)
   m4+cpu_viz()
\SV
   endmodule