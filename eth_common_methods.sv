
`ifndef _ETH_COMMON_METHODS_
 `define _ETH_COMMON_METHODS_

class eth_common_methods extends uvm_object;

 `include "data_8b10b.sv"
 `include "spec_8b10b.sv"
   
   virtual eth_if vif;
   boolen_t sync_status;

   eth_decoder decoder;
   
   event   SUDI_e, PUDI_e;
   
   //////////////////
   // TODO: ANALYZE THIS SIGNALS
   // GMII interface
   
   bit 	   mr_loopback;
   
   logic   RX_ER;
   logic   RX_DV;
   logic [7:0] RXD;
   
   logic [15:0] rx_config_reg;
   bit 		carrier_detect;

   xmit_t_wrap::xmit_t xmit;
   //////////////////
   
   `uvm_object_utils_begin(eth_common_methods)
   `uvm_object_utils_end

   extern function new(string name = "eth_common_methods");
   
   extern function boolen_t check_comma(logic [0:6] comma_try);
   extern task receive();
   extern task synchronization_process();
   extern task ten_bit_counter();


endclass // eth_common_methods

function eth_common_methods::new(string name = "eth_common_methods");
   super.new(name);
   decoder = eth_decoder::type_id::create("decoder",this);   
endfunction: new


//--------------------------------------------------------
//
//--------------------------------------------------------

// 36.2.5.2.2 Receive

task eth_common_methods::receive();
   rx_receive_sm_st_t rx_receive_sm_st;
   boolen_t receiving;
   
   forever begin

      wait(SUDI_e.triggered);

      if(vif.mr_main_reset == 1'b0)
	rx_receive_sm_st = WAIT_FOR_K_st;	 
      else if(sync_status == FALSE) 
	rx_receive_sm_st = LINK_FAILED_st;
      else begin
	 
	 case(rx_receive_sm_st)
	   
  	   LINK_FAILED_st: begin
	      if(xmit != xmit_t_wrap::DATA)
		decoder.RUDI_set(rudi_t_wrap::INVALID);
	      if(receiving == TRUE) begin
		 receiving = FALSE;
		 RX_ER = '1;
	      end
	      else begin
		 RX_DV = '0;
		 RX_ER = '0;
	      end
	      rx_receive_sm_st = WAIT_FOR_K_st;		 
	   end
	   
	   WAIT_FOR_K_st: begin
	      receiving = FALSE;
	      RX_DV = '0;
	      RX_ER = '0;
	      
 	      if(decoder.SUDI_is_K28_5() && decoder.SUDI_is_rx_even())
		rx_receive_sm_st = RX_K_st;	     
	   end
	   
	   RX_K_st: begin
	      receiving = FALSE;
	      RX_DV = '0;
	      RX_ER = '0;
	      if(decoder.SUDI_is_D21_5() || decoder.SUDI_is_D2_2)
		rx_receive_sm_st = RX_CB_st;
	      else if(decoder.SUDI_is_data == FALSE && xmit != xmit_t_wrap::DATA)
		rx_receive_sm_st = RX_INVALID_st;
	      else if((xmit != xmit_t_wrap::DATA && (decoder.SUDI_is_data == TRUE && !decoder.SUDI_is_D21_5() && !decoder.SUDI_is_D2_2())) || (xmit == xmit_t_wrap::DATA && (!decoder.SUDI_is_D21_5() && !decoder.SUDI_is_D2_2())))
		rx_receive_sm_st = IDLE_D_st;
	   end // case: RX_K_st
	   
	   RX_CB_st: begin
	      receiving = FALSE;
	      RX_DV = '0;
	      RX_ER = '0;
	      if(decoder.SUDI_is_data == TRUE)
		rx_receive_sm_st = RX_CC_st;
	      else
		rx_receive_sm_st = RX_INVALID_st;	     
	   end

	   RX_CC_st: begin
	      rx_config_reg[7:0] = decoder.DECODE();
	      if(decoder.SUDI_is_data == TRUE)
		rx_receive_sm_st = RX_CD_st;
	      else
		rx_receive_sm_st = RX_INVALID_st;
	   end

	   RX_CD_st: begin
	      rx_config_reg[15:8] = decoder.DECODE();
	      decoder.RUDI_set(rudi_t_wrap::CONFIG);	      
	      if(decoder.SUDI_is_K28_5() && decoder.SUDI_is_rx_even())
		rx_receive_sm_st = RX_K_st;
	      else if(!decoder.SUDI_is_K28_5() || decoder.SUDI_is_rx_even())
		rx_receive_sm_st = RX_INVALID_st;
	   end

	   IDLE_D_st: begin
	      receiving = FALSE;
	      RX_DV = '0;
	      RX_ER = '0;
	      decoder.RUDI_set(rudi_t_wrap::IDLE);	      
	      if(!decoder.SUDI_is_K28_5() && xmit != xmit_t_wrap::DATA)
		rx_receive_sm_st = RX_INVALID_st;
	      else if(xmit != xmit_t_wrap::DATA && carrier_detect == TRUE)
		rx_receive_sm_st = CARRIER_DETECT_st;
	      else if(xmit != xmit_t_wrap::DATA && carrier_detect == FALSE || decoder.SUDI_is_K28_5())
		rx_receive_sm_st = RX_K_st;
	   end // case: IDLE_D_st

	   CARRIER_DETECT_st: begin
	      receiving = TRUE;
	      if(decoder.is_S_ordered_set())
		rx_receive_sm_st = START_OF_PACKET_st;
	      else 
		rx_receive_sm_st = FALSE_CARRIER_st;
	   end

	   FALSE_CARRIER_st: begin
	      RX_ER = '1;
	      RXD = 8'b0000_1110;
	      if(decoder.SUDI_is_K28_5() && decoder.SUDI_is_rx_even())
		rx_receive_sm_st = RX_K_st;
	   end

	   RX_INVALID_st: begin
	      if(xmit == xmit_t_wrap::CONFIG)
		decoder.RUDI_set(rudi_t_wrap::INVALID);
	      else if(xmit == xmit_t_wrap::DATA)
		receiving = TRUE;
	      if(decoder.SUDI_is_K28_5() && decoder.SUDI_is_rx_even())
		rx_receive_sm_st = RX_K_st;
	      else
		if( !decoder.SUDI_is_K28_5() && decoder.SUDI_is_rx_even())
		  rx_receive_sm_st = WAIT_FOR_K_st;
	   end // case: RX_INVALID_st
	   	      
	   START_OF_PACKET_st: begin
	      RX_DV = '1;
	      RX_ER = '0;
	      RXD = 8'b0101_0101;
	      rx_receive_sm_st = RECEIVE_st;
	   end

	   // In receive state doesn't wait for a new SUDI message, so we
	   // need to inherite one more case statement to handle this situation
	   RECEIVE_st: begin
	      if(decoder.check_end___K28_5___D___K28_5() || decoder.check_end___K28_5___D21_5___D0_0() || decoder.check_end___K28_5___D2_2___D0_0() && decoder.SUDI_is_rx_even())
		rx_receive_sm_st = EARLY_END_st;
	      else if(decoder.check_end___T___R___K28_5() && decoder.SUDI_is_rx_even())
		rx_receive_sm_st = TRI_RRI_st;
	      else if(decoder.check_end___T___R___R())
		rx_receive_sm_st = TRR_EXTEND_st;
	      else if(decoder.check_end___R___R___R())
		rx_receive_sm_st = EARLY_END_EXT_st;
	      else if(decoder.SUDI_is_data == TRUE)
		rx_receive_sm_st = RX_DATA_st;
	      else
		rx_receive_sm_st = RX_DATA_ERROR_st;
	      
	      case(rx_receive_sm_st)
		
		EARLY_END_st: begin
		   RX_ER = '1;
		   if(!decoder.SUDI_is_D21_5() && !decoder.SUDI_is_D2_2())
		     rx_receive_sm_st = IDLE_D_st;
		   else if(decoder.SUDI_is_D21_5() || decoder.SUDI_is_D2_2)
		     rx_receive_sm_st = RX_CB_st;
		end
		
		TRI_RRI_st: begin
		   receiving = FALSE;
		   RX_DV = '0;
		   RX_ER = '0;
		   if(decoder.SUDI_is_K28_5())
		     rx_receive_sm_st = RX_K_st;
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
		   RXD = decoder.DECODE();
		   rx_receive_sm_st = RECEIVE_st;
		end
		
		RX_DATA_ERROR_st: begin
		   RX_ER = '1;
		   rx_receive_sm_st = RECEIVE_st;
		end
		
		default:
		  `uvm_fatal(get_type_name(),"Default state is prohibited")
		
	      endcase // case (rx_receive_sm_st)
	      
	   end // case: RECEIVE_st
	   
	   EPD2_CHECK_END_st: begin
	      if(decoder.check_end___R___R___R())
		rx_receive_sm_st = TRR_EXTEND_st;
	      else if(decoder.check_end___R___R___K28_5() && decoder.SUDI_is_rx_even())
		rx_receive_sm_st = TRI_RRI_st;
	      else if(decoder.check_end___R___R___S())
		rx_receive_sm_st = PACKET_BURST_RPS_st;
	      else
		rx_receive_sm_st = EXTEND_ERR_st;

	      case(rx_receive_sm_st)
		
		TRI_RRI_st: begin
		   receiving = FALSE;
		   RX_DV = '0;
		   RX_ER = '0;
		   if(decoder.SUDI_is_K28_5())
		     rx_receive_sm_st = RX_K_st;
		end
		
		TRR_EXTEND_st: begin
		   RX_DV = '0;
		   RX_ER = '1;
		   RXD = 8'b0000_1111;
		   rx_receive_sm_st = EPD2_CHECK_END_st;
		end

		PACKET_BURST_RPS_st: begin
		   RX_DV = '0;
		   RXD = 8'b0000_1111;
		   if(decoder.is_S_ordered_set())
		     rx_receive_sm_st = START_OF_PACKET_st;
		end

		EXTEND_ERR_st: begin
		   RX_DV = '0;
		   RXD = 8'b0000_1111;
		   if(decoder.is_S_ordered_set())
		     rx_receive_sm_st = START_OF_PACKET_st;
		   else if(decoder.SUDI_is_K28_5() && decoder.SUDI_is_rx_even())
		     rx_receive_sm_st = RX_K_st;
		   else if(decoder.is_S_ordered_set() && !(decoder.SUDI_is_K28_5() && decoder.SUDI_is_rx_even()))
		     rx_receive_sm_st = EPD2_CHECK_END_st;
		end	      

		default:
		  `uvm_fatal(get_type_name(), "Receving SM failed state")
	      endcase // case (rx_receive_sm_st)
	   end // else: !if(sync_status == FAIL)

	   default:
	     `uvm_fatal(get_type_name(), "Receving SM failed state")
	 endcase // case (rx_receive_sm_st)
      end // else: !if(sync_status == FALSE)
   end   

endtask // receive

//------------------------------------------------------------------------
// 36.2.5.2.6 Synchronization   

task eth_common_methods::synchronization_process();
   
   int good_cgs = '0;      
   bit  rx_even = '1;
   
   rx_sync_sm_st_t rx_sync_sm_st;

   forever begin

      // According to Figure 36-9-Synchronization SM state transitions occur
      // only when new PUDI message has been received.
      wait(PUDI_e.triggered);

      // cgbad is not used in synchronization SM(for symplification)just because it's
      // a negation of cgbad

      if(vif.mr_main_reset == 1'b1 || vif.signal_detectCHANGE == TRUE && vif.mr_loopback == FALSE)begin
	 rx_sync_sm_st = LOSS_OF_SYNC_st;
      end
      else begin

	 rx_sync_sm_st = LOSS_OF_SYNC_st;
	 
	 case(rx_sync_sm_st)
	   
	   LOSS_OF_SYNC_st: begin
	      sync_status = FALSE;	   
	      rx_even = ~rx_even;	   
	      if(decoder.PUDI_is_comma && (vif.signal_detect == TRUE || mr_loopback == TRUE))
		rx_sync_sm_st = COMMA_DETECT_1_st;
	   end
	   
	   COMMA_DETECT_1_st: begin
	      rx_even = EVEN;
	      if(decoder.SUDI_is_data())
		rx_sync_sm_st = ACQUIRE_SYNC_1_st;	   
	   end
	   
	   ACQUIRE_SYNC_1_st: begin
	      rx_even = ~rx_even;
	      if(rx_even == FALSE && decoder.PUDI_is_comma)
		rx_sync_sm_st = COMMA_DETECT_2_st;
	      else if(!decoder.SUDI_is_invalid() && !decoder.PUDI_is_comma())
		rx_sync_sm_st = ACQUIRE_SYNC_1_st;
	   end

	   COMMA_DETECT_2_st: begin
	      rx_even = EVEN;
	      if(decoder.SUDI_is_data())
		rx_sync_sm_st = ACQUIRE_SYNC_2_st;
	   end

	   ACQUIRE_SYNC_2_st: begin
	      rx_even = ~rx_even;
	      if(rx_even == FALSE && decoder.PUDI_is_comma)
		rx_sync_sm_st = COMMA_DETECT_3_st;
	      else if(decoder.PUDI_is_invalid() == FALSE && decoder.PUDI_is_comma())
		rx_sync_sm_st = ACQUIRE_SYNC_2_st;
	   end

	   SYNC_ACQUIRED_1_st: begin
	      sync_status = TRUE;
	      rx_even = ~rx_even;
	      if(decoder.PUDI_cggood())
		rx_sync_sm_st = SYNC_ACQUIRED_1_st;
	      else
		rx_sync_sm_st = SYNC_ACQUIRED_2_st;	   
	   end

	   SYNC_ACQUIRED_2_st: begin
	      rx_even = ~rx_even;
	      good_cgs = 0;
	      if(decoder.PUDI_cggood())
		rx_sync_sm_st = SYNC_ACQUIRED_2A_st;
	      else 
		rx_sync_sm_st = SYNC_ACQUIRED_3_st;
	   end

	   SYNC_ACQUIRED_2A_st: begin
	      rx_even = ~rx_even;
	      ++good_cgs;
	      if(decoder.PUDI_cggood())
		rx_sync_sm_st = (good_cgs == 3) ? SYNC_ACQUIRED_1_st : SYNC_ACQUIRED_2A_st;
	      else
		rx_sync_sm_st = SYNC_ACQUIRED_3_st;
	   end

	   SYNC_ACQUIRED_3_st: begin
	      rx_even = ~rx_even;
	      good_cgs = 0;
	      if(decoder.PUDI_cggood())
		rx_sync_sm_st = SYNC_ACQUIRED_3A_st;
	      else 
		rx_sync_sm_st = SYNC_ACQUIRED_4_st;
	   end

	   SYNC_ACQUIRED_3A_st: begin
	      rx_even = ~rx_even;
	      ++good_cgs;
	      if(decoder.PUDI_cggood())
		rx_sync_sm_st = (good_cgs == 3) ? SYNC_ACQUIRED_2_st : SYNC_ACQUIRED_3A_st;
	      else
		rx_sync_sm_st = SYNC_ACQUIRED_4_st;
	   end

	   SYNC_ACQUIRED_4_st: begin
	      rx_even = ~rx_even;
	      good_cgs = 0;
	      if(decoder.PUDI_cggood())
		rx_sync_sm_st = SYNC_ACQUIRED_4A_st;
	      else 
		rx_sync_sm_st = LOSS_OF_SYNC_st;
	   end

	   SYNC_ACQUIRED_4A_st: begin
	      rx_even = ~rx_even;
	      ++good_cgs;
	      if(decoder.PUDI_cggood())
		rx_sync_sm_st = (good_cgs == 3) ? SYNC_ACQUIRED_3_st : SYNC_ACQUIRED_4A_st;
	      else
		rx_sync_sm_st = LOSS_OF_SYNC_st;
	   end

	   default:
	     `uvm_fatal(get_type_name(), "Synchronization SM failed state")
	   
	 endcase // case (rx_sync_sm_st)

	 decoder.SUDI_set_parity(rx_even);
	 ->SUDI_e;
	 
      end // else: !if(vif.mr_main_reset == 1'b1 || vif.signal_detectCHANGE == TRUE && vif.mr_loopback == FALSE)      
   end // forever begin
         
endtask // synchronization_process


//-------------------------------------------------
// 36.3 Physical Medium Attachment (PMA) sublayer
//-------------------------------------------------

// 36.3.2.3 PMA receive function and 3.3.2.4 Code-group alignment process

task eth_common_methods::ten_bit_counter();
   
   logic [0:9] shift_data;
   logic [0:39] four_ten_bits;
   int 		comma_position = '0;
   boolen_t is_comma = FALSE;
   
   
   forever begin
      repeat(10) begin
	 @(vif.cb);
	 shift_data = {shift_data[1:9],vif.txp};
      end
      four_ten_bits = {four_ten_bits[10:29],shift_data};

      if(is_comma == FALSE) begin	
	 for(int i = 0; i < 10; ++i) begin
	    if(check_comma(four_ten_bits[i+:7])) begin
	       comma_position = i;
	       is_comma = TRUE;
	    end	 
	 end
      end
      else begin
	 is_comma = check_comma(four_ten_bits[comma_position+:7]);
      end // else: !if(is_comma == FALSE)

      // Put all input arguments into decoder and calculate all
      // auxilary signals
      
      decoder.PUDI_set_code_group(four_ten_bits[comma_position+:30]);
      decoder.PUDI_set_comma(is_comma);
      decoder.PUDI_calc();      
      
      ->PUDI_e;
   end   
endtask // counter_event

function boolen_t eth_common_methods::check_comma(logic [0:6] comma_try);
   case(comma_try[0:6])
     7'b0011111 : check_comma = TRUE;
     7'b1100000 : check_comma = TRUE;
     default: check_comma = FALSE;	
   endcase
endfunction // check_comma   

`endif //  `ifndef _ETH_COMMON_METHODS_
