class message_print extends uvm_object;

   `uvm_object_utils_begin(message_print)
   `uvm_object_utils_end
   
   extern function new(string name = "message_print");   
   extern function void print (print_struct_t msg_struct);
   extern function string space_padding (string in_s , int new_length);
   
endclass // message_printer

function message_print::new(string name = "message_print");
   super.new(name);
endfunction: new

function void message_print::print(print_struct_t msg_struct);

   string debug_s = "";   
   string delimeter_s = "--------------------------------";
   string footer_line_s;
   
   int 	  longest_footer_size = 0;
   

   debug_s = {debug_s , "\n"};   
   debug_s = {debug_s , delimeter_s , "\n"};   
   debug_s = {debug_s , msg_struct.header_s , "\n"};
   debug_s = {debug_s , delimeter_s , "\n"};

   // If the message have a footer
   if(msg_struct.footer_q.size()) begin
      // 1. Find the longest footer_name_s to align printing message
      foreach(msg_struct.footer_q[i]) begin
	 if(msg_struct.footer_q[i].footer_name_s.len() > longest_footer_size)
	   longest_footer_size = msg_struct.footer_q[i].footer_name_s.len();      
      end
      
      // 2. Add padding and concatenate with debug string
      foreach(msg_struct.footer_q[i]) begin
	 msg_struct.footer_q[i].footer_name_s = space_padding(msg_struct.footer_q[i].footer_name_s, longest_footer_size);
	 debug_s = {debug_s, msg_struct.footer_q[i].footer_name_s , ":" , msg_struct.footer_q[i].footer_val_s , "\n"};      
      end      
      debug_s = {debug_s , delimeter_s , "\n"};
   end // if (msg_struct.footer_q.size())
   
   
   `uvm_info("MSG_PRINT" , debug_s , UVM_LOW);
   
endfunction // print


function string message_print::space_padding(string in_s, int new_length);

   string out_s;
   int in_length;

   in_length = in_s.len();
   if(in_length > new_length)
     `uvm_warning("MSG_PRINT" , $sformatf("The length of the string %s is greater than desired new string with padding" , in_s))
   else 
     out_s = {in_s , {new_length - in_length + 3{" "}}};

   return out_s;   
endfunction // space_padding

   
