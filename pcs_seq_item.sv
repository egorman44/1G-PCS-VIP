// ***************************************************************
// Class : pcs_seq_item
// Desc.  : 
// *************************************************************** 

class pcs_seq_item extends uvm_sequence_item;

      // ***************************************************************
   // Class properties
   // ***************************************************************
   
   uvm_tlm_response_status_e status;
   
   rand int ipg;
   rand int carrier_extend_delay;
   rand bit start_error, stop_error;
   rand int tx_frame_size;
   rand byte tx_frame_a[];  
   
   byte      rx_frame_q[$];
   bit 	     rx_err;

   message_print msg_print_h;
   
   // ***************************************************************
   // UVM registration macros
   // ***************************************************************
   
   `uvm_object_utils_begin(pcs_seq_item)
      `uvm_field_int(ipg, UVM_ALL_ON)
      `uvm_field_int(carrier_extend_delay, UVM_ALL_ON)
      `uvm_field_int(start_error, UVM_ALL_ON)
      `uvm_field_int(stop_error, UVM_ALL_ON)
      `uvm_field_int(tx_frame_size, UVM_ALL_ON)
      `uvm_field_array_int(tx_frame_a , UVM_ALL_ON)
      `uvm_field_queue_int(rx_frame_q, UVM_ALL_ON)
   `uvm_object_utils_end
   
      
   // ***************************************************************
   // Constraints 
   // ***************************************************************
   
   // ***************************************************************
   // Class methods
   // ***************************************************************
   
   function new(string name="pcs_seq_item");
      super.new(name);
      msg_print_h = message_print::type_id::create("msg_print");
   endfunction // new

   function void rx_print();
      print_struct_t print_struct;   
      footer_struct_t footer_struct;
      string debug_str = "";
      
      print_struct.header_s = "RX PACKET";

      footer_struct.footer_name_s = "rx_err";
      footer_struct.footer_val_s = $sformatf("%0d", rx_err);
      print_struct.footer_q.push_back(footer_struct);

      footer_struct.footer_name_s = "frame_size";
      footer_struct.footer_val_s = $sformatf("%0d", rx_frame_q.size());
      print_struct.footer_q.push_back(footer_struct);

      footer_struct.footer_name_s = "rx_data";
      foreach(rx_frame_q[i]) begin
	 if(i[2:0] == 0)	   
	   debug_str = {debug_str, $sformatf("\n %4d:\t",i)};
	 debug_str = {debug_str, $sformatf(" %2x", rx_frame_q[i])};
      end
      footer_struct.footer_val_s = debug_str;      
      print_struct.footer_q.push_back(footer_struct);

      msg_print_h.print(print_struct);   
      
   endfunction // rx_print
   

endclass // pcs_seq_item
