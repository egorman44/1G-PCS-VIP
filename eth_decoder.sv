/*
 eth_decoder is auxilary class that stores derived signals from code_croup 
 that helps to transmit in state machins.
 */

class eth_decoder extends uvm_object;

`include "data_8b10b.sv"
`include "spec_8b10b.sv"

   `uvm_object_utils_begin(eth_decoder)
   `uvm_object_utils_end

   code_group_struct_t code_group_struct;

   code_group_t [3] three_code_group;
   code_group_t current_code_group;
   crd_t CRD_RX;
      
   bit is_comma; // Signal that indicates succesful code-group alignment
   bit is_special;
   bit is_data;
   bit is_invalid;
   bit cgbad, cggood;
   
   bit rx_even;

   // TODO:: analyze signals
   rudi_t_wrap::RUDI_t RUDI;
      
   extern function new(string name = "eth_decoder");

   // Decode methods
   extern function void decode_8b10b(code_group_t code_group , crd_t CRD);
   extern function void PUDI_calc();
   extern function crd_t crd_rx_rules(code_group_t code_group);
   
   // Setter methods
   extern function void RUDI_set(rudi_t_wrap::RUDI_t RUDI);
   extern function void SUDI_set_parity(bit rx_even);
   extern function void PUDI_set_comma(bit is_comma);
   extern function void PUDI_set_code_group(code_group_t [3] code_group);   
   
   // Getter methods
   extern function bit PUDI_is_comma();
   extern function bit PUDI_is_special();
   extern function bit PUDI_is_data();
   extern function bit PUDI_is_invalid();
   extern function bit PUDI_cggood();
   extern function bit PUDI_cgbad();

   extern function string SUDI_get_code_group_name();
   
   extern function bit SUDI_is_rx_even();
   extern function bit SUDI_is_invalid();
   extern function bit SUDI_is_data();
   extern function bit SUDI_is_K28_5();
   extern function bit SUDI_is_D2_2();
   extern function bit SUDI_is_D21_5();
   
   extern function bit is_S_ordered_set();
   extern function bit is_R_ordered_set();   
   
   extern function octet_t DECODE();

   extern function bit check_end___K28_5___D___K28_5();
   extern function bit check_end___K28_5___D21_5___D0_0();
   extern function bit check_end___K28_5___D2_2___D0_0();
   extern function bit check_end___T___R___K28_5();
   extern function bit check_end___T___R___R();
   extern function bit check_end___R___R___R();
   extern function bit check_end___R___R___S();
   extern function bit check_end___R___R___K28_5();
   
endclass // eth_decoder

function eth_decoder::new(string name = "eth_decoder");
   super.new(name);
endfunction: new

function void eth_decoder::PUDI_calc();
   decode_8b10b(three_code_group[0] , CRD_RX);   
endfunction // decode

// 36.2.4.6 Checking the validity of received code-groups
function void eth_decoder::decode_8b10b(code_group_t code_group , crd_t CRD);
   
   is_special	= '0;
   is_data	= '0;
   is_invalid	= '0;
   
   if(data_decode_8b10b_table_aa[CRD].exists(code_group[0])) begin
      is_data = '1;
      code_group_struct = data_decode_8b10b_table_aa[CRD][code_group[0]];      
   end
   else if(spec_decode_8b10b_table_aa[CRD].exists(code_group[0])) begin
      is_special = '1;
      code_group_struct = spec_decode_8b10b_table_aa[CRD][code_group[0]];
   end
   else begin
      is_invalid = '1;
   end

   cggood = !((is_comma && rx_even == EVEN) || is_invalid);
   cgbad  =  ((is_comma && rx_even == EVEN) || is_invalid);	 

endfunction // decode

// 36.2.4.4 Running disparity rules
function crd_t eth_decoder::crd_rx_rules(code_group_t code_group);
   
   int ones_abcdei, ones_fghj;
   
   ones_abcdei = $countones(code_group[0:5]);
   ones_fghj = $countones(code_group[6:9]);

   if(ones_abcdei > 3 && (code_group[0:5] == 6'b000_111))
     CRD_RX = POSITIVE;
   else if(ones_abcdei < 3 && (code_group[0:5] == 6'b111_000))
     CRD_RX = NEGATIVE;
   
   if(ones_fghj > 2 && (code_group[6:9] == 4'b00_11))
     CRD_RX = POSITIVE;
   else if(ones_fghj < 2 && (code_group[6:9] == 4'b11_00))
     CRD_RX = NEGATIVE;
   
endfunction // crd_rx_rules

///////////////////////////////////////////
// Setter Mathods

function void eth_decoder::RUDI_set(rudi_t_wrap::RUDI_t RUDI);
   this.RUDI = RUDI;
endfunction // RUDI_set

function void eth_decoder::SUDI_set_parity(bit rx_even);
   this.rx_even = rx_even;
endfunction // SUDI_set_parity

function void eth_decoder::PUDI_set_comma(bit is_comma);   
  this.is_comma = is_comma;
endfunction // PUDI_set_comma

function void eth_decoder::PUDI_set_code_group(code_group_t [3] code_group);   
   three_code_group = code_group;
   current_code_group = code_group[0];   
endfunction // PUDI_set_comma

///////////////////////////////////////////
// Getter Mathods

function bit eth_decoder::SUDI_is_K28_5();
   return is_comma;
endfunction // PUDI_is_comma

function bit eth_decoder::SUDI_is_D21_5();
   return is_comma;
endfunction // PUDI_is_comma

function bit eth_decoder::SUDI_is_D2_2();
   return is_comma;
endfunction // PUDI_is_comma

function bit eth_decoder::PUDI_is_comma();
   return is_comma;
endfunction // PUDI_is_comma

function bit eth_decoder::PUDI_is_special();
   return is_special;
endfunction

function bit eth_decoder::PUDI_is_data();
   return is_data;
endfunction // PUDI_is_data

function bit eth_decoder::PUDI_is_invalid();
   return is_invalid;
endfunction // PUDI_is_invalid

function bit eth_decoder::PUDI_cggood();
   return cggood;
endfunction // PUDI_is_comma

function bit eth_decoder::PUDI_cgbad();
   return cgbad;
endfunction // PUDI_is_comma

function bit eth_decoder::SUDI_is_rx_even();
   return rx_even;
endfunction // PUDI_is_comma

function bit eth_decoder::SUDI_is_invalid();
   return is_invalid;
endfunction // PUDI_is_comma

function bit eth_decoder::SUDI_is_data();
   return is_data;
endfunction // PUDI_is_comma

function string eth_decoder::SUDI_get_code_group_name();
   return code_group_struct.code_group_name;
endfunction // SUDI_get_code_group_name

function octet_t eth_decoder::DECODE();
   return code_group_struct.octet;
endfunction // SUDI_get_code_group_name

///////////////////////////////////////////////
// check_end functions implementation

function bit eth_decoder::check_end___K28_5___D___K28_5();
endfunction // check_end___K28_5___D___K28_5

function bit eth_decoder::check_end___K28_5___D21_5___D0_0();
endfunction // check_end___K28_5___D21_5___D0_0

function bit eth_decoder::check_end___K28_5___D2_2___D0_0();
endfunction // check_end___K28_5___D2_2___D0_0

function bit eth_decoder::check_end___T___R___K28_5();
endfunction // check_end___T___R___K28_5

function bit eth_decoder::check_end___T___R___R();
endfunction // check_end___T___R___R

function bit eth_decoder::check_end___R___R___R();
endfunction // check_end___R___R___R

function bit eth_decoder::check_end___R___R___S();
endfunction // check_end___R___R___S

function bit eth_decoder::check_end___R___R___K28_5();
endfunction // check_end___R___R___K28_5

///////////////////////////////////////////////
// check ordered set functions
function bit eth_decoder::is_S_ordered_set();
endfunction // is_S_ordered_set

function bit eth_decoder::is_R_ordered_set();
endfunction // is_R_ordered_set

