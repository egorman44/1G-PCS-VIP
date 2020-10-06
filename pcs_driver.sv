// ***************************************************************
// Class : pcs_driver
// Desc.  : 
// *************************************************************** 

class pcs_driver extends uvm_driver #(pcs_seq_item);


   // ***************************************************************
   // UVM registration macros
   // ***************************************************************
   
   `uvm_component_utils_begin(pcs_driver)
   `uvm_component_utils_end

   virtual pcs_if vif;
   crd_t tx_disparity;
   
   // ***************************************************************
   // Class properties
   // ***************************************************************

   // TODO: CHECK THIS CLASS VARIABLE
   
   bit [15:0] tx_config_reg;
   event      req_os_e, req_cg_e;
   bit 	      tx_even;
   bit 	      transmitting;
   octet_t    TXD;
   
   mailbox #(cg_t) cg_mbx;
   mailbox #(string) os_mbx;
   xmit_t_wrap::xmit_t xmit = xmit_t_wrap::CONFIG;
   
   // ***************************************************************
   // Class methods
   // ***************************************************************

   extern function new(string name="pcs_driver" , uvm_component parent=null);
   extern function void build_phase(uvm_phase phase);
   extern function void connect_phase(uvm_phase phase);
   extern task run_phase(uvm_phase phase);

   // Figure 36-5 PCS transmir order_set state diagram
   extern task pcs_tx_os_proc();
   extern function void pcs_tx_os_sm(ref tx_os_sm_st_t tx_os_sm_st, input bit terminate=0);

   // Figure 36-6 PCS transmit code_group state diagrame
   extern task pcs_tx_cg_proc();
   extern function void pcs_tx_cg_sm(ref tx_cg_sm_st_t tx_cg_sm_st);

   extern function cg_t encode(octet_t octet);
   extern task pma_tx_proc();
   
   extern function octet_t os_to_octet(string os);
   
endclass // pcs_driver

function pcs_driver::new(string name="pcs_driver" , uvm_component parent=null);
   super.new(name,parent);
   cg_mbx = new(1);
   os_mbx = new(1);
endfunction // new

function void pcs_driver::build_phase(uvm_phase phase);
   super.build_phase(phase);
endfunction // build_phase

function void pcs_driver::connect_phase(uvm_phase phase);
   super.connect_phase(phase);
endfunction // connect_phase			

task pcs_driver::run_phase(uvm_phase phase);

   fork
      pma_tx_proc();
      //pma_rx_proc();
   join
   
endtask // run_phase

//

task pcs_driver::pma_tx_proc();
   
   cg_t cg;
   
   forever begin
      vif.tx_code_group = '0;
      wait(!vif.mr_main_reset);
      forever begin
	 @(posedge vif.cb or posedge vif.mr_main_reset);
	 if(vif.mr_main_reset) begin // This condition is used to reset both TX state machines
	    -> req_cg_e;
	    while(os_mbx.num()) // If cg_mbx is not empty clear it
	      cg_mbx.get();
	    break;
	 end
	 else begin
	    -> req_cg_e;
	    cg_mbx.get(cg);
	    vif.tx_code_group = cg;
	 end	 
      end // forever begin
   end // forever begin
   
endtask // pma_tx_proc

task pcs_driver::pcs_tx_cg_proc();
   
   tx_cg_sm_st_t tx_cg_sm_st = GENERATE_CODE_GROUP_st;
   
   forever begin

      @req_cg_e;
      
      if(vif.mr_main_reset) begin
	 // Need to reset pcs_tx_os_sm too
	 -> req_os_e;
	 while(os_mbx.num()) // Don't forget to clear os_mbx
	   os_mbx.get();
	 tx_cg_sm_st = GENERATE_CODE_GROUP_st;
      end
      else
	pcs_tx_cg_sm(tx_cg_sm_st);
   end
endtask // pcs_tx_cg_proc


// This function could be used recursevely to resolve state transactions that don't
// need to wait req_cg_e event

function void pcs_driver::pcs_tx_cg_sm(ref tx_cg_sm_st_t tx_cg_sm_st);

   string tx_o_set;
   cg_t tx_code_group;
   
   
   case(tx_cg_sm_st)

     GENERATE_CODE_GROUP_st: begin

	// Pull next ordered_set from pcs_tx_os_proc
	-> req_os_e;
	os_mbx.get(tx_o_set);
	
	if(tx_o_set == "/V/" || tx_o_set == "/S/" || tx_o_set == "/T/" || tx_o_set == "/R/")
	  tx_cg_sm_st = SPECIAL_GO_st;
	else if(tx_o_set == "/D/")
	  tx_cg_sm_st = DATA_GO_st;
	else if(tx_o_set == "/I/")
	  tx_cg_sm_st = IDLE_DISPARITY_TEST_st;
	else if(tx_o_set == "/C/")
	  tx_cg_sm_st = CONFIGURATION_C1A_st;
	else
	  `uvm_fatal("PCS_DRIVER" , "There is no such ordered set")
	
	pcs_tx_cg_sm(tx_cg_sm_st);
	
     end // case: GENERATE_CODE_GROUP_st
     
     SPECIAL_GO_st: begin	    
	tx_code_group = encode(os_to_octet(tx_o_set));
	tx_even = !tx_even;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = GENERATE_CODE_GROUP_st;
     end

     DATA_GO_st: begin
	tx_code_group = encode(TXD);
	tx_even = !tx_even;
	cg_mbx.put(tx_code_group);	
	tx_cg_sm_st = GENERATE_CODE_GROUP_st;
     end

     IDLE_DISPARITY_TEST_st: begin
	if(tx_disparity == POSITIVE)
	  tx_cg_sm_st = IDLE_DISPARITY_WRONG_st;
	else 
	  tx_cg_sm_st = IDLE_DISPARITY_OK_st;

	pcs_tx_cg_sm(tx_cg_sm_st);
     end
     
     IDLE_DISPARITY_WRONG_st: begin
	tx_code_group = "K28_5";
	tx_even = 1;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = IDLE_I1B_st;
     end

     IDLE_I1B_st: begin
	tx_code_group = "D5_6";
	tx_even = 0;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = GENERATE_CODE_GROUP_st;
     end
     
     IDLE_DISPARITY_OK_st: begin
	tx_code_group = "K28_5";
	tx_even = 1;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = GENERATE_CODE_GROUP_st;
     end

     IDLE_I2B_st: begin
	tx_code_group = "D16_2";
	tx_even = 0;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = GENERATE_CODE_GROUP_st;
     end

     CONFIGURATION_C1A_st: begin
	tx_code_group = "K28_5";
	tx_even = 1;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = CONFIGURATION_C1B_st;
     end

     CONFIGURATION_C1B_st: begin
	tx_code_group = "K21_5";
	tx_even = 0;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = CONFIGURATION_C1C_st;
     end

     CONFIGURATION_C1C_st: begin
	tx_code_group = tx_config_reg[7:0];
	tx_even = 1;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = CONFIGURATION_C1D_st;
     end

     CONFIGURATION_C1D_st: begin
	tx_code_group = tx_config_reg[15:8];
	tx_even = 0;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = (tx_o_set == "/C/") ? CONFIGURATION_C2A_st : GENERATE_CODE_GROUP_st;
     end

     CONFIGURATION_C2A_st: begin
	tx_code_group = "K28_5";
	tx_even = 1;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = CONFIGURATION_C2B_st;
     end

     CONFIGURATION_C2B_st: begin
	tx_code_group = "D2_2";
	tx_even = 0;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = CONFIGURATION_C2C_st;
     end

     CONFIGURATION_C2C_st: begin
	tx_code_group = tx_config_reg[7:0];
	tx_even = 1;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = CONFIGURATION_C2D_st;
     end

     CONFIGURATION_C2D_st: begin
	tx_code_group = tx_config_reg[15:8];
	tx_even = 0;
	cg_mbx.put(tx_code_group);
	tx_cg_sm_st = GENERATE_CODE_GROUP_st;
     end

     default:
       `uvm_fatal($sformatf("There is no the state %0s for tx_cg_sm_st") , tx_cg_sm_st)
     
   endcase // case (tx_cg_sm_st)
   
endfunction // pcs_tx_cg_sm

task pcs_driver::pcs_tx_os_proc();

   tx_os_sm_st_t tx_os_sm_st = CONFIGURATION_st;

   forever begin
      
      @req_os_e;
      pcs_tx_os_sm(tx_os_sm_st, vif.mr_main_reset);
      
   end // forever begin
   
endtask // pcs_tx_os_sm

function void pcs_driver::pcs_tx_os_sm(ref tx_os_sm_st_t tx_os_sm_st, input bit terminate=0);

   // Static variables that is used not to lose values
   // between function invocation
   static int ipg, data_cntr, carrier_extend_delay;
   
   // Here we put previous value for xmit to detect the xmitCHANGE
   // and make a transition to TX_TEST_XMIT state
   xmit_t_wrap::xmit_t xmit_prev = xmit_t_wrap::CONFIG;

   // Each time we jump into CONFIGURATION_st
   // We need to make sure that driver <-> sequencer
   // hanshake is completed
   if(terminate) begin
      tx_os_sm_st = TX_TEST_XMIT_st;
      if (req != null) begin
	 req.status = UVM_TLM_INCOMPLETE_RESPONSE;
	 seq_item_port.item_done();
      end
   end

   else begin

      if(!tx_even && (xmit != xmit_prev)) begin
	 `uvm_warning("PCS_DRIVER", "xmitCHANGE cause reset for pcs_tx_os_sm")
	 tx_os_sm_st = TX_TEST_XMIT_st;
	 if(req != null) begin
	    req.status = UVM_TLM_INCOMPLETE_RESPONSE;
	    seq_item_port.item_done();
	 end
      end

      xmit_prev = xmit;
      
      case(tx_os_sm_st)	 
	
	TX_TEST_XMIT_st: begin
	   transmitting = 0;
	   //vif.COL = 0;
	   if(xmit == xmit_t_wrap::CONFIG)
	     tx_os_sm_st = CONFIGURATION_st;
	   // Cut iff the condition (xmit == xmit_t_wrap::DATA && (TX_EN || TX_ER)))
	   // because of it's indicate the error on GMII interface
	   else if(xmit == xmit_t_wrap::IDLE)
	     tx_os_sm_st = IDLE_st;
	   // Cut off the condition !TX_ER && !TX_ER
	   else if(xmit == xmit_t_wrap::DATA)
	     tx_os_sm_st = XMIT_DATA_st;
	   else
	     `uvm_fatal("PCS_DRIVER" , $sformatf("There is no %0s value for xmit variable"))

	   pcs_tx_os_sm(tx_os_sm_st);
	end

	CONFIGURATION_st: begin
	   os_mbx.put("/C/");
	   tx_os_sm_st = CONFIGURATION_st;			
	end
	
	IDLE_st: begin
	   os_mbx.put("/I/");
	   if(xmit == xmit_t_wrap::DATA)
	     tx_os_sm_st = XMIT_DATA_st;
	end

	XMIT_DATA_st: begin
	   os_mbx.put("/I/");
	   if(seq_item_port.has_do_available()) begin
	      seq_item_port.peek(req);
	      // Copy controll knobs
	      ipg = req.ipg;
	      carrier_extend_delay = req.carrier_extend_delay;
	      tx_os_sm_st = IPG_DELAY_st;	      
	   end	   
	   else
	     tx_os_sm_st = XMIT_DATA_st;		      
	end

	IPG_DELAY_st: begin
	   os_mbx.put("/I/");
	   if(ipg > 0) begin
	      --ipg;
	      tx_os_sm_st = IPG_DELAY_st;
	   end
	   else if(req.start_error)
	     tx_os_sm_st = START_ERROR_st;
	   else
	     tx_os_sm_st = TX_START_OF_PACKET_st;	     
	end

	TX_START_OF_PACKET_st: begin
	   seq_item_port.get_next_item();
	   transmitting = 1;
	   tx_os_sm_st = TX_PACKET_st;
	   data_cntr = 0;
	   os_mbx.put("/S/");
	end
	
	TX_PACKET_st: begin
	   if(data_cntr != req.frame_size) begin
	      tx_os_sm_st = TX_DATA_st;
	   end	   
	   else if(req.stop_error)
	     tx_os_sm_st = END_OF_PACKET_EXT_st;
	   else
	     tx_os_sm_st = END_OF_PACKET_NOEXT_st;
	   
	   pcs_tx_os_sm(tx_os_sm_st);
	end

	TX_DATA_st: begin
	   tx_os_sm_st = TX_PACKET_st;
	   TXD = req.frame[data_cntr];
	   ++data_cntr;
	   os_mbx.put("/D/");	   
	end

	END_OF_PACKET_NOEXT_st: begin
	   if(!tx_even)
	     transmitting = 0;
	   tx_os_sm_st = EPD2_NOEXT_st;
	   seq_item_port.item_done();
	   os_mbx.put("/T/");
	end

	EPD2_NOEXT_st: begin
	   transmitting = 0;
	   if(!tx_even)
	     tx_os_sm_st = XMIT_DATA_st;
	   else
	     tx_os_sm_st = EPD3_st;
	   
	   os_mbx.put("/R/");
	end

	EPD3_st: begin
	   tx_os_sm_st = XMIT_DATA_st;
	   os_mbx.put("/R/");
	end

	END_OF_PACKET_EXT_st: begin
	   seq_item_port.item_done();
 	   if(carrier_extend_delay)
	     tx_os_sm_st = CARRIER_EXTEND_st;
	   else
	     tx_os_sm_st = EXTEND_BY_1_st;
	   os_mbx.put("/T/"); // VOID() here 
	end

	CARRIER_EXTEND_st: begin

	   if(carrier_extend_delay > 0) begin
	      --carrier_extend_delay;
	      tx_os_sm_st = CARRIER_EXTEND_st;
	   end
	   else if(seq_item_port.has_do_available()) begin
	      seq_item_port.peek(req);
	      // Copy controll knobs
	      ipg = req.ipg;
	      carrier_extend_delay = req.carrier_extend_delay;
	      tx_os_sm_st = (req.start_error) ? START_ERROR_st : TX_START_OF_PACKET_st;
	   end
	   else
	     tx_os_sm_st = EXTEND_BY_1_st;
	      
	      os_mbx.put("/R/"); // VOID() here
	   end // case: CARRIER_EXTEND_st
	   
	   EXTEND_BY_1_st: begin
	      if(!tx_even)
		transmitting = 0;
	      //COL = 0;
	      tx_os_sm_st = EPD2_NOEXT_st;
	      os_mbx.put("/R/");
	   end

	START_ERROR_st: begin
	   seq_item_port.get_next_item();
	   transmitting = 1;
	   //COL = receiving;
	   tx_os_sm_st = TX_DATA_ERROR_st;
	   os_mbx.put("/S/");
	end

	TX_DATA_ERROR_st: begin
	   //COL = receiving;
	   tx_os_sm_st = TX_PACKET_st;
	   os_mbx.put("/V/");
	end

	default:
	  `uvm_fatal("PCS_DRIVER" , $sformatf("There is no %0s state for pcs_tx_os_sm",tx_os_sm_st))
	
      endcase // case (tx_test_xmit_st)

   end // else: !if(teminate)
   
endfunction // pcs_tx_os_proc

function cg_t pcs_driver::encode(octet_t octet);
   `uvm_fatal("PCS_DRIVER" , "No implementation")
endfunction // encode

function octet_t pcs_driver::os_to_octet(string os);
   case(os)
     "/R/": os_to_octet = 8'hF7;
     "/S/": os_to_octet = 8'hFB;
     "/T/": os_to_octet = 8'hFD;
     "/V/": os_to_octet = 8'hFE;
     default: `uvm_fatal("ETH_DECODER" , $sformatf("Ordered set %0s is not defined" , os))
   endcase // case (os_name)   
endfunction // os_to_octet


