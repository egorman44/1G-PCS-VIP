// ***************************************************************
// Class : pcs_seq_item
// Desc.  : 
// *************************************************************** 

class pcs_seq_item extends uvm_sequence_item;


   // ***************************************************************
   // UVM registration macros
   // ***************************************************************
   
   `uvm_object_utils_begin(pcs_seq_item)
   `uvm_object_utils_end
   
   // ***************************************************************
   // Class properties
   // ***************************************************************

   rand int ipg;
   rand int carrier_extend_delay;
   rand bit start_error, stop_error;
   rand int frame_size;
   rand byte frame[];

   uvm_tlm_response_status_e status;
   
   // ***************************************************************
   // Constraints 
   // ***************************************************************

   //constraint frame_size_cnstr{
   //   
   //}
   
   // ***************************************************************
   // Class methods
   // ***************************************************************
   
   function new(string name="pcs_seq_item");
      super.new(name);
   endfunction // new

   virtual task body();
   endtask // body

endclass // pcs_seq_item
