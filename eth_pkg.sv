`ifndef __ETH_PKG__
 `define __ETH_PKG__

package eth_pkg;

   import uvm_pkg::*;
  `include "uvm_macros.svh"

   typedef enum bit{ FALSE = 1'b0 , TRUE = 1'b1}boolen_t;
   typedef enum bit{ NEGATIVE = 1'b0 , POSITIVE = 1'b1} crd_t;
   typedef enum {DATA , SPECIAL, INVALID} cg_type_t;
   typedef enum bit{ EVEN = 1'b1, ODD = 1'b0} parity_t;

   virtual class xmit_t_wrap;
      typedef enum {CONFIG, DATA, IDLE} xmit_t;
   endclass // xmit_t_wrap

   virtual class rudi_t_wrap;      
      typedef enum { INVALID , CONFIG, IDLE} RUDI_t;
   endclass // rudi_t_wrap
      
   typedef bit [7:0] octet_t;
   typedef bit [0:9] cg_t;
   
   // PUDI message sends by PMA receive process
   typedef struct    {
      cg_t cg;
      cg_type_t cg_type;
      octet_t octet;      
      string  cg_name;
      bit     comma;
   } cg_struct_t;

   // Auxilary type to allow nested associative arrays
   typedef octet_t decode_table_t[cg_t];
   
   typedef struct    packed{
      crd_t crd;
      octet_t octet_val;
   } crd_octet_t;

   typedef struct{
      string 	 footer_name_s;
      string 	 footer_val_s;
   } footer_struct_t;
   
   typedef struct {
      string 	  header_s;
      footer_struct_t footer_q[$];      
   } print_struct_t;


        
   typedef enum      {LOSS_OF_SYNC_st ,
		      COMMA_DETECT_1_st,
		      ACQUIRE_SYNC_1_st,
		      COMMA_DETECT_2_st,
		      ACQUIRE_SYNC_2_st,
		      COMMA_DETECT_3_st,
		      SYNC_ACQUIRED_1_st,
		      SYNC_ACQUIRED_2_st,
 		      SYNC_ACQUIRED_2A_st,
		      SYNC_ACQUIRED_3_st,
		      SYNC_ACQUIRED_3A_st,
		      SYNC_ACQUIRED_4_st,
		      SYNC_ACQUIRED_4A_st} rx_sync_sm_st_t;

   typedef enum      {LINK_FAILED_st,
		      WAIT_FOR_K_st,
		      RX_K_st,
		      RX_CB_st,
		      RX_CC_st,
		      RX_CD_st,
		      RX_INVALID_st,
		      IDLE_D_st,
		      CARRIER_DETECT_st,
		      FALSE_CARRIER_st,
		      START_OF_PACKET_st,
		      RECEIVE_st,
		      EARLY_END_st,
		      TRI_RRI_st,
		      TRR_EXTEND_st,
		      RX_DATA_ERROR_st,
		      RX_DATA_st,
		      EARLY_END_EXT_st,		 
		      EPD2_CHECK_END_st,
		      PACKET_BURST_RPS_st,
		      EXTEND_ERR_st
		      } rx_receive_sm_st_t;

  `ifndef NO_AGENT_COMPILATION
   `include "eth_cfg.sv"
   `include "message_print.sv"
//  `include "pudi_obj.sv"
   `include "eth_seq_item.sv"   
   `include "eth_decoder.sv"
   `include "eth_common_methods.sv"
   `include "eth_monitor.sv"
  `endif
   
   
endpackage // eth_pkg
   
`endif //  `ifndef __ETH_PKG__
   
   
