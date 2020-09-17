
/*
 eth_decoder is auxilary class that stores derived signals from code_croup 
 that helps to transmit in state machines.
 */

class eth_decoder extends uvm_object;

`include "decode_8b10b.sv"

   `uvm_object_utils_begin(eth_decoder)
   `uvm_object_utils_end

   // Handle for printer object
   message_print msg_print;

   // queue with three items is used to store three 
   // consecutive code-groups for check_end() funciton.
   
   cg_struct_t cg_struct_q[$];

   // code group that is used for all calculations at
   // a current time slot. The current code-group is located 
   // in the cg_struct_q[0] item, since set_cg() function 
   // uses push_back() to shift items into the queue
   
   cg_struct_t cg_struct_current;

   // Shows that queue pipe is full and
   bit queue_full;

   // current value of RX running disparity
   crd_t CRD_RX;
   
   bit rx_even;

   // TODO:: analyze signals
   rudi_t_wrap::RUDI_t RUDI;
   
   extern function new(string name = "eth_decoder");

   //////////////////////////////////////////////
   // DECODER API FUNCTIONS
   //////////////////////////////////////////////
   
   extern function void cg_set(cg_t cg, bit comma);
   extern function bit cg_check_type(cg_type_t cg_type);
   extern function bit cg_check_name(string cg_name, cg_struct_t cg_struct = cg_struct_current);
   extern function bit cg_is_comma();
   extern function octet_t cg_decode();   
   extern function bit check_end(string cg_name_a[3]);
   extern function void check_end_print();
   extern function bit SUDI_is_rx_even();
   extern function void SUDI_set_parity(bit rx_even);
   extern function bit decoder_ready();
   
   //////////////////////////////////////////////
   // DECODER INTERNAL FUNCITONS
   //////////////////////////////////////////////
   
   extern function cg_struct_t decode_8b10b(cg_t cg , crd_t CRD, bit comma);
   extern function void crd_rx_rules(cg_t cg, ref crd_t crd);
   extern function bit carrier_detect();  
   extern function void cg_print(cg_struct_t cg_struct = cg_struct_current);
   extern function string os_convert(string os_name);
   extern function bit os_check(string os_name , cg_struct_t cg_struct = cg_struct_current);
   
endclass // eth_decoder

function eth_decoder::new(string name = "eth_decoder");
   super.new(name);
endfunction: new

// 36.2.5.1.4 Functions carrier_detect
function bit eth_decoder::carrier_detect();

   cg_t cg_K28_5_pos = 10'b001111_1010;
   cg_t cg_K28_5_neg = 10'b110000_0101;
   cg_t compare_vec_pos, compare_vec_neg;
   int diff_neg , diff_pos;
   
   compare_vec_neg = cg_struct_current.cg ^ cg_K28_5_neg;
   compare_vec_pos = cg_struct_current.cg ^ cg_K28_5_pos;

   diff_neg = $countones(compare_vec_neg);
   diff_pos = $countones(compare_vec_pos);

   `uvm_info("ETH_DECODER" , $sformatf("POSITIVE: compare = %10b , diff = %0d" , compare_vec_pos, diff_pos) , UVM_FULL)
   `uvm_info("ETH_DECODER" , $sformatf("NEGATIVE: compare = %10b , diff = %0d" , compare_vec_neg, diff_neg) , UVM_FULL)
   
   carrier_detect = 0;

   if(rx_even) begin
      if(diff_pos > 2 && diff_neg > 2)
	carrier_detect = 1;
      if(CRD_RX && diff_pos >= 2 && diff_pos <= 9)
	carrier_detect = 1;
      if(~CRD_RX && diff_neg >= 2 && diff_neg <= 9)
	carrier_detect = 1;
   end
   
endfunction // carrier_detect

// 36.2.4.6 Checking the validity of received code-groups
function cg_struct_t eth_decoder::decode_8b10b(cg_t cg , crd_t CRD, bit comma);
   
   cg_struct_t cg_struct;
   
   cg_struct.cg = cg;

   `uvm_info("ETH_DECODER" , $sformatf("CRD: %0s CG: %10b" , CRD.name() , cg) , UVM_FULL)
   
   if(data_decode_8b10b_table_aa[CRD].exists(cg)) begin
      cg_struct.cg_type = DATA;
      cg_struct.octet = data_decode_8b10b_table_aa[CRD][cg];
      cg_struct.cg_name = $sformatf("D%0d_%0d" , cg_struct.octet[4:0] , cg_struct.octet[7:5]);
   end
   else if(spec_decode_8b10b_table_aa[CRD].exists(cg)) begin
      cg_struct.cg_type = SPECIAL;
      cg_struct.octet = spec_decode_8b10b_table_aa[CRD][cg];
      cg_struct.cg_name = $sformatf("K%0d_%0d" , cg_struct.octet[4:0] , cg_struct.octet[7:5]);
   end
   else begin 
      cg_struct.cg_type = INVALID;
      cg_struct.cg_name = "INVALID";      
   end

   `uvm_info("ETH_DECODER" , $sformatf("DATA VAL: %8b %0s" , cg_struct.octet , cg_struct.cg_name) , UVM_FULL)
   cg_struct.comma = comma;
   
   return cg_struct;
   
endfunction // decode

// 36.2.4.4 Running disparity rules
function void eth_decoder::crd_rx_rules
  (
   cg_t cg,
   ref crd_t crd
   );
   
   int ones_abcdei, ones_fghj;
   
   ones_abcdei = $countones(cg[0:5]);
   ones_fghj = $countones(cg[6:9]);
   
   //   `uvm_info("ETH_DECODER" , $sformatf("\n\nCRD_RX : %s  \nCG : 0b%10b, \nones_abcdei : %0d , \nones_fghj : %0d\n" , crd.name() , cg , ones_abcdei , ones_fghj) , UVM_FULL)
   
   if(ones_abcdei > 3 || (cg[0:5] == 6'b000_111))
     crd = POSITIVE;
   else if(ones_abcdei < 3 || (cg[0:5] == 6'b111_000))
     crd = NEGATIVE;

   if(ones_fghj > 2 || (cg[6:9] == 4'b00_11))
     crd = POSITIVE;
   else if(ones_fghj < 2 || (cg[6:9] == 4'b11_00))
     crd = NEGATIVE;
   
endfunction // crd_rx_rules

///////////////////////////////////////////
// Setter Mathods
///////////////////////////////////////////

function void eth_decoder::cg_set(cg_t cg, bit comma);

   cg_struct_q.push_back(decode_8b10b(cg, CRD_RX, comma));
   if(cg_struct_q.size() >= 3) begin
      if(cg_struct_q.size() == 4)
	cg_struct_q.delete(0);
      queue_full = 1;      
      cg_struct_current = cg_struct_q[0];
      cg_print();
   end
   else begin
      queue_full = 0;
   end
   crd_rx_rules(cg, CRD_RX);
   
endfunction // PUDI_set_comma

///////////////////////////////////////////
// Getter Mathods
///////////////////////////////////////////

function bit eth_decoder::cg_check_type(cg_type_t cg_type);
   return cg_struct_current.cg_type == cg_type;
endfunction // cg_check_type

function bit eth_decoder::cg_check_name(string cg_name, cg_struct_t cg_struct = cg_struct_current);
   return cg_struct.cg_name == cg_name;
endfunction // cg_check_name

function bit eth_decoder::cg_is_comma();
   return cg_struct_current.comma;
endfunction // cg_is_comma

function bit eth_decoder::SUDI_is_rx_even();
   return rx_even;
endfunction // SUDI_is_rx_even

function void eth_decoder::SUDI_set_parity(bit rx_even);
   this.rx_even = rx_even;
endfunction // SUDI_set_parity

function octet_t eth_decoder::cg_decode();
   cg_decode = cg_struct_current.octet;   
endfunction // cg_decode

function bit eth_decoder::decoder_ready();
   return queue_full;   
endfunction // decoder_ready

///////////////////////////////////////////////
// check_end functions implementation

function bit eth_decoder::os_check(string os_name , cg_struct_t cg_struct = cg_struct_current);
   return os_convert(os_name) == cg_struct.cg_name;   
endfunction // os_check

function string eth_decoder::os_convert(string os_name);
   case(os_name)
     "/S/": os_convert = "K27_7";
     "/T/": os_convert = "K29_7";
     "/R/": os_convert = "K23_7";
     default: `uvm_fatal("ETH_DECODER" , $sformatf("Ordered set %0s is not defined" , os_name))
   endcase // case (os_name)   
endfunction // os_convert
  
function bit eth_decoder::check_end(string cg_name_a[3]);
   int indx = 0;
   check_end = 1;

   //check_end_print();
   
   do begin
      if(!uvm_re_match("\/\/[A-Z]\/\/" , cg_name_a[indx])) begin
	 //`uvm_info("ETH_DECODER" , $sformatf("ORDERED SET: %0s" , cg_name_a[indx]) , UVM_FULL)
	 if(cg_name_a[indx] == "/D/")
	   check_end = (cg_struct_q[indx].cg_type == DATA);
	 else 
	   check_end = os_check(cg_name_a[indx] , cg_struct_q[indx]);
      end
      else
	check_end = cg_check_name(cg_name_a[indx] , cg_struct_q[indx]);
      `uvm_info("ETH_DECODER" , $sformatf("ORDERED SET: %0s CODE_GT: %0s" , cg_name_a[indx] , cg_struct_q[indx].cg_name) , UVM_FULL)
      indx++;
   end
   while(indx < 3 && check_end);
         
endfunction // check_end

function void eth_decoder::check_end_print();

   print_struct_t print_struct;   
   footer_struct_t footer_struct;

   print_struct.header_s = "CHECK END(THREE LAST CODE GROUP)";

   foreach(cg_struct_q[indx]) begin
      footer_struct.footer_name_s = $sformatf("CG(t+%0d)" , indx);
      footer_struct.footer_val_s = cg_struct_q[indx].cg_name;
      print_struct.footer_q.push_back(footer_struct);
   end

   msg_print.print(print_struct);
   
endfunction // check_end_print

   
function void eth_decoder::cg_print(cg_struct_t cg_struct = cg_struct_current);
   
   print_struct_t print_struct;   
   footer_struct_t footer_struct;

   print_struct.header_s = "RX CODE GROUP";
   
   footer_struct.footer_name_s = "CRD_RX";
   footer_struct.footer_val_s = CRD_RX.name();
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "bin_val";
   footer_struct.footer_val_s = $sformatf("10'b%6b_%4b" , cg_struct.cg[0:5] , cg_struct.cg[6:9]);
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "cg_type";
   footer_struct.footer_val_s = cg_struct.cg_type.name();   
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "cg_name";
   footer_struct.footer_val_s = cg_struct.cg_name;
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "is_comma";
   footer_struct.footer_val_s = $sformatf("%0d" , cg_struct.comma);
   print_struct.footer_q.push_back(footer_struct);

   msg_print.print(print_struct);   

endfunction // cg_print
