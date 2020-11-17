// ***************************************************************
// Class : pcs_common_methods
// Desc.  : This class includes functions that could be used by multiple
// objects in the pcs_agent
// *************************************************************** 

class pcs_common_methods extends uvm_object;


   // ***************************************************************
   // UVM registration macros
   // ***************************************************************
   
   `uvm_object_utils_begin(pcs_common_methods)
   `uvm_object_utils_end
   
   // ***************************************************************
   // Class properties
   // ***************************************************************

   message_print msg_print_h;
   
   // ***************************************************************
   // Constraints 
   // ***************************************************************
   
   // ***************************************************************
   // Class methods
   // ***************************************************************

   extern function new(string name="pcs_common_methods");
   // 36.2.4.4 Running disparity rules
   extern function void crd_rules(cg_t cg, ref crd_t crd);

   extern function octet_t os_to_octet(os_t os);
   extern function bit cg_name_to_octet(string cg_name, ref octet_t octet);
   extern function void set_os(ref cg_struct_t cg_struct);
   extern function void set_cg_name(ref cg_struct_t cg_struct);
      
   extern function void print_header(string header);
   extern function void print_cg(string header, ref cg_struct_t cg_struct);
endclass // pcs_common_methods
   
function pcs_common_methods::new(string name="pcs_common_methods");
   super.new(name);
   msg_print_h = message_print::type_id::create("msg_print");
endfunction // new

function bit pcs_common_methods::cg_name_to_octet(string cg_name, ref octet_t octet);
   bit cg_match = 1;
   if(!uvm_re_match("[DK][0-9]{1}_[0-9]{1}", cg_name)) begin
      octet[7:5] = cg_name.substr(3,3).atoi();
      octet[4:0] = cg_name.substr(1,1).atoi();
   end
   else if(!uvm_re_match("[DK][0-9]{2}_[0-9]{1}", cg_name)) begin
      octet[7:5] = cg_name.substr(4,4).atoi();
      octet[4:0] = cg_name.substr(1,2).atoi();
   end
   else begin
      cg_match = 0;
   end
   return cg_match;
endfunction // cg_name_to_octet

function octet_t pcs_common_methods::os_to_octet(os_t os);
   octet_t octet;
   case(os)
     CARRIER_EXT_os	: octet = 8'hF7;
     SOP_os		: octet = 8'hFB;
     EOP_os		: octet = 8'hFD;
     ERR_PROP_os	: octet = 8'hFE;
   endcase // case (os_name)
   return octet;
endfunction // os_to_octet

function void pcs_common_methods::set_os(ref cg_struct_t cg_struct);
   if(cg_struct.cg_type == SPECIAL) begin
      case(cg_struct.octet)
	8'hF7: cg_struct.os_name = "/R/";
	8'hFB: cg_struct.os_name = "/S/";
	8'hFD: cg_struct.os_name = "/T/";
	8'hFE: cg_struct.os_name = "/V/";
      endcase // case (cg_struct.octet)
   end
   else if(cg_struct.cg_type == DATA)
     cg_struct.os_name = "/D/";
endfunction // set_os

function void pcs_common_methods::set_cg_name(ref cg_struct_t cg_struct);
   case(cg_struct.cg_type)
     SPECIAL: cg_struct.cg_name = $sformatf("K%0d_%0d" , cg_struct.octet[4:0] , cg_struct.octet[7:5]);
     DATA   : cg_struct.cg_name = $sformatf("D%0d_%0d" , cg_struct.octet[4:0] , cg_struct.octet[7:5]);
     default: cg_struct.cg_name = "INVALID";
   endcase // case (cg_struct.cg_type)
endfunction // set_cg_name

// 36.2.4.4 Running disparity rules
function void pcs_common_methods::crd_rules( cg_t cg, ref crd_t crd);
   
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

function void pcs_common_methods::print_header(string header);

   print_struct_t print_struct;
   print_struct.header_s = header;   
   msg_print_h.print(print_struct);
   
endfunction // print_header

function void pcs_common_methods::print_cg(string header, ref cg_struct_t cg_struct);
   print_struct_t print_struct;   
   footer_struct_t footer_struct;
   string cg_name = "";
   string os_name = "";
   
   print_struct.header_s = header;
   
   footer_struct.footer_name_s = "bin_val";
   footer_struct.footer_val_s = $sformatf("10'b%6b_%4b" , cg_struct.cg[0:5] , cg_struct.cg[6:9]);
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "octet_val";
   footer_struct.footer_val_s = $sformatf("8'h%2h", cg_struct.octet);
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "cg_type";
   footer_struct.footer_val_s = cg_struct.cg_type.name();   
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "cg_name";
   footer_struct.footer_val_s = cg_struct.cg_name;
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "os_name";      
   footer_struct.footer_val_s = $sformatf("%0s" , cg_struct.os_name);      
   print_struct.footer_q.push_back(footer_struct);
   
   footer_struct.footer_name_s = "is_comma";
   footer_struct.footer_val_s = $sformatf("%0d" , cg_struct.comma);
   print_struct.footer_q.push_back(footer_struct);

   msg_print_h.print(print_struct);   
   
endfunction // print_cg
