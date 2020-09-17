
`ifndef _ETH_COMMON_METHODS_
 `define _ETH_COMMON_METHODS_

class eth_common_methods extends uvm_object;
   
   virtual eth_if vif;
   bit sync_status;

   eth_decoder decoder;
   message_print msg_print;
   event   SUDI_e, PUDI_e;

   eth_seq_item eth_seq_item_h;
   uvm_analysis_port #(eth_seq_item) analysis_port;
   
   //////////////////
   // TODO: ANALYZE THIS SIGNALS
   // GMII interface

   bit 	   EN_CDEN = 1'b1;
   
   logic   RX_ER;
   logic   RX_DV;
   logic [7:0] RXD;
   
   logic [15:0] rx_config_reg;
   bit 		receiving;    // Was inside pcs_receive_process()

   xmit_t_wrap::xmit_t xmit = xmit_t_wrap::DATA;
   //////////////////
   
   `uvm_object_utils_begin(eth_common_methods)
   `uvm_object_utils_end

   extern function new(string name = "eth_common_methods");
   
   extern task pma_receive_process();
   extern task pcs_synchronization_process();
   extern task pcs_receive_process();
   extern function void write_an();
   extern function void resolve_inner_state(ref rx_receive_sm_st_t rx_receive_sm_st);
   
   extern function void print_sm_state(string state_s);
   extern function void print_rx_rcv_state(rx_sync_sm_st_t rx_sync_sm_st);

   
   extern function bit is_cggood(bit rx_even);   
   extern function bit check_comma(cg_t cg);
   
endclass // eth_common_methods

function eth_common_methods::new(string name = "eth_common_methods");
   super.new(name);
   decoder = eth_decoder::type_id::create("decoder",null);   
endfunction: new


//--------------------------------------------------------
// 36.2.5.2.2 Receive
//--------------------------------------------------------

task eth_common_methods::pcs_receive_process();
   
   rx_receive_sm_st_t rx_receive_sm_st;
   
   forever begin

      @SUDI_e;      

      `uvm_info("ETH_COMMON" , $sformatf("SUDI event has occured"), UVM_FULL);
            
      if(!sync_status)
	rx_receive_sm_st = LINK_FAILED_st;
      
      if(vif.mr_main_reset == 1'b1)
	rx_receive_sm_st = WAIT_FOR_K_st;
      
      case(rx_receive_sm_st)
	
  	LINK_FAILED_st: begin
	   if(xmit != xmit_t_wrap::DATA)
	     //decoder.RUDI_set(rudi_t_wrap::INVALID);
	   if(receiving) begin
	      receiving = 0;
	      RX_ER = '1;
	   end
	   else begin
	      RX_DV = '0;
	      RX_ER = '0;
	   end
	   rx_receive_sm_st = WAIT_FOR_K_st;		 
	end
	
	WAIT_FOR_K_st: begin
	   receiving = '0;
	   RX_DV = '0;
	   RX_ER = '0;
 	   if(decoder.cg_check_name("K28_5") && decoder.SUDI_is_rx_even()) begin
	      rx_receive_sm_st = RX_K_st;
	   end
	end
	
	RX_K_st: begin
	   receiving = '0;
	   RX_DV = '0;
	   RX_ER = '0;
	   if(decoder.cg_check_name("D21_5") || decoder.cg_check_name("D2_2"))
	     rx_receive_sm_st = RX_CB_st;
	   else if(!decoder.cg_check_type(DATA) && xmit != xmit_t_wrap::DATA)
	     rx_receive_sm_st = RX_INVALID_st;
	   else if((xmit != xmit_t_wrap::DATA && (decoder.cg_check_type(DATA) && !decoder.cg_check_name("D21_5") && !decoder.cg_check_name("D2_2"))) || (xmit == xmit_t_wrap::DATA && (!decoder.cg_check_name("D21_5") && !decoder.cg_check_name("D2_2"))))
	     rx_receive_sm_st = IDLE_D_st;
	end // case: RX_K_st
	
	RX_CB_st: begin
	   receiving = '0;
	   RX_DV = '0;
	   RX_ER = '0;
	   if(decoder.cg_check_type(DATA))
	     rx_receive_sm_st = RX_CC_st;
	   else
	     rx_receive_sm_st = RX_INVALID_st;	     
	end

	RX_CC_st: begin
	   rx_config_reg[7:0] = decoder.cg_decode();
	   if(decoder.cg_check_type(DATA))
	     rx_receive_sm_st = RX_CD_st;
	   else
	     rx_receive_sm_st = RX_INVALID_st;
	end

	RX_CD_st: begin
	   rx_config_reg[15:8] = decoder.cg_decode();
	   //decoder.RUDI_set(rudi_t_wrap::CONFIG);	      
	   if(decoder.cg_check_name("K28_5") && decoder.SUDI_is_rx_even())
	     rx_receive_sm_st = RX_K_st;
	   else if(!decoder.cg_check_name("K28_5") || decoder.SUDI_is_rx_even())
	     rx_receive_sm_st = RX_INVALID_st;
	end

	IDLE_D_st: begin
	   receiving = '0;
	   RX_DV = '0;
	   RX_ER = '0;
	   //decoder.RUDI_set(rudi_t_wrap::IDLE);	      
	   if(xmit == xmit_t_wrap::DATA && decoder.carrier_detect()) begin
	      // CARRIER_DETECT state
	      //rx_receive_sm_st = CARRIER_DETECT_st;
	      receiving = '1;
	      if(decoder.os_check("/S/"))
	        rx_receive_sm_st = START_OF_PACKET_st;
	      else 
	        rx_receive_sm_st = FALSE_CARRIER_st;
	   end
	   else if(xmit == xmit_t_wrap::DATA && decoder.carrier_detect() || decoder.cg_check_name("K28_5"))
	     rx_receive_sm_st = RX_K_st;
	   
	   //if(!decoder.cg_check_name("K28_5") && xmit != xmit_t_wrap::DATA)
	   else
	      rx_receive_sm_st = RX_INVALID_st;
	end // case: IDLE_D_st
	
	//CARRIER_DETECT_st: begin
	//   receiving = TRUE;
	//   if(decoder.os_check("/S/"))
	//     rx_receive_sm_st = START_OF_PACKET_st;
	//   else 
	//     rx_receive_sm_st = FALSE_CARRIER_st;
	//end

	FALSE_CARRIER_st: begin
	   RX_ER = '1;
	   RXD = 8'b0000_1110;
	   if(decoder.cg_check_name("K28_5") && decoder.SUDI_is_rx_even())
	     rx_receive_sm_st = RX_K_st;
	end

	RX_INVALID_st: begin
	   if(xmit == xmit_t_wrap::CONFIG)
	     //decoder.RUDI_set(rudi_t_wrap::INVALID);
	     ;	   
	   else if(xmit == xmit_t_wrap::DATA)
	     receiving = '1;
	   if(decoder.cg_check_name("K28_5") && decoder.SUDI_is_rx_even())
	     rx_receive_sm_st = RX_K_st;
	   else
	     if( !decoder.cg_check_name("K28_5") && decoder.SUDI_is_rx_even())
	       rx_receive_sm_st = WAIT_FOR_K_st;
	end // case: RX_INVALID_st
	
	START_OF_PACKET_st: begin
	   RX_DV = '1;
	   RX_ER = '0;
	   RXD = 8'b0101_0101;
	   rx_receive_sm_st = RECEIVE_st;
	   eth_seq_item_h = eth_seq_item::type_id::create("eth_seq_item");
	end

	// In receive state doesn't wait for a new SUDI message, so we
	// need to inherite one more case statement to handle this situation
	RECEIVE_st: begin

	   decoder.check_end_print();
	   
	   if(decoder.check_end('{"K28_5" , "/D/"  , "K28_5"}) || 
	      decoder.check_end('{"K28_5" , "D21_5", "D0_0"}) || 
	      decoder.check_end('{"K28_5" , "D2_2" , "D0_0"}) && 
	      decoder.SUDI_is_rx_even())
	     
	     rx_receive_sm_st = EARLY_END_st;
	   else if(decoder.check_end('{"/T/" , "/R/" , "K28_5"}) && decoder.SUDI_is_rx_even())
	     rx_receive_sm_st = TRI_RRI_st;
	   else if(decoder.check_end('{"/T/" , "/R/" , "/R/"}))
	     rx_receive_sm_st = TRR_EXTEND_st;
	   else if(decoder.check_end('{"/R/" , "/R/" , "/R/"}))
	     rx_receive_sm_st = EARLY_END_EXT_st;
	   else if(decoder.cg_check_type(DATA))
	     rx_receive_sm_st = RX_DATA_st;
	   else
	     rx_receive_sm_st = RX_DATA_ERROR_st;

	   print_sm_state({"RX RCV SM : " , rx_receive_sm_st.name()});
	   resolve_inner_state(rx_receive_sm_st);
	   
	end // case: RECEIVE_st
	
	EPD2_CHECK_END_st: begin
	   if(decoder.check_end('{"/R/" , "/R/" , "/R/"}))
	     rx_receive_sm_st = TRR_EXTEND_st;
	   else if(decoder.check_end('{"/R/" , "/R/" , "K28_5"}) && decoder.SUDI_is_rx_even())
	     rx_receive_sm_st = TRI_RRI_st;
	   else if(decoder.check_end('{"/R/" , "/R/" , "/S/"}))
	     rx_receive_sm_st = PACKET_BURST_RPS_st;
	   else
	     rx_receive_sm_st = EXTEND_ERR_st;
	   resolve_inner_state(rx_receive_sm_st);

	end // case: EPD2_CHECK_END_st
	
	default:
	  resolve_inner_state(rx_receive_sm_st);
	
      endcase // case (rx_receive_sm_st)

      print_sm_state({"RX RCV SM : " , rx_receive_sm_st.name()});

end   

endtask // receive

function void eth_common_methods::write_an();
   `uvm_info("ETH_COMMON" , eth_seq_item_h.convert2string() , UVM_LOW)
   analysis_port.write(eth_seq_item_h);
endfunction // write_an

function void eth_common_methods::resolve_inner_state(ref rx_receive_sm_st_t rx_receive_sm_st);
   
   case(rx_receive_sm_st)
     
     EARLY_END_st: begin
	RX_ER = '1;
	if(!decoder.cg_check_name("D21_5") && !decoder.cg_check_name("D2_2"))
	  rx_receive_sm_st = IDLE_D_st;
	else if(decoder.cg_check_name("D21_5") || decoder.cg_check_name("D2_2"))
	  rx_receive_sm_st = RX_CB_st;
     end
     
     TRI_RRI_st: begin
	receiving = '1;
	RX_DV = '0;
	RX_ER = '0;
	if(decoder.cg_check_name("K28_5")) begin
	   rx_receive_sm_st = RX_K_st;
	   write_an();
	end
     end
     
     TRR_EXTEND_st: begin
	RX_DV = '0;
	RX_ER = '1;
	RXD = 8'b0000_1111;
	rx_receive_sm_st = EPD2_CHECK_END_st;
     end
     
     EARLY_END_EXT_st: begin
	RX_ER = '1;
	rx_receive_sm_st = EPD2_CHECK_END_st;
     end
     
     RX_DATA_st: begin
	RX_ER = '0;
	RXD = decoder.cg_decode();
	rx_receive_sm_st = RECEIVE_st;
	eth_seq_item_h.frame_an.push_back(decoder.cg_decode());
     end
     
     RX_DATA_ERROR_st: begin
	RX_ER = '1;
	rx_receive_sm_st = RECEIVE_st;
     end

     PACKET_BURST_RPS_st: begin
	RX_DV = 0;
	RXD = 'b0000_1111;
	if(decoder.os_check("/S/")) begin
	   rx_receive_sm_st = START_OF_PACKET_st;
	   write_an();
	end
     end

     EXTEND_ERR_st: begin
	RX_DV = '0;
	RXD = 8'b0000_1111;
	if(decoder.os_check("/S/")) begin
	   rx_receive_sm_st = START_OF_PACKET_st;
	   write_an();
	end
	else if(decoder.cg_check_name("K28_5") && decoder.SUDI_is_rx_even())
	  rx_receive_sm_st = RX_K_st;
	else if(decoder.os_check("/S/") && !(decoder.cg_check_name("K28_5") && decoder.SUDI_is_rx_even()))
	  rx_receive_sm_st = EPD2_CHECK_END_st;
     end	      
	
     default:
       `uvm_fatal(get_type_name(),"Default state is prohibited")

   endcase // case (rx_receive_sm_st)
endfunction
   


//------------------------------------------------------------------------
// 36.2.5.2.6 Synchronization
//------------------------------------------------------------------------

task eth_common_methods::pcs_synchronization_process();
   
   int good_cgs = '0;      
   bit rx_even = '1;   
   rx_sync_sm_st_t rx_sync_sm_st = LOSS_OF_SYNC_st;
       
   forever begin

      // According to Figure 36-9-Synchronization SM state transitions occur
      // only when new PUDI message has been received.
      
      @PUDI_e;
      `uvm_info("ETH_COMMON" , $sformatf("PUDI event has occured"), UVM_FULL);

      // 1. At first step we calculate the state transition.
      if(vif.mr_main_reset == 1'b1)
	rx_sync_sm_st = LOSS_OF_SYNC_st;
      
      case(rx_sync_sm_st)
	
	LOSS_OF_SYNC_st: begin
	   if(decoder.cg_is_comma() && (vif.signal_detect == 1'b1 || vif.mr_loopback == 1'b1))
	     rx_sync_sm_st = COMMA_DETECT_1_st;
	   else
	     rx_sync_sm_st = LOSS_OF_SYNC_st;	      
	end
	
	COMMA_DETECT_1_st: begin
	   if(decoder.cg_check_type(DATA))
	     rx_sync_sm_st = ACQUIRE_SYNC_1_st;
	   else
	     rx_sync_sm_st = LOSS_OF_SYNC_st;	      
	end
	
	ACQUIRE_SYNC_1_st: begin
	   if(rx_even == FALSE && decoder.cg_is_comma())
	     rx_sync_sm_st = COMMA_DETECT_2_st;
	   else if(!decoder.cg_check_type(INVALID) && !decoder.cg_is_comma())
	     rx_sync_sm_st = ACQUIRE_SYNC_1_st;
	   else
	     rx_sync_sm_st = LOSS_OF_SYNC_st;	      
	end

	COMMA_DETECT_2_st: begin
	   if(decoder.cg_check_type(DATA))
	     rx_sync_sm_st = ACQUIRE_SYNC_2_st;
	   else
	     rx_sync_sm_st = LOSS_OF_SYNC_st;	      
	end

	ACQUIRE_SYNC_2_st: begin
	   `uvm_info("ETH_COMMON" , $sformatf("is_comma = %0b , is_invalid = %0b" , decoder.cg_check_type(INVALID) , decoder.cg_is_comma()) , UVM_FULL)
	   
	   if(!rx_even && decoder.cg_is_comma())
	     rx_sync_sm_st = COMMA_DETECT_3_st;
	   else if(!decoder.cg_check_type(INVALID) && !decoder.cg_is_comma())
	      rx_sync_sm_st = ACQUIRE_SYNC_2_st;
	   else
	      rx_sync_sm_st = LOSS_OF_SYNC_st;
	end

	COMMA_DETECT_3_st: begin
	   if(decoder.cg_check_type(DATA))
	     rx_sync_sm_st = SYNC_ACQUIRED_1_st;
	   else
	     rx_sync_sm_st = LOSS_OF_SYNC_st;
	end
	
	SYNC_ACQUIRED_1_st: begin
	   if(is_cggood(rx_even))
	     rx_sync_sm_st = SYNC_ACQUIRED_1_st;
	   else
	     rx_sync_sm_st = SYNC_ACQUIRED_2_st;
	end

	SYNC_ACQUIRED_2_st: begin
	   if(is_cggood(rx_even))
	     rx_sync_sm_st = SYNC_ACQUIRED_2A_st;
	   else 
	     rx_sync_sm_st = SYNC_ACQUIRED_3_st;
	end

	SYNC_ACQUIRED_2A_st: begin
	   if(is_cggood(rx_even))
	     rx_sync_sm_st = (good_cgs == 3) ? SYNC_ACQUIRED_1_st : SYNC_ACQUIRED_2A_st;
	   else
	     rx_sync_sm_st = SYNC_ACQUIRED_3_st;
	end

	SYNC_ACQUIRED_3_st: begin
	   if(is_cggood(rx_even))
	     rx_sync_sm_st = SYNC_ACQUIRED_3A_st;
	   else 
	     rx_sync_sm_st = SYNC_ACQUIRED_4_st;
	end

	SYNC_ACQUIRED_3A_st: begin
	   if(is_cggood(rx_even))
	     rx_sync_sm_st = (good_cgs == 3) ? SYNC_ACQUIRED_2_st : SYNC_ACQUIRED_3A_st;
	   else
	     rx_sync_sm_st = SYNC_ACQUIRED_4_st;
	end

	SYNC_ACQUIRED_4_st: begin
	   if(is_cggood(rx_even))
	     rx_sync_sm_st = SYNC_ACQUIRED_4A_st;
	   else 
	     rx_sync_sm_st = LOSS_OF_SYNC_st;
	end

	SYNC_ACQUIRED_4A_st: begin
	   if(is_cggood(rx_even))
	     rx_sync_sm_st = (good_cgs == 3) ? SYNC_ACQUIRED_3_st : SYNC_ACQUIRED_4A_st;
	   else
	     rx_sync_sm_st = LOSS_OF_SYNC_st;
	end

	default:
	  `uvm_fatal(get_type_name(), "Synchronization SM failed state")
	
      endcase // case (rx_sync_sm_st)

      // 2. Then we execute actions inside state blocks.
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

	default:
	  `uvm_fatal(get_type_name(), "Synchronization SM failed state")
	
      endcase // case (rx_sync_sm_st)

      print_sm_state({"RX SYNC SM : " , rx_sync_sm_st.name()});
      
      decoder.SUDI_set_parity(rx_even);
      
      ->SUDI_e;
      
   end // forever begin
   
endtask // pcs_synchronization_process

function bit eth_common_methods::is_cggood
  (
  input bit rx_even
    );
   bit 	    cggood;
   
   cggood = !((decoder.cg_is_comma() && rx_even == EVEN) || decoder.cg_check_type(INVALID));
   return cggood;   
endfunction // is_cggood

function void eth_common_methods::print_sm_state
  (
  input string state_s
    );

   print_struct_t print_struct;
   print_struct.header_s = state_s;   
   msg_print.print(print_struct);
   
endfunction // print_sm_state

function void eth_common_methods::print_rx_rcv_state
  (
  input rx_sync_sm_st_t rx_sync_sm_st
    );

   print_struct_t print_struct;   
   footer_struct_t footer_struct;   

   print_struct.header_s	= "RX RCV STATE";   
   footer_struct.footer_name_s	= "rx_rcv_state";
   footer_struct.footer_val_s	= rx_sync_sm_st.name();
   
   print_struct.footer_q.push_back(footer_struct);
   msg_print.print(print_struct);
   
endfunction // print_rx_rcv_state

//-------------------------------------------------
// 36.3 Physical Medium Attachment (PMA) sublayer
//-------------------------------------------------

// 36.3.2.3 PMA receive function and 3.3.2.4 Code-group alignment process

task eth_common_methods::pma_receive_process();

   logic [0:9] ten_bits;
   logic [0:19] two_ten_bits;
   int 		comma_position = '0;
   int 		cg_counter = '0;
      
   bit 		is_comma = 1'b0;
   
   forever begin      
      vif.read(ten_bits); 
      two_ten_bits = {two_ten_bits[10:19] , ten_bits};
      
      `uvm_info("ETH_COMMON" , $sformatf("Received 10-bit: 0b%10b " , ten_bits) , UVM_FULL)
      `uvm_info("ETH_COMMON" , $sformatf("Two 10-bit: 0b%20b " , two_ten_bits) , UVM_FULL)

      is_comma = 1'b0;
      
      if(EN_CDEN == 1'b1) begin	
	 for(int i = 0; i < 10; ++i) begin
	    //`uvm_info("ETH_COMMON" , $sformatf("Comma try: %7b" , two_ten_bits[i+:7]) , UVM_FULL)
	    if(check_comma(two_ten_bits[i+:10])) begin
	       comma_position = i;
	       is_comma = 1'b1;
	       `uvm_info("ETH_COMMON" , $sformatf("Comma detected in pos %0d %7b" , comma_position , two_ten_bits[i+:7]) , UVM_FULL)
	    end
	 end
      end
      else begin
	 is_comma = check_comma(two_ten_bits[comma_position+:10]);
      end // else: !if(is_comma == FALSE)
      
      decoder.cg_set(two_ten_bits[comma_position+:10], is_comma);
      

      // Enable sync process only when three code-groups were received
      if(cg_counter != 2)
	++cg_counter;
      else
	->PUDI_e;
      
      //`uvm_info("ETH_COMMON" , $sformatf("PUDI has triggered ") , UVM_FULL)
      
   end   
endtask // counter_event

function bit eth_common_methods::check_comma(cg_t cg);
   case(cg[0:6])
     7'b0011111 : check_comma = 1;
     7'b1100000 : check_comma = 1;
     default: check_comma = 0;	
   endcase
endfunction // check_comma   

`endif //  `ifndef _ETH_COMMON_METHODS_

