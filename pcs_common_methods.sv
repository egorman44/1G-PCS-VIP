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

   // ***************************************************************
   // Constraints 
   // ***************************************************************
   
   // ***************************************************************
   // Class methods
   // ***************************************************************
   
   function new(string name="pcs_common_methods");
      super.new(name);
   endfunction // new

   // 36.2.4.4 Running disparity rules
   extern function void crd_rules(cg_t cg, ref crd_t crd);

   extern function bit os_to_octet(string os, ref octet_t octet);
   extern function bit cg_name_to_octet(string cg_name, ref octet_t octet);
   extern function void get_os(ref cg_struct_t cg_struct);
   
endclass // pcs_common_methods

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

function bit  pcs_common_methods::os_to_octet(string os, ref octet_t octet);
   bit os_match = 1;
   case(os)
     "/R/": octet = 8'hF7;
     "/S/": octet = 8'hFB;
     "/T/": octet = 8'hFD;
     "/V/": octet = 8'hFE;
     default: os_match = 0;
   endcase // case (os_name)
   return os_match;
endfunction // os_to_octet

function void pcs_common_methods::get_os(ref cg_struct_t cg_struct);
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
endfunction // get_os     
  
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
