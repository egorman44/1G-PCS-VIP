// ***************************************************************
// Class : pcs_rx_comp
// Desc.  : 
// *************************************************************** 

class pcs_rx_comp extends uvm_component;

`include "decode_8b10b.sv"
   // ***************************************************************
   // UVM registration macros
   // ***************************************************************
   
   `uvm_component_utils_begin(pcs_rx_comp)
   `uvm_component_utils_end
   
   // ***************************************************************
   // Class properties
   // ***************************************************************

   // This bit is used to enable writing into analysis port. This bit
   // should be 1 if pcs_rx_comp is built in pcs_monitor and 0 if this
   // component is build in pcs_driver
   protected bit analysis_enable = 0;
   
   pcs_common_methods pcs_common_methods_h;
   
   virtual pcs_if vif;
   uvm_analysis_port #(pcs_seq_item) analysis_port;
   
   // queue with three items is used to store three 
   // consecutive code-groups for check_end() function.
   
   cg_struct_t cg_struct_q[$];

   // code group that is used for all calculations at
   // a current time slot.
   
   cg_struct_t cg_struct_current;

   // pma_receive_process variables
   protected cg_struct_t cg_struct_a[2:0];
   protected crd_t crd_rx;

   // pcs_rx_sync_sm state variables

   protected rx_sync_sm_st_t rx_sync_sm_st = LOSS_OF_SYNC_st;
   protected bit sync_status = 0;
   protected bit rx_even = 0;
   protected int good_cgs;

   // pcs_rx_rcv_sm state variables
   
   protected rx_receive_sm_st_t rx_receive_sm_st = LINK_FAILED_st;
   protected rudi_t rudi;
   protected bit [15:0] rx_config_reg;
   protected bit 	receiving;

   // events that is used to synchronize functionality for pcs_rx_sync_proc
   // and  pcs_rx_rcv_proc

   message_print msg_print_h;

   //////////////////
   // TODO: ANALYZE THIS SIGNALS
   // GMII interface

   bit 			EN_CDEN = 1'b1;

   xmit_t xmit = XMIT_DATA;
   
   // ***************************************************************
   // Class methods
   // ***************************************************************

   extern function new(string name = "pcs_rx_comp", uvm_component parent=null);
   extern virtual function void build_phase(uvm_phase phase);
   //extern virtual function void connect_phase(uvm_phase phase);
   extern virtual task          run_phase(uvm_phase phase);
   
   extern task pma_receive_process();
   
   extern function void pcs_rx_sync_sm();
   extern function void pcs_rx_rcv_sm();

   extern function void print_pcs_rx_sync_vars();
   //extern function void print_pcs_rx_rcv_vars();

   // This task allows to write sequence items into analysis port
   extern task write_an();

   // This function is used to enable analysys port wrintting
   extern function void set_analysis(bit analysis_enable);
   
   extern function void print_sm_state(string state_s);
   extern function void print_check_end();
   extern function void print_cg(ref cg_struct_t cg_struct = cg_struct_current);
   
   extern function bit is_cggood();   
   extern function bit check_comma(cg_t cg);
   extern function void os_set();

   extern function cg_struct_t decode_8b10b(cg_t cg , crd_t CRD, bit comma);
   extern function bit carrier_detect();  
endclass // pcs_rx_comp

function pcs_rx_comp::new(string name = "pcs_rx_comp", uvm_component parent=null);
   super.new(name, parent);   
endfunction: new

function void pcs_rx_comp::build_phase(uvm_phase phase);
   super.build_phase(phase);
   pcs_common_methods_h = pcs_common_methods::type_id::create("pcs_common_methods_h");
   msg_print_h = message_print::type_id::create("msg_print");
endfunction // build_phase

task pcs_rx_comp::run_phase(uvm_phase phase);
   fork
      pma_receive_process();
      begin
	 if(analysis_enable)
	   write_an();
      end
   join_none   
endtask // run_phase

function void pcs_rx_comp::set_analysis(bit analysis_enable);
   this.analysis_enable = analysis_enable;
endfunction // set_analysis

   
//-------------------------------------------------
// 36.3 Physical Medium Attachment (PMA) sublayer
//-------------------------------------------------

// 36.3.2.3 PMA receive function and 3.3.2.4 Code-group alignment process

task pcs_rx_comp::pma_receive_process();

   logic [0:9] ten_bits;
   logic [0:19] two_ten_bits;
   cg_t cg;
   
   int 		comma_position	= 0;
   int 		cg_counter	= 0;   
   bit 		is_comma	= 0;
   
   forever begin      
      vif.read(ten_bits);
      two_ten_bits = {two_ten_bits[10:19] , ten_bits};
      
      `uvm_info("PCS_RX_COMP" , $sformatf("Received 10-bit: 0b%10b " , ten_bits) , UVM_FULL)
      `uvm_info("PCS_RX_COMP" , $sformatf("Two 10-bit: 0b%10b_%10b " , two_ten_bits[0:9], two_ten_bits[10:19]) , UVM_FULL)

      is_comma = 1'b0;
      
      if(EN_CDEN == 1'b1) begin	
	 for(int i = 0; i < 10; ++i) begin
	    //`uvm_info("PCS_RX_COMP" , $sformatf("Comma try: %7b" , two_ten_bits[i+:7]) , UVM_FULL)
	    if(check_comma(two_ten_bits[i+:10])) begin
	       comma_position = i;
	       is_comma = 1'b1;
	       `uvm_info("PCS_RX_COMP" , $sformatf("Comma detected in pos %0d %7b" , comma_position , two_ten_bits[i+:7]) , UVM_FULL)
	       //break;
	    end
	 end
      end
      else begin
	 is_comma = check_comma(two_ten_bits[comma_position+:10]);
      end // else: !if(is_comma == FALSE)

      cg = two_ten_bits[comma_position+:10];
      cg_struct_a = {cg_struct_a[1:0],decode_8b10b(cg, crd_rx, is_comma)};
      cg_struct_current = cg_struct_a[2];
      pcs_common_methods_h.crd_rules(cg, crd_rx);
      
      // Enable sync process only when three code-groups were received
      if(cg_counter < 2)
	++cg_counter;
      else begin
	 os_set();
	 print_cg(cg_struct_a[2]);
	 pcs_rx_sync_sm();
	 pcs_rx_rcv_sm();
      end

   end   
endtask // pma_receive_process

//------------------------------------------------------------------------
// 36.2.5.2.6 Synchronization
//------------------------------------------------------------------------

function void pcs_rx_comp::pcs_rx_sync_sm();
   
   if(vif.mr_main_reset) 
     rx_sync_sm_st = LOSS_OF_SYNC_st;

   //----------------------------------------------
   // First case is used to calculate NEW state
   // based on OLD state
   //----------------------------------------------

   case(rx_sync_sm_st)
     
     LOSS_OF_SYNC_st: begin
	if(cg_struct_current.comma)
	  rx_sync_sm_st = COMMA_DETECT_1_st;
	else
	  rx_sync_sm_st = LOSS_OF_SYNC_st;	      
     end
     
     COMMA_DETECT_1_st: begin
	if(cg_struct_current.cg_type == DATA)
	  rx_sync_sm_st = ACQUIRE_SYNC_1_st;
	else
	  rx_sync_sm_st = LOSS_OF_SYNC_st;	      
     end
     
     ACQUIRE_SYNC_1_st: begin
	if(!rx_even && cg_struct_current.comma)
	  rx_sync_sm_st = COMMA_DETECT_2_st;
	else if(cg_struct_current.cg_type != INVALID && !cg_struct_current.comma)
	  rx_sync_sm_st = ACQUIRE_SYNC_1_st;
	else
	  rx_sync_sm_st = LOSS_OF_SYNC_st;	      
     end

     COMMA_DETECT_2_st: begin
	if(cg_struct_current.cg_type == DATA)
	  rx_sync_sm_st = ACQUIRE_SYNC_2_st;
	else
	  rx_sync_sm_st = LOSS_OF_SYNC_st;	      
     end

     ACQUIRE_SYNC_2_st: begin
	`uvm_info("PCS_RX_COMP" , $sformatf("is_comma = %0b , is_invalid = %0b" , cg_struct_current.cg_type == INVALID , cg_struct_current.comma) , UVM_FULL)
	
	if(!rx_even && cg_struct_current.comma)
	  rx_sync_sm_st = COMMA_DETECT_3_st;
	else if(!cg_struct_current.cg_type == INVALID && !cg_struct_current.comma)
	  rx_sync_sm_st = ACQUIRE_SYNC_2_st;
	else
	  rx_sync_sm_st = LOSS_OF_SYNC_st;
     end

     COMMA_DETECT_3_st: begin
	if(cg_struct_current.cg_type == DATA)
	  rx_sync_sm_st = SYNC_ACQUIRED_1_st;
	else
	  rx_sync_sm_st = LOSS_OF_SYNC_st;
     end
     
     SYNC_ACQUIRED_1_st: begin
	if(is_cggood())
	  rx_sync_sm_st = SYNC_ACQUIRED_1_st;
	else
	  rx_sync_sm_st = SYNC_ACQUIRED_2_st;
     end

     SYNC_ACQUIRED_2_st: begin
	if(is_cggood())
	  rx_sync_sm_st = SYNC_ACQUIRED_2A_st;
	else 
	  rx_sync_sm_st = SYNC_ACQUIRED_3_st;
     end

     SYNC_ACQUIRED_2A_st: begin
	if(is_cggood())
	  rx_sync_sm_st = (good_cgs == 3) ? SYNC_ACQUIRED_1_st : SYNC_ACQUIRED_2A_st;
	else
	  rx_sync_sm_st = SYNC_ACQUIRED_3_st;
     end

     SYNC_ACQUIRED_3_st: begin
	if(is_cggood())
	  rx_sync_sm_st = SYNC_ACQUIRED_3A_st;
	else 
	  rx_sync_sm_st = SYNC_ACQUIRED_4_st;
     end

     SYNC_ACQUIRED_3A_st: begin
	if(is_cggood())
	  rx_sync_sm_st = (good_cgs == 3) ? SYNC_ACQUIRED_2_st : SYNC_ACQUIRED_3A_st;
	else
	  rx_sync_sm_st = SYNC_ACQUIRED_4_st;
     end

     SYNC_ACQUIRED_4_st: begin
	if(is_cggood())
	  rx_sync_sm_st = SYNC_ACQUIRED_4A_st;
	else 
	  rx_sync_sm_st = LOSS_OF_SYNC_st;
     end

     SYNC_ACQUIRED_4A_st: begin
	if(is_cggood())
	  rx_sync_sm_st = (good_cgs == 3) ? SYNC_ACQUIRED_3_st : SYNC_ACQUIRED_4A_st;
	else
	  rx_sync_sm_st = LOSS_OF_SYNC_st;
     end

     default:
       `uvm_fatal("PCS_RX_COMP", $sformatf("The state %0s is INCALID for PCS_RX_SYNC sm" , rx_sync_sm_st))
     
   endcase // case (rx_sync_sm_st)

   print_sm_state({"RX SYNC STATE : " , rx_sync_sm_st.name()});
   
   //----------------------------------------------
   // Second case is used to execute actions in NEW state
   //----------------------------------------------
   
   case(rx_sync_sm_st)
     
     LOSS_OF_SYNC_st: begin
	sync_status = 0;	   
	rx_even = ~rx_even;
     end
     
     COMMA_DETECT_1_st: begin
	rx_even = 1'b1;
     end
     
     ACQUIRE_SYNC_1_st: begin
	rx_even = ~rx_even;
     end

     COMMA_DETECT_2_st: begin
	rx_even = 1'b1;
     end

     ACQUIRE_SYNC_2_st: begin
	rx_even = ~rx_even;
     end

     COMMA_DETECT_3_st: begin
	rx_even = 1'b1;
     end
     
     SYNC_ACQUIRED_1_st: begin
	sync_status = 1;
	rx_even = ~rx_even;
     end

     SYNC_ACQUIRED_2_st: begin
	rx_even = ~rx_even;
	good_cgs = 0;
     end

     SYNC_ACQUIRED_2A_st: begin
	rx_even = ~rx_even;
	++good_cgs;
     end

     SYNC_ACQUIRED_3_st: begin
	rx_even = ~rx_even;
	good_cgs = 0;
     end

     SYNC_ACQUIRED_3A_st: begin
	rx_even = ~rx_even;
	++good_cgs;
     end

     SYNC_ACQUIRED_4_st: begin
	rx_even = ~rx_even;
	good_cgs = 0;
     end

     SYNC_ACQUIRED_4A_st: begin
	rx_even = ~rx_even;
	++good_cgs;
     end
     
   endcase // case (rx_sync_sm_st)

   print_pcs_rx_sync_vars();
   
endfunction // pcs_rx_sync_sm

function bit pcs_rx_comp::is_cggood();
   is_cggood = !((cg_struct_current.comma && rx_even) || cg_struct_current.cg_type == INVALID);
endfunction // is_cggood

//--------------------------------------------------------
// 36.2.5.2.2 Receive
//--------------------------------------------------------

function void pcs_rx_comp::pcs_rx_rcv_sm();
   
   if(vif.mr_main_reset)
     rx_receive_sm_st = WAIT_FOR_K_st;
   else if(!sync_status)
     rx_receive_sm_st = LINK_FAILED_st;
   
   `uvm_info("PCS_RX_COMP" , $sformatf("SUDI event has occured"), UVM_FULL);

   //----------------------------------------------
   // First case is used to calculate NEW state
   // based on OLD state
   //----------------------------------------------

   case(rx_receive_sm_st)
     
     LINK_FAILED_st: begin
	if(xmit != XMIT_DATA)
	  rudi = RUDI_INVALID;
	receiving = 0;
	rx_receive_sm_st = WAIT_FOR_K_st;		 
     end
     
     WAIT_FOR_K_st: begin
	receiving = 0;	
 	if(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hBC && // cg_name("K28_5")
	   rx_even)
	   
	  rx_receive_sm_st = RX_K_st;
     end
     
     RX_K_st: begin
	receiving = 0;
	if(cg_struct_current.cg_type == DATA && 
	   (cg_struct_current.octet == 8'h35 ||  // cg_name("D21_1")
	    cg_struct_current.octet == 8'h42))  // cg_name("D2_2")	  
	   
	  rx_receive_sm_st = RX_CB_st;
	
	else if(cg_struct_current.cg_type != DATA && xmit != XMIT_DATA)
	  rx_receive_sm_st = RX_INVALID_st;
	else if((xmit != XMIT_DATA && 
		 (cg_struct_current.cg_type == DATA && 
		  cg_struct_current.octet != 8'h35 &&      //cg_name != ("D21_1")
		  cg_struct_current.octet != 8'h42))       //cg_name != ("D2_2")
		||
		(xmit == XMIT_DATA && 
		 (!(cg_struct_current.cg_type == DATA && 
		    (cg_struct_current.octet == 8'h35 ||  //cg_name != ("D21_1")
		     cg_struct_current.octet == 8'h42)))))//cg_name != ("D2_2")

	   
	  rx_receive_sm_st = IDLE_D_st;
	
     end // case: RX_K_st
     
     RX_CB_st: begin
	receiving = 0;
	if(cg_struct_current.cg_type == DATA)
	  rx_receive_sm_st = RX_CC_st;
	else
	  rx_receive_sm_st = RX_INVALID_st;	     
     end

     RX_CC_st: begin
	rx_config_reg[7:0] = cg_struct_current.octet;
	if(cg_struct_current.cg_type == DATA)
	  rx_receive_sm_st = RX_CD_st;
	else
	  rx_receive_sm_st = RX_INVALID_st;
     end

     RX_CD_st: begin
	rx_config_reg[15:8] = cg_struct_current.octet;
	rudi = RUDI_CONFIG;
	if(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hBC &&  // cg_name("K28_5")
	   rx_even)
	   
	  rx_receive_sm_st = RX_K_st;
	
	else if(!(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hBC) ||  // cg_name("K28_5")
		rx_even)
	   
	  rx_receive_sm_st = RX_INVALID_st;
     end

     IDLE_D_st: begin
	receiving = 0;
	rudi = RUDI_INVALID;
	if(xmit == XMIT_DATA && carrier_detect()) begin	  
	   rx_receive_sm_st = CARRIER_DETECT_st;
	end
	else if(xmit == XMIT_DATA && !carrier_detect() || 
		cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hBC) // cg_name("K28_5")
	   
	  rx_receive_sm_st = RX_K_st;	
	else
	  rx_receive_sm_st = RX_INVALID_st;
     end // case: IDLE_D_st
     
     CARRIER_DETECT_st: begin
        receiving = 1;
	if(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hFB) // os_name == "/S/"
          rx_receive_sm_st = START_OF_PACKET_st;
        else 
          rx_receive_sm_st = FALSE_CARRIER_st;
     end

     FALSE_CARRIER_st: begin
	if(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hBC && // cg_name("K28_5")
	   rx_even)
	   
	  rx_receive_sm_st = RX_K_st;
     end

     RX_INVALID_st: begin
	if(xmit == XMIT_CONFIG)
	  rudi = RUDI_INVALID;
	else if(xmit == XMIT_DATA)
	  receiving = 1;
	if(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hBC && // cg_name("K28_5")
	   rx_even)
	  rx_receive_sm_st = RX_K_st;
	else
	  if( !(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hBC) &&  // cg_name("K28_5")
	      rx_even)
	    rx_receive_sm_st = WAIT_FOR_K_st;
     end // case: RX_INVALID_st
     
     START_OF_PACKET_st: begin
	rx_receive_sm_st = RECEIVE_st;
     end

     // RECEIVE_st doesn't wait for a new SUDI message, so
     // here we call pcs_rx_rcv_sm() recursively.
     // This state also calls check_end function that checks
     // three consequtive code-groups
     
     RECEIVE_st: begin

	if(
	   // decoder.check_end('{"K28_5" , "/D/"  , "K28_5"})
	   (((cg_struct_a[2].cg_type == SPECIAL && cg_struct_a[2].octet == 8'hBD) && // cg_name == "K28_5"
	     (cg_struct_a[1].cg_type == DATA) &&                                     // cg_type == DATA
	     (cg_struct_a[0].cg_type == SPECIAL && cg_struct_a[0].octet == 8'hBD))   // cg_name == "K28_5"
	    ||
	    // decoder.check_end('{"K28_5" , "D21_5", "D0_0"})
	    ((cg_struct_a[2].cg_type == SPECIAL && cg_struct_a[2].octet == 8'hBD) && // cg_name == "K28_5"
	     (cg_struct_a[1].cg_type == DATA && cg_struct_a[1].octet == 8'hB5) &&    // cg_name == "D21_5"
	     (cg_struct_a[0].cg_type == DATA && cg_struct_a[0].octet == 8'h00))      // cg_name == "D0_0"
	    ||
	    // decoder.check_end('{"K28_5" , "D2_2" , "D0_0"})
	    ((cg_struct_a[2].cg_type == SPECIAL && cg_struct_a[2].octet == 8'hBD) && // cg_name == "K28_5"
	     (cg_struct_a[1].cg_type == DATA && cg_struct_a[1].octet == 8'h42) &&    // cg_name == "D2_2"
	     (cg_struct_a[0].cg_type == DATA && cg_struct_a[0].octet == 8'h00)))     // cg_name == "D0_0"
	   &&   
	   rx_even)
	   
	  rx_receive_sm_st = EARLY_END_st;

	//decoder.check_end('{"/T/" , "/R/" , "K28_5"})
	//else if((cg_struct_a[2].cg_type == SPECIAL && cg_struct_a[2].octet == 8'hFD) && // os_name == "/T/"
	//	(cg_struct_a[1].cg_type == SPECIAL && cg_struct_a[1].octet == 8'hF7) && // os_name == "/R/"
	//	(cg_struct_a[0].cg_type == SPECIAL && cg_struct_a[0].octet == 8'hBD) && // cg_name == "K28_5"
	//	rx_even)

	else if(cg_struct_a[2].cg_name == "K29_7" &&
		cg_struct_a[1].cg_name == "K23_7" &&
		cg_struct_a[0].cg_name == "K28_5" &&
		rx_even)
	  rx_receive_sm_st = TRI_RRI_st;
	
	//decoder.check_end('{"/T/" , "/R/" , "/R/"})
	else if((cg_struct_a[2].cg_type == SPECIAL && cg_struct_a[2].octet == 8'hFD) && // os_name == "/T/"
		(cg_struct_a[1].cg_type == SPECIAL && cg_struct_a[1].octet == 8'hF7) && // os_name == "/R/"
		(cg_struct_a[0].cg_type == SPECIAL && cg_struct_a[0].octet == 8'hF7))   // os_name == "/R/"
	  rx_receive_sm_st = TRR_EXTEND_st;

	//decoder.check_end('{"/R/" , "/R/" , "/R/"})
	else if((cg_struct_a[2].cg_type == SPECIAL && cg_struct_a[2].octet == 8'hF7) && // os_name == "/R/"
		(cg_struct_a[1].cg_type == SPECIAL && cg_struct_a[1].octet == 8'hF7) && // os_name == "/R/"
		(cg_struct_a[0].cg_type == SPECIAL && cg_struct_a[0].octet == 8'hF7))   // os_name == "/R/"
	  rx_receive_sm_st = EARLY_END_EXT_st;

	else if(cg_struct_current.cg_type == DATA)
	  rx_receive_sm_st = RX_DATA_st;
	else
	  rx_receive_sm_st = RX_DATA_ERROR_st;

     end // case: RECEIVE_st

     EARLY_END_st: begin
	
	if(cg_struct_current.cg_type == DATA && 
	   (cg_struct_current.octet == 8'h35 ||  //cg_name("D21_1")
	    cg_struct_current.octet == 8'h42))   //cg_name("D2_2")
	   
	  rx_receive_sm_st = RX_CB_st;

	else
	  rx_receive_sm_st = IDLE_D_st;	
     end
     
     TRI_RRI_st: begin
	receiving = 1;
	if(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hBC) begin // cg_name("K28_5")
	   rx_receive_sm_st = RX_K_st;
	end
     end
     
     TRR_EXTEND_st: begin
	rx_receive_sm_st = EPD2_CHECK_END_st;
     end
     
     EARLY_END_EXT_st: begin
	rx_receive_sm_st = EPD2_CHECK_END_st;
     end
     
     RX_DATA_st: begin
	rx_receive_sm_st = RECEIVE_st;
     end
     
     RX_DATA_ERROR_st: begin
	rx_receive_sm_st = RECEIVE_st;
     end

     PACKET_BURST_RPS_st: begin
	if(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hFB) begin // os_to_octet == "/S/"
	   rx_receive_sm_st = START_OF_PACKET_st;
	end
     end

     EXTEND_ERR_st: begin
	if(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hFB) begin // os_to_octet == "/S/"
	   rx_receive_sm_st = START_OF_PACKET_st;
	end
	else if(cg_struct_current.cg_type == SPECIAL && cg_struct_current.octet == 8'hBC  // cg_name("K28_5")
		&& rx_even)
	  rx_receive_sm_st = RX_K_st;
	else
	  rx_receive_sm_st = EPD2_CHECK_END_st;
     end	      
     
     EPD2_CHECK_END_st: begin
	if((cg_struct_a[2].cg_type == SPECIAL && cg_struct_a[2].octet == 8'hF7) && // os_name == "/R/"
	   (cg_struct_a[1].cg_type == SPECIAL && cg_struct_a[1].octet == 8'hF7) && // os_name == "/R/"
	   (cg_struct_a[0].cg_type == SPECIAL && cg_struct_a[0].octet == 8'hF7) && // os_name == "/R/"
	   rx_even)
	  rx_receive_sm_st = TRR_EXTEND_st;

	else if((cg_struct_a[2].cg_type == SPECIAL && cg_struct_a[2].octet == 8'hF7) && // os_name == "/R/"
		(cg_struct_a[1].cg_type == SPECIAL && cg_struct_a[1].octet == 8'hF7) && // os_name == "/R/"
		(cg_struct_a[0].cg_type == SPECIAL && cg_struct_a[0].octet == 8'hBD) && // cg_type == "K28_5"
		rx_even)
	  rx_receive_sm_st = TRI_RRI_st;

	else if((cg_struct_a[2].cg_type == SPECIAL && cg_struct_a[2].octet == 8'hF7) && // os_name == "/R/"
		(cg_struct_a[1].cg_type == SPECIAL && cg_struct_a[1].octet == 8'hF7) && // os_name == "/R/"
		(cg_struct_a[0].cg_type == SPECIAL && cg_struct_a[0].octet == 8'hFB) && // os_name == "/S/"
		rx_even)
	  rx_receive_sm_st = PACKET_BURST_RPS_st;

	else
	  rx_receive_sm_st = EXTEND_ERR_st;
	
     end // case: EPD2_CHECK_END_st
     
     default:
       `uvm_fatal(get_type_name(), $sformatf("The state %0s is INVALID for pcs_rx_rcv_sm" , rx_receive_sm_st))
     
   endcase // case (rx_receive_sm_st)

   print_sm_state({"RX RCV STATE : " , rx_receive_sm_st.name()});

   if(rx_receive_sm_st == RECEIVE_st || rx_receive_sm_st == EPD2_CHECK_END_st)
     print_check_end();
   
   //----------------------------------------------
   // Second case is used to execute actions in NEW state
   //----------------------------------------------
   
   case(rx_receive_sm_st)
           
     LINK_FAILED_st: begin
	if(xmit != XMIT_DATA)
	  rudi = RUDI_INVALID;
	receiving = 0;
     end
     
     WAIT_FOR_K_st: begin
	receiving = 0;	
     end
     
     RX_K_st: begin
	receiving = 0;	
     end // case: RX_K_st
     
     RX_CB_st: begin
	receiving = 0;
     end

     RX_CC_st: begin
	rx_config_reg[7:0] = cg_struct_current.octet;
     end

     RX_CD_st: begin
	rx_config_reg[15:8] = cg_struct_current.octet;
	rudi = RUDI_CONFIG;
     end

     IDLE_D_st: begin
	receiving = 0;
	rudi = RUDI_INVALID;
     end // case: IDLE_D_st
     
     CARRIER_DETECT_st: begin
        receiving = 1;
	pcs_rx_rcv_sm();
     end

     RX_INVALID_st: begin
	if(xmit == XMIT_CONFIG)
	  rudi = RUDI_INVALID;
	else if(xmit == XMIT_DATA)
	  receiving = 1;
     end // case: RX_INVALID_st     
     
     RECEIVE_st: begin
	pcs_rx_rcv_sm();
     end // case: RECEIVE_st
     
     TRI_RRI_st: begin
	receiving = 1;
     end
     
     EPD2_CHECK_END_st: begin
	pcs_rx_rcv_sm();
     end // case: EPD2_CHECK_END_st
     
   endcase // case (rx_receive_sm_st)
      
endfunction // pcs_rx_rcv_sm

task pcs_rx_comp::write_an();

   pcs_seq_item pcs_seq_item_h;
   
   forever begin
      @(rx_receive_sm_st);
      
      if(rx_receive_sm_st == START_OF_PACKET_st)
	pcs_seq_item_h = pcs_seq_item::type_id::create("pcs_seq_item", this);
      if(rx_receive_sm_st == RX_DATA_st)
	pcs_seq_item_h.rx_frame_q.push_back(cg_struct_current.octet);

      // Check that frame was received without errors
      if(pcs_seq_item_h != null &&					 
	 !pcs_seq_item_h.rx_err &&
	 (rx_receive_sm_st == RX_DATA_ERROR_st ||
	  rx_receive_sm_st == EARLY_END_EXT_st ||
	  rx_receive_sm_st == TRR_EXTEND_st ||
	  rx_receive_sm_st == EARLY_END_EXT_st))
	pcs_seq_item_h.rx_err = 1;
      
      // Write packet into AP
      if(pcs_seq_item_h != null &&
	 (rx_receive_sm_st == EARLY_END_EXT_st ||
	  rx_receive_sm_st == TRI_RRI_st ||
	  rx_receive_sm_st == TRR_EXTEND_st ||
	  rx_receive_sm_st == EARLY_END_EXT_st)) 
	begin
	   //`uvm_info("PCS_RX_COMP" , pcs_seq_item_h.convert2string() , UVM_LOW)      
	   analysis_port.write(pcs_seq_item_h);
	end      
      
   end // forever begin
   
endtask // write_an

function void pcs_rx_comp::print_sm_state(string state_s);

   print_struct_t print_struct;
   print_struct.header_s = state_s;   
   msg_print_h.print(print_struct);
   
endfunction // print_sm_state

// 36.2.4.6 Checking the validity of received code-groups
function cg_struct_t pcs_rx_comp::decode_8b10b(cg_t cg , crd_t CRD, bit comma);
   
   cg_struct_t cg_struct;
   
   cg_struct.cg = cg;

   `uvm_info("PCS_RX_COMP" , $sformatf("CRD: %0s CG: %10b" , CRD.name() , cg) , UVM_FULL)
   
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
   
   //`uvm_info("PCS_RX_COMP" , $sformatf("DATA VAL: %8b %0s" , cg_struct.octet , cg_struct.cg_name) , UVM_FULL)
   cg_struct.comma = comma;
   
   return cg_struct;
   
endfunction // decode

function bit pcs_rx_comp::check_comma(cg_t cg);
   case(cg[0:6])
     7'b0011111 : check_comma = 1;
     7'b1100000 : check_comma = 1;
     default: check_comma = 0;	
   endcase
endfunction // check_comma   

// 36.2.5.1.4 Functions carrier_detect
function bit pcs_rx_comp::carrier_detect();

   cg_t cg_K28_5_pos = 10'b001111_1010;
   cg_t cg_K28_5_neg = 10'b110000_0101;
   cg_t compare_vec_pos, compare_vec_neg;
   int diff_neg , diff_pos;
   
   compare_vec_neg = cg_struct_current.cg ^ cg_K28_5_neg;
   compare_vec_pos = cg_struct_current.cg ^ cg_K28_5_pos;

   diff_neg = $countones(compare_vec_neg);
   diff_pos = $countones(compare_vec_pos);

   `uvm_info("PCS_RX_COMP" , $sformatf("POSITIVE: compare = %10b , diff = %0d" , compare_vec_pos, diff_pos) , UVM_FULL)
   `uvm_info("PCS_RX_COMP" , $sformatf("NEGATIVE: compare = %10b , diff = %0d" , compare_vec_neg, diff_neg) , UVM_FULL)
   
   carrier_detect = 0;

   if(rx_even) begin
      if(diff_pos > 2 && diff_neg > 2)
	carrier_detect = 1;
      if(crd_rx && diff_pos >= 2 && diff_pos <= 9)
	carrier_detect = 1;
      if(~crd_rx && diff_neg >= 2 && diff_neg <= 9)
	carrier_detect = 1;
   end
   
endfunction // carrier_detect

function void pcs_rx_comp::print_cg(ref cg_struct_t cg_struct = cg_struct_current);
   print_struct_t print_struct;   
   footer_struct_t footer_struct;
   string cg_name = "";
   string os_name = "";
   
   print_struct.header_s = "RX CODE GROUP";
   
   //footer_struct.footer_name_s = "CRD_RX";
   //footer_struct.footer_val_s = CRD_RX.name();
   //print_struct.footer_q.push_back(footer_struct);

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
   case(cg_struct.cg_type)
     DATA:    cg_name = $sformatf("D%0d_%0d" , cg_struct.octet[4:0] , cg_struct.octet[7:5]);
     SPECIAL: cg_name = $sformatf("K%0d_%0d" , cg_struct.octet[4:0] , cg_struct.octet[7:5]);
     INVALID: cg_name = "INVALID";
   endcase // case (cg_struct.cg_type)
   footer_struct.footer_val_s = cg_name;
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "os_name";      
   footer_struct.footer_val_s = $sformatf("%0s" , cg_struct.os_name);      
   print_struct.footer_q.push_back(footer_struct);
   
   footer_struct.footer_name_s = "is_comma";
   footer_struct.footer_val_s = $sformatf("%0d" , cg_struct.comma);
   print_struct.footer_q.push_back(footer_struct);

   msg_print_h.print(print_struct);   

endfunction // print_cg

function void pcs_rx_comp::print_pcs_rx_sync_vars();
   print_struct_t print_struct;   
   footer_struct_t footer_struct;

   print_struct.header_s = "PCS SYNC VARS";

   footer_struct.footer_name_s = "sync_status";
   footer_struct.footer_val_s = $sformatf("%0b" , sync_status);
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "rx_even";
   footer_struct.footer_val_s = $sformatf("%0b" , rx_even);
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "good_cgs";
   footer_struct.footer_val_s = $sformatf("%0d" , good_cgs);
   print_struct.footer_q.push_back(footer_struct);

   msg_print_h.print(print_struct);
   
endfunction // print_pcs_rx_sync_vars

function void pcs_rx_comp::os_set();
   if(cg_struct_current.os_name == "") begin
      cg_struct_a[2].os_name = "INVALID";
      if(cg_struct_a[2].cg_type == SPECIAL) begin
	 case(cg_struct_a[2].octet)
	   8'hF7: cg_struct_a[2].os_name = "/R/";
	   8'hFB: cg_struct_a[2].os_name = "/S/";
	   8'hFD: cg_struct_a[2].os_name = "/T/";
	   8'hFE: cg_struct_a[2].os_name = "/V/";
	   8'hBC: begin
	      if(cg_struct_a[1].cg_type == SPECIAL) begin
		 case(cg_struct_a[1].octet)
		   8'hB5: begin
		      cg_struct_a[2].os_name = "/C1/";
		      cg_struct_a[1].os_name = "/C1/";
		   end
		   8'h42: begin
		      cg_struct_a[2].os_name = "/C2/";
		      cg_struct_a[1].os_name = "/C2/";
		   end
		 endcase // case (cg_struct_a[1].octet)
	      end // if (cg_struct_a[1].cg_type == SPECIAL)
	      else if(cg_struct_a[1].cg_type == DATA) begin
		 case(cg_struct_a[1].octet)	      
		   8'hC5: begin
		      cg_struct_a[2].os_name = "/I1/";
		      cg_struct_a[1].os_name = "/I1/";
		   end
		   8'h50: begin
		      cg_struct_a[2].os_name = "/I2/";
		      cg_struct_a[1].os_name = "/I2/";
		   end
		 endcase // case (cg_struct_a[1].octet)		 
	      end // if (cg_struct_a[1].cg_type == DATA)	      
	   end // case: 8'hBC	   
	 endcase // case (cg_struct_a[2].octet)
      end
      else if(cg_struct_a[2].cg_type == DATA)
	cg_struct_a[2].os_name = "/D/";
   end     
endfunction // os_set

function void pcs_rx_comp::print_check_end();
   print_struct_t print_struct;   
   footer_struct_t footer_struct;

   print_struct.header_s = "CHECK END";

   footer_struct.footer_name_s = "code_groups";
   footer_struct.footer_val_s = $sformatf("%0s - %0s - %0s" , cg_struct_a[2].cg_name , cg_struct_a[1].cg_name, cg_struct_a[0].cg_name);
   print_struct.footer_q.push_back(footer_struct);

   footer_struct.footer_name_s = "ordered_set";
   footer_struct.footer_val_s = $sformatf("%0s - %0s - %0s" , cg_struct_a[2].os_name , cg_struct_a[1].os_name, cg_struct_a[0].os_name);
   print_struct.footer_q.push_back(footer_struct);

   msg_print_h.print(print_struct);

endfunction // print_check_end

