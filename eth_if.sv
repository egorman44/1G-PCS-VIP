interface eth_if(input logic clk);

   logic txp, txn;
   logic rxp, rxn;

   logic mr_main_reset;
   logic signal_detectCHANGE;
   logic mr_loopback;
   logic signal_detect;
      
   event rx_ten_bits_ready;
      
   clocking cb@(posedge clk);
      default input #1step output #1;

      output txp, txn;
      input rxp, rxn;
      
   endclocking // cb

   task clock_recovery();      
   endtask // clock_recovery
   
   task write(logic [0:9] data_tx);
            
      for(int i = 0; i < 10; i++) begin
      	 @(cb);
      	 cb.txp		<=  data_tx[i];
      	 cb.txn		<= ~data_tx[i];
      end
            
   endtask // write

   task read(output logic [0:9] data_rx);
      repeat(10) begin
	 @(cb);
	 data_rx = {data_rx[1:9] , cb.rxp};
      end
   endtask
   
endinterface // eth_if
