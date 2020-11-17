// ***************************************************************
// Class : pcs_seq_item
// Desc.  : 
// *************************************************************** 

class pcs_seq_item extends uvm_sequence_item;
   
   // ***************************************************************
   // Class properties
   // ***************************************************************
   
   rand op_mode_t op_mode;
   
   rand ipg_type_t ipg_type;
   rand int ipg;   

   rand int frame_size;
   rand byte frame_a[];

   // TX_ER assrtion while TX_EN is asserted indicates an error from
   // RS sublayer. 
   // 1. It could be placed wherever in the packet.
   // 2. The duration takes one or more cycles
   rand bit  err;
    
   rand bit  start_err; // This knob is used to enter in   

   rand int err_position;
   rand int err_duration;

   rand bit carrier_extend;
   rand int carrier_extend_duration;
   
   rand bit carrier_extend_err;
   rand int carrier_extend_err_position;
   rand int carrier_extend_err_duration;
   
   rand bit  next_burst;  
   
   uvm_tlm_response_status_e status;
      
   message_print msg_print_h;
   
   // ***************************************************************
   // UVM registration macros
   // ***************************************************************
   
   `uvm_object_utils_begin(pcs_seq_item)
   `uvm_object_utils_end
      
   // ***************************************************************
   // Constraints 
   // ***************************************************************

   // Use soft here to overide this constraint if
   // Jumbo frames are needed to tets   
   constraint frame_size_cnstr{
      soft frame_size inside {[64:1530]};
      frame_a.size == frame_size;
   }

   // Constraits that defines IPG duration.
   // By default HUGE_IPG is disabled in the ipg_dist_cnstr,
   // You can define it if you want to check testcases when
   // ipg > 1500
   constraint ipg_cnstr{
      ipg_type == MINIMUM_IPG	-> ipg == 12;
      ipg_type == SMALL_IPG	-> ipg inside {[12:50]};
      ipg_type == MEDIUM_IPG	-> ipg inside {[50:500]};
      ipg_type == BIG_IPG	-> ipg inside {[500:1500]};
      //ipg_type == HUGE_IPG	-> <put here what ever you want>
   }
   
   constraint ipg_dist_cnstr{
      soft ipg_type dist {MINIMUM_IPG := 10, SMALL_IPG := 10, MEDIUM_IPG := 5, BIG_IPG := 1};
   }   

   // By default start error is disabled
   constraint start_err_dflt_cnstr{
      soft start_err == 0;
   }

   constraint next_burst_dflt_cnstr{
      soft next_burst == 0;
   }
   
   // This constrain controls error
   // generation during packet transmission process
   constraint err_prop_cnstr {
      if(err) {
	 err_position < frame_size;
	 err_duration < frame_size - err_position;
	 }
      else {
	 err_position == 0;
	 err_duration == 0;
      }
   }
   
   constraint carrier_extend_cnstr {
      if (op_mode == FULL_DUPLEX_m) {
	 carrier_extend == 0;
	 carrier_extend_duration ==0;
	 carrier_extend_err == 0;
	 carrier_extend_err_duration == 0;
	 carrier_extend_err_position == 0;	 
	 }
      else{
	 if(frame_size < 512) {

	    carrier_extend == 1;
	    carrier_extend_duration == 512 - frame_size;
	    if(carrier_extend_err) {
	       carrier_extend_err_position < carrier_extend_duration;
	       carrier_extend_err_duration < carrier_extend_duration - carrier_extend_err_position;
	       }
	 } 
	    else {
	       carrier_extend == 0;
	    }
      }
   }
				  
   // ***************************************************************
   // Class methods
   // ***************************************************************
   
   function new(string name="pcs_seq_item");
      super.new(name);
      msg_print_h = message_print::type_id::create("msg_print");
   endfunction // new

   function void do_copy(uvm_object rhs);

      pcs_seq_item rhs_;

      if(!$cast(rhs_, rhs))
	 `uvm_fatal("PCS_SEQ_ITEM", "Casting failed");
      
      super.do_copy(rhs);
      
      op_mode		= rhs_.op_mode;
      ipg_type		= rhs_.ipg_type;      
      frame_size	= rhs_.frame_size;
      frame_a		= new[frame_size];      
      foreach(frame_a[i])
	frame_a[i] = rhs_.frame_a[i];
      err				= rhs_.err;      
      start_err				= rhs_.start_err;
      err_position			= rhs_.err_position;
      err_duration			= rhs_.err_duration;
      carrier_extend			= rhs_.carrier_extend;
      carrier_extend_duration		= rhs_.carrier_extend_duration;      
      carrier_extend_err		= rhs_.carrier_extend_err;
      carrier_extend_err_position	= rhs_.carrier_extend_err_position;
      carrier_extend_err_duration	= rhs_.carrier_extend_err_duration;      
      next_burst			= rhs_.next_burst;
      status				= rhs_.status;
      msg_print_h			= rhs_.msg_print_h.copy();

   endfunction // do_copy

   function bit do_compare(uvm_object rhs, uvm_comparer comparer);
      bit    seq_item_is_matched = 0;
      pcs_seq_item rhs_;

      if(!$cast(rhs_, rhs))
	 `uvm_fatal("PCS_SEQ_ITEM", "Casting failed");

      if(frame_size != rhs_.frame_size)
	return 0;

      foreach(frame_a[i])
	if(frame_a[i] != rhs_.frame_a[i])
	  return 0;
      
      return 1;
	      
   endfunction // do_compare
   	
   function void print(string header_s);
      
      print_struct_t print_struct;   
      footer_struct_t footer_struct;
      string debug_str = "";
      
      print_struct.header_s = header_s;

      footer_struct.footer_name_s = "op_mode";
      footer_struct.footer_val_s = $sformatf("%0s", op_mode.name());
      print_struct.footer_q.push_back(footer_struct);

      footer_struct.footer_name_s = "ipg";
      footer_struct.footer_val_s = $sformatf("%0d", ipg);
      print_struct.footer_q.push_back(footer_struct);

      footer_struct.footer_name_s = "err";
      footer_struct.footer_val_s = $sformatf("%0d", err);
      print_struct.footer_q.push_back(footer_struct);

      footer_struct.footer_name_s = "carrier_extend";
      footer_struct.footer_val_s = $sformatf("%0d", carrier_extend);
      print_struct.footer_q.push_back(footer_struct);

      footer_struct.footer_name_s = "carrier_extend_duration";
      footer_struct.footer_val_s = $sformatf("%0d", carrier_extend_duration);
      print_struct.footer_q.push_back(footer_struct);
      
      footer_struct.footer_name_s = "carrier_extend_err";
      footer_struct.footer_val_s = $sformatf("%0d", carrier_extend_err);
      print_struct.footer_q.push_back(footer_struct);

      footer_struct.footer_name_s = "frame_size";
      footer_struct.footer_val_s = $sformatf("%0d", frame_size);
      print_struct.footer_q.push_back(footer_struct);

      footer_struct.footer_name_s = "next_burst";
      footer_struct.footer_val_s = $sformatf("%0d", next_burst);
      print_struct.footer_q.push_back(footer_struct);

      footer_struct.footer_name_s = "data";
      foreach(frame_a[i]) begin
	 if(i[2:0] == 0)	   
	   debug_str = {debug_str, $sformatf("\n %4d:\t",i)};
	 debug_str = {debug_str, $sformatf(" %2x", frame_a[i])};
      end
      footer_struct.footer_val_s = debug_str;      
      print_struct.footer_q.push_back(footer_struct);

      msg_print_h.print(print_struct);
      
   endfunction // print
   

endclass // pcs_seq_item
