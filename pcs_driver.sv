// ***************************************************************
// Class : pcs_driver
// Desc.  : 
// *************************************************************** 

class pcs_driver extends uvm_driver #(pcs_seq_item);

`include "decode_8b10b.sv"

   // ***************************************************************
   // UVM registration macros
   // ***************************************************************
   
   `uvm_component_utils_begin(pcs_driver)
   `uvm_component_utils_end
   
   // ***************************************************************
   // Class properties
   // ***************************************************************

   pcs_rx_comp pcs_rx_comp_h;
   
   virtual pcs_if vif;
   
   // TODO: CHECK THIS CLASS VARIABLE
   
   bit [15:0] tx_config_reg;
   crd_t      crd_tx = NEGATIVE;   
   
   // Here we put previous value for xmit to detect the xmitCHANGE
   // and make a transition to TX_TEST_XMIT state
   xmit_t xmit_prev = XMIT_CONFIG;
   xmit_t xmit = XMIT_CONFIG;
   bit 	      xmitCHANGE;

   // Sync hook to use in SVunit, shows that cg and os was calculated
   
   pcs_common_methods pcs_common_methods_h;

   // pcs_tx_cg_sm state variables

   tx_cg_sm_st_t tx_cg_sm_st;
   cg_struct_t cg_tx_struct;
   cg_t tx_code_group;
   bit 	      tx_even;   
   
   // pcs_tx_os_sm state variables
   
   tx_os_sm_st_t tx_os_sm_st = TX_TEST_XMIT_st;
   os_t tx_o_set;
   octet_t tx_octet;
   bit 	      transmitting = 0;
   int 	      ipg;
   int 	      byte_cntr;
   
   // ***************************************************************
   // Class methods
   // ***************************************************************

   extern function new(string name="pcs_driver" , uvm_component parent=null);
   extern function void build_phase(uvm_phase phase);
   extern function void connect_phase(uvm_phase phase);
   extern task run_phase(uvm_phase phase);

   // Figure 36-5 PCS transmir order_set state diagram
   extern virtual task pcs_tx_os_sm();
   extern virtual function void mid_pcs_tx_os_sm();
   extern virtual function void end_pcs_tx_os_sm();
   
   // Figure 36-6 PCS transmit code_group state diagrame
   extern task pcs_tx_cg_sm();
   extern virtual function void mid_pcs_tx_cg_sm();
   extern virtual function void end_pcs_tx_cg_sm();

   extern virtual task pma_tx_proc();
   extern virtual function void tx_sm_completion();
   extern function cg_struct_t encode_8b10b(octet_t octet, cg_type_t cg_type);


endclass // pcs_driver

function pcs_driver::new(string name="pcs_driver" , uvm_component parent=null);
   super.new(name,parent);
   pcs_rx_comp_h = pcs_rx_comp::type_id::create("pcs_rx_comp_h", this);
   `uvm_info("PCS_DRIVER", "pcs_rx_comp_h has created", UVM_FULL)
endfunction // new

function void pcs_driver::build_phase(uvm_phase phase);
   super.build_phase(phase);
   pcs_common_methods_h = pcs_common_methods::type_id::create("pcs_common_methods_h", this);
   //pcs_rx_comp_h = pcs_rx_comp::type_id::create("pcs_rx_comp_h", this);
endfunction // build_phase

function void pcs_driver::connect_phase(uvm_phase phase);
   super.connect_phase(phase);
   pcs_rx_comp_h.vif = vif;
endfunction // connect_phase			

task pcs_driver::run_phase(uvm_phase phase);

   fork
      pma_tx_proc();
   join
   
endtask // run_phase

//////////////////////////////////////////////////////
// PMA TX PROCESS
//////////////////////////////////////////////////////

task pcs_driver::pma_tx_proc();
   
   cg_t cg;
   
   forever begin
      pcs_tx_cg_sm();
      pcs_common_methods_h.print_cg("TX CODE GROUP",cg_tx_struct);
      pcs_common_methods_h.print_header({"TX CRD : ", crd_tx.name});
      tx_sm_completion();
      vif.write(cg_tx_struct.cg);
   end // forever begin
   
endtask // pma_tx_proc


// This function could be used recursevely to resolve state transactions that don't
// need to wait req_cg_e event

task pcs_driver::pcs_tx_cg_sm();
   
   if(vif.mr_main_reset) begin
      pcs_tx_os_sm();
      tx_cg_sm_st = GENERATE_CODE_GROUP_st;
   end
   else begin
      
      case(tx_cg_sm_st)

	GENERATE_CODE_GROUP_st: begin	   
	   // Call pcs_tx_os_sm() to get next os
	   pcs_tx_os_sm();
	   
	   if(tx_o_set == ERR_PROP_os || tx_o_set == SOP_os || tx_o_set == EOP_os || tx_o_set == CARRIER_EXT_os)
	     tx_cg_sm_st = SPECIAL_GO_st;
	   else if(tx_o_set == DATA_os)
	     tx_cg_sm_st = DATA_GO_st;
	   else if(tx_o_set == IDLE_os)
	     tx_cg_sm_st = IDLE_DISPARITY_TEST_st;
	   else if(tx_o_set == CONFIG_os)
	     tx_cg_sm_st = CONFIGURATION_C1A_st;	
	end // case: GENERATE_CODE_GROUP_st
	
	SPECIAL_GO_st: begin
	   tx_cg_sm_st = GENERATE_CODE_GROUP_st;
	end

	DATA_GO_st: begin
	   tx_cg_sm_st = GENERATE_CODE_GROUP_st;
	end

	IDLE_DISPARITY_TEST_st: begin
	   if(crd_tx == POSITIVE)
	     tx_cg_sm_st = IDLE_DISPARITY_WRONG_st;
	   else 
	     tx_cg_sm_st = IDLE_DISPARITY_OK_st;
	end
	
	IDLE_DISPARITY_WRONG_st: begin	  
	   tx_cg_sm_st = IDLE_I1B_st;
	end

	IDLE_I1B_st: begin	   
	   tx_cg_sm_st = GENERATE_CODE_GROUP_st;
	end
	
	IDLE_DISPARITY_OK_st: begin
	   tx_cg_sm_st = IDLE_I2B_st;
	end

	IDLE_I2B_st: begin
	   tx_cg_sm_st = GENERATE_CODE_GROUP_st;
	end

	CONFIGURATION_C1A_st: begin
	   tx_cg_sm_st = CONFIGURATION_C1B_st;
	end

	CONFIGURATION_C1B_st: begin
	   tx_cg_sm_st = CONFIGURATION_C1C_st;
	end

	CONFIGURATION_C1C_st: begin
	   tx_cg_sm_st = CONFIGURATION_C1D_st;
	end

	CONFIGURATION_C1D_st: begin
	   tx_cg_sm_st = (tx_o_set == CONFIG_os) ? CONFIGURATION_C2A_st : GENERATE_CODE_GROUP_st;
	end

	CONFIGURATION_C2A_st: begin
	   tx_cg_sm_st = CONFIGURATION_C2B_st;
	end

	CONFIGURATION_C2B_st: begin
	   tx_cg_sm_st = CONFIGURATION_C2C_st;
	end

	CONFIGURATION_C2C_st: begin
	   tx_cg_sm_st = CONFIGURATION_C2D_st;
	end

	CONFIGURATION_C2D_st: begin
	   tx_cg_sm_st = GENERATE_CODE_GROUP_st;
	end

	default:
	  `uvm_fatal("PCS_DRIVER", $sformatf("There is no the state %0s for tx_cg_sm_st()", tx_cg_sm_st.name()))
	
      endcase // case (tx_cg_sm_st)
   end // else: !if(vif.mr_main_reset)

   mid_pcs_tx_cg_sm();
   //----------------------------------------------
   // Second case is used to execute actions in NEW state
   //----------------------------------------------
   
   case(tx_cg_sm_st)

     IDLE_DISPARITY_TEST_st: begin
	pcs_tx_cg_sm();
	return;
     end
     
     GENERATE_CODE_GROUP_st: begin
	pcs_tx_cg_sm();
	return;
     end
     
     SPECIAL_GO_st: begin
	cg_tx_struct = encode_8b10b(pcs_common_methods_h.os_to_octet(tx_o_set), SPECIAL);
	tx_even = !tx_even;
     end

     DATA_GO_st: begin
	cg_tx_struct = encode_8b10b(tx_octet, DATA);
	tx_even = !tx_even;
     end

     IDLE_DISPARITY_WRONG_st: begin
	cg_tx_struct = encode_8b10b(8'hBC, SPECIAL);
	tx_even = 1;
     end

     IDLE_I1B_st: begin
	cg_tx_struct = encode_8b10b(8'hC5, DATA); // "D5_6"
	tx_even = 0;
     end

     IDLE_DISPARITY_OK_st: begin
	cg_tx_struct = encode_8b10b(8'hBC, SPECIAL); // "K28_5"
	tx_even = 1;
     end

     IDLE_I2B_st: begin
	cg_tx_struct = encode_8b10b(8'h50, DATA); // "D16_2"
	tx_even = 0;
     end

     CONFIGURATION_C1A_st: begin
	cg_tx_struct = encode_8b10b(8'hBC, SPECIAL); // "K28_5"
	tx_even = 1;
     end

     CONFIGURATION_C1B_st: begin
	cg_tx_struct = encode_8b10b(8'hB5, DATA); // "D21_5"
	tx_even = 0;
     end

     CONFIGURATION_C1C_st: begin
	cg_tx_struct = encode_8b10b(tx_config_reg[7:0], DATA);
	tx_even = 1;
     end

     CONFIGURATION_C1D_st: begin
	cg_tx_struct = encode_8b10b(tx_config_reg[15:8], DATA);
	tx_even = 0;
     end

     CONFIGURATION_C2A_st: begin
	cg_tx_struct = encode_8b10b(8'hBC, SPECIAL); // "K28_5"
	tx_even = 1;
     end

     CONFIGURATION_C2B_st: begin
	cg_tx_struct = encode_8b10b(8'h42, DATA); // "D2_2"
	tx_even = 0;
     end

     CONFIGURATION_C2C_st: begin
	cg_tx_struct = encode_8b10b(tx_config_reg[7:0], DATA);
	tx_even = 0;
     end

     CONFIGURATION_C2D_st: begin
	cg_tx_struct = encode_8b10b(tx_config_reg[15:8], DATA);
	tx_even = 0;
     end
     
   endcase // case (tx_cg_sm_st)

   end_pcs_tx_cg_sm();
   
endtask // pcs_tx_cg_sm

task pcs_driver::pcs_tx_os_sm();
      
   /////////////////////////
   // SM reset conditions
   /////////////////////////
   
   // We need to make sure that driver <-> sequencer
   // hanshake is completed if reset occurs
   if(vif.mr_main_reset) begin
      tx_os_sm_st = TX_TEST_XMIT_st;
      if (req != null) begin
   	 req.status = UVM_TLM_INCOMPLETE_RESPONSE; // mark seq_item as incompleted to proccess it on sequence level
   	 seq_item_port.item_done(req);
   	 req = null;
      end
   end
   else if(xmitCHANGE) begin
      pcs_common_methods_h.print_header({"XMIT(CHANGED): " , xmit.name()});
      xmitCHANGE = 0;
      tx_os_sm_st = TX_TEST_XMIT_st;
      if(req != null) begin
   	 req.status = UVM_TLM_INCOMPLETE_RESPONSE;
   	 seq_item_port.item_done(req);
   	 req = null;
      end
   end   
   else begin
      
      case(tx_os_sm_st)	 
	
	TX_TEST_XMIT_st: begin
	   if(xmit == XMIT_CONFIG)
	     tx_os_sm_st = CONFIGURATION_st;
	   else if(xmit == XMIT_IDLE)
	     tx_os_sm_st = IDLE_st;
	   else
	     tx_os_sm_st = XMIT_DATA_st;
	end
	
	CONFIGURATION_st: begin
	   tx_os_sm_st = CONFIGURATION_st;			
	end
	
	IDLE_st: begin
	   if(xmit == XMIT_DATA)
	     tx_os_sm_st = XMIT_DATA_st;
	end

	XMIT_DATA_st: begin
	   tx_os_sm_st = XMIT_DATA_st;
	   if(req != null)
	     `uvm_info("PCS_DRIVER" , $sformatf("byte_cntr = %0d \n ipg = %0d" , byte_cntr, req.ipg), UVM_FULL)
	   if(req != null && byte_cntr >= req.ipg)  // Will it work if req == null ?!
	     tx_os_sm_st = TX_START_OF_PACKET_st;
	end

	TX_START_OF_PACKET_st: begin
	   tx_os_sm_st = (req.start_err) ? TX_DATA_ERROR_st : TX_PACKET_st;
	end
	
	TX_DATA_ERROR_st: begin
	   tx_os_sm_st = TX_PACKET_st;
	end	
	
	TX_PACKET_st: begin
	   `uvm_info("PCS_DRIVER" , $sformatf("byte_cntr = %0d \n ipg = %0d" , byte_cntr, req.ipg), UVM_FULL)
	   if(byte_cntr == req.frame_size)
	     tx_os_sm_st = (req.carrier_extend) ? END_OF_PACKET_EXT_st : END_OF_PACKET_NOEXT_st;
	   else
	     tx_os_sm_st = TX_DATA_st;
	end

	TX_DATA_st: begin
	   tx_os_sm_st = TX_PACKET_st;
	end

	END_OF_PACKET_NOEXT_st: begin
	   tx_os_sm_st = EPD2_NOEXT_st;
	end

	EPD2_NOEXT_st: begin
	   if(!tx_even)
	     tx_os_sm_st = KILL1_REQ_st;
	   else
	     tx_os_sm_st = EPD3_st;
	end

	EPD3_st: begin
	   tx_os_sm_st = KILL1_REQ_st;
	end

	END_OF_PACKET_EXT_st: begin
 	   if(req.carrier_extend_duration == 1)
	     tx_os_sm_st = EXTEND_BY_1_st;
	   else
	     tx_os_sm_st = CARRIER_EXTEND_st;
	end
	
	CARRIER_EXTEND_st: begin
	   // This condition is used to implement burst transaction
	   // if the next item is NOT available in sequncer FIFO when
	   // next_burst = 1 we need to report an error and proceed in 
	   // non burst mode
	   if(byte_cntr == req.carrier_extend_duration) begin
	     if(req.next_burst) begin
		if(seq_item_port.has_do_available())
		  tx_os_sm_st = KILL2_REQ_st;
		else begin
		   `uvm_error("PCS_DRIVER" , "There is no sequence item for packet in burst mode")
		   tx_os_sm_st = EXTEND_BY_1_st;
		end		   
	     end	      
	     else
	       tx_os_sm_st = EXTEND_BY_1_st;
	   end // if (byte_cntr == req.carrier_extend_duration)
	   else
	     tx_os_sm_st = CARRIER_EXTEND_st;
	   
	end // case: CARRIER_EXTEND_st
		
	EXTEND_BY_1_st: begin
	   tx_os_sm_st = EPD2_NOEXT_st;
	end

	KILL1_REQ_st: begin
	   tx_os_sm_st = XMIT_DATA_st;
	end
	
	KILL2_REQ_st: begin
	   tx_os_sm_st = TX_START_OF_PACKET_st;
	end
      endcase // case (tx_os_sm_st)
      
   end // else: !if(xmitCHANGE)
   
   mid_pcs_tx_os_sm();
   
   //----------------------------------------------
   // Second case is used to execute actions in NEW state
   //----------------------------------------------
   
   case(tx_os_sm_st)
     
     TX_TEST_XMIT_st: begin
	transmitting = 0;
	byte_cntr = 0;
	if(vif.mr_main_reset == 0) begin
	   pcs_tx_os_sm();
	   return;
	end
     end

     CONFIGURATION_st: begin
	tx_o_set = CONFIG_os;
     end
     
     IDLE_st: begin
	tx_o_set = IDLE_os;
     end

     XMIT_DATA_st: begin
	tx_o_set = IDLE_os;
	++byte_cntr;
	if(req == null && seq_item_port.has_do_available()) begin
	   `uvm_info("DRIVER_UT" , "Just took the req " , UVM_FULL)
	   seq_item_port.peek(req); // Don't retrieve item from sequencer FIFO
	end
     end

     TX_START_OF_PACKET_st: begin
	tx_o_set = SOP_os;
	if(req == null)
	  seq_item_port.get_next_item(req); // Driver-Sequencer handshake
	transmitting = 1;
	byte_cntr = 0;
     end

     TX_DATA_ERROR_st: begin
	tx_o_set = ERR_PROP_os;
     end

     TX_PACKET_st: begin
	pcs_tx_os_sm();
	return;
     end

     TX_DATA_st: begin
	tx_o_set = DATA_os;
	tx_octet = req.frame_a[byte_cntr];
	if(req.err) begin
	   if(byte_cntr >= req.err_position && req.err_duration) begin
	      --req.err_duration;
	      tx_o_set = ERR_PROP_os;
	   end
	end
	++byte_cntr;
     end

     END_OF_PACKET_NOEXT_st: begin
	tx_o_set = EOP_os;
	if(!tx_even)
	  transmitting = 0;
     end
     
     EPD2_NOEXT_st: begin
	tx_o_set = CARRIER_EXT_os;
	transmitting = 0;
     end

     EPD3_st: begin
	tx_o_set = CARRIER_EXT_os;
     end

     END_OF_PACKET_EXT_st: begin
	tx_o_set = EOP_os;
	byte_cntr = 0;
     end

     CARRIER_EXTEND_st: begin
	tx_o_set = CARRIER_EXT_os;
	if(req.carrier_extend_err) begin
	   if(byte_cntr >= req.carrier_extend_err_position && req.carrier_extend_err_duration) begin
	      --req.carrier_extend_err_duration;
	      tx_o_set = ERR_PROP_os;
	   end
	end
	++byte_cntr;
     end // case: CARRIER_EXTEND_st
     
     EXTEND_BY_1_st: begin
	tx_o_set = CARRIER_EXT_os;
	if(!tx_even)
	  transmitting = 0;
     end

     KILL1_REQ_st: begin
	req.status = UVM_TLM_OK_RESPONSE;
	seq_item_port.item_done(req);
	req = null;	
	pcs_tx_os_sm();
	return;
     end

     KILL2_REQ_st: begin
	req.status = UVM_TLM_OK_RESPONSE;
	seq_item_port.item_done(req);
	req = null;
	pcs_tx_os_sm();
	return;
     end
     
   endcase // case (tx_test_xmit_st)

   end_pcs_tx_os_sm();
   
endtask // pcs_tx_os_sm

function cg_struct_t pcs_driver::encode_8b10b(octet_t octet, cg_type_t cg_type);

   cg_struct_t cg_struct;

   cg_struct.octet = octet;
   cg_struct.cg_type = cg_type;

   if(encode_8b10b_table_aa[cg_type][crd_tx].exists(octet))
     cg_struct.cg = encode_8b10b_table_aa[cg_type][crd_tx][octet];
   else begin
      `uvm_fatal("PCS_DRIVER" , $sformatf("The item(octet : 0x%2h , cg_type : %0s) was not found in encode_8b10b_table_aa", octet, cg_type))
   end
   
   pcs_common_methods_h.set_cg_name(cg_struct);   
   pcs_common_methods_h.crd_rules(cg_struct.cg, crd_tx);
   
   return cg_struct;
   
endfunction // encode_8b10b

function void pcs_driver::tx_sm_completion();
endfunction // tx_sm_completion

function void pcs_driver::mid_pcs_tx_cg_sm();
   pcs_common_methods_h.print_header({"TX CODE-GROUP SM STATE : " , tx_cg_sm_st.name()});
endfunction // mid_pcs_tx_cg_sm

function void pcs_driver::end_pcs_tx_cg_sm();
endfunction // end_pcs_tx_cg_sm

function void pcs_driver::mid_pcs_tx_os_sm();
   xmitCHANGE <= (xmitCHANGE == 0 && xmit_prev != xmit);
   xmit_prev = xmit;
   pcs_common_methods_h.print_header({"TX ORDERED-SET SM STATE : " , tx_os_sm_st.name()});
endfunction // mid_pcs_tx_os_sm

function void pcs_driver::end_pcs_tx_os_sm();
endfunction // end_pcs_tx_os_sm


