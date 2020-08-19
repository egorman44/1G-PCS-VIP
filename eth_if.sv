interface eth_if(input logic txp,
		 input logic clk);
   
   logic mr_main_reset;  
   logic mr_loopback;
   logic signal_detectCHANGE;
   logic signal_detect;

   clocking cb@(posedge clk);

   endclocking // cb
   
   
endinterface // eth_if
