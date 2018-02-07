// --------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
// --------------------------------------------------------------------
// Copyright (c) 2006 by Lattice Semiconductor Corporation
// --------------------------------------------------------------------
//
// Permission:
//
//   Lattice Semiconductor grants permission to use this code for use
//   in synthesis for any Lattice programmable logic product.  Other
//   use of this code, including the selling or duplication of any
//   portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL or Verilog source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Lattice Semiconductor provides no warranty
//   regarding the use or functionality of this code.
//
// --------------------------------------------------------------------
//           
//                     Lattice Semiconductor Corporation
//                     5555 NE Moore Court
//                     Hillsboro, OR 97214
//                     U.S.A
//
//                     TEL: 1-800-Lattice (USA and Canada)
//                          503-268-8001 (other locations)
//
//                     web: http://www.latticesemi.com/
//                     email: techsupport@latticesemi.com
// --------------------------------------------------------------------
//
// Revision History :


// UART TX over IrDA on iCEstick

module uart (
         
         input wire   clk_in        ,
         //input wire   from_pc       , 
         input wire   from_io       ,
         output wire  to_ir         ,
         //output wire  sd            ,
         input wire   i_serial_data ,
         output wire  o_serial_data ,
         output wire  o_serial_data_io,
         
         //output       test1         ,
         //output       test2         ,
         //output       test3         ,
         output [7:0] led   ,
         output o_rx_data_ready,
         output CLKOS
         );

// parameters (constants)
parameter clk_freq = 27'd6000000;  // in Hz for 12MHz clock

reg [26:0]  rst_count ;
wire        i_rst ;
wire        CLKOP ;
        

wire [7:0]  o_rx_data       ; 
wire        o_rx_data_ready ;

wire [7:0]  i_tx_data       ;
wire        i_start_tx      ;
wire        w_from_pc       ;
wire        w_clkos /* synthesis syn_keep = 1 */ /* synthesis syn_isclock = 1 */;

assign o_serial_data_io = o_serial_data;
assign w_from_pc = 1;//from_pc;

// internal reset generation
always @ (posedge clk_in)
    begin
        if (rst_count >= (clk_freq/2)) begin
        end else                       
            rst_count <= rst_count + 1;
    end

assign i_rst =0;//= ~rst_count[19] ;

// PLL instantiation
/*ice_pll ice_pll_inst(
     .REFERENCECLK ( clk_in        ),  // input 12MHz
     .PLLOUTCORE   ( CLKOP         ),  // output 38MHz
     .PLLOUTGLOBAL ( PLLOUTGLOBAL  ),
     .RESET        ( 1'b1  )
     );*/
assign CLKOP = clk_in;
//assign CLKOP = clk_in;
reg [5:0] clk_count ; 
reg CLKOS ;
//wire CLKOS;
always @ (posedge CLKOP) begin
    if ( clk_count == 9 ) clk_count <= 0 ;
    else clk_count <= clk_count + 1 ;          
    end

always @ (posedge CLKOP) begin
    if ( clk_count == 9 ) CLKOS <= ~CLKOS ;    
    end
assign w_clkos = CLKOS;    
//assign CLKOS = CLKOP;
//
// UART RX instantiation
/*uart_rx_fsm uut1 (                   
     .i_clk                 ( CLKOP           ),
     .i_rst                 ( i_rst           ),
     .i_rx_clk              ( CLKOP           ),
     .i_start_rx            ( 1'b1            ),
     .i_loopback_en         ( 1'b0            ),
     .i_parity_even         ( 1'b0            ),
     .i_parity_en           ( 1'b0            ),               
     .i_no_of_data_bits     ( 2'b11           ),  
     .i_stick_parity_en     ( 1'b0            ),
     .i_clear_linestatusreg ( 1'b0            ),               
     .i_clear_rxdataready   ( 1'b0            ),
     .o_rx_data             ( o_rx_data       ), 
     .o_timeout             (                 ),               
     .bit_sample_en         ( bit_sample_en   ), 
     .o_parity_error        (                 ),
     .o_framing_error       (                 ),
     .o_break_interrupt     (                 ),               
     .o_rx_data_ready       ( o_rx_data_ready ),
     .i_int_serial_data     (                 ),
     .i_serial_data         ( w_from_pc&from_io ) // from_pc UART signal
    );*/
    
UART_RX u_uart_rx
  (
   .i_Clock      (CLKOP)            ,
   .i_RX_Serial  (w_from_pc&from_io),
   .o_RX_DV      (o_rx_data_ready),
   .o_RX_Byte    (o_rx_data)
   );
   
    
  //assign  o_rx_data_ready = i_start_tx;

reg [4:0] count ;
reg [15:0] shift_reg1 ;
reg [19:0] shift_reg2 ;
wire w_count/* synthesis syn_keep = 1 */ /* synthesis syn_isclock = 1 */;

always @ (posedge w_clkos) count <= count + 1 ;
always @ (posedge w_clkos) shift_reg2[19:0] <= {shift_reg2[18:0], o_rx_data_ready} ; 
always @ (posedge w_clkos) shift_reg1[15:0] <= {shift_reg1[14:0], rx_rdy} ; 
assign rx_rdy = |shift_reg2 ;
assign i_start_tx = |shift_reg1 ;
assign i_tx_data = o_rx_data;//{o_rx_data[7:6], ~o_rx_data[5], o_rx_data[4:0]} ; // o_rx_data
assign w_count = count[3];
// UART TX instantiation
/*uart_tx_fsm uut2(                                
    .i_clk                 ( w_count        ),   
    .i_rst                 ( i_rst         ),   
    .i_tx_data             ( i_tx_data     ),   
    .i_start_tx            ( i_start_tx    ),   
    .i_tx_en               ( 1'b1          ),   
    .i_tx_en_div2          ( 1'b0          ),   
    .i_break_control       ( 1'b0          ),   
    .o_tx_en_stop          (  ),                
    .i_loopback_en         ( 1'b0          ),   
    .i_stop_bit_15         ( 1'b0          ),   
    .i_stop_bit_2          ( 1'b0          ),   
    .i_parity_even         ( 1'b0          ),   
    .i_parity_en           ( 1'b0          ),   
    .i_no_of_data_bits     ( 2'b11         ),   
    .i_stick_parity_en     ( 1'b0          ),   
    .i_clear_linestatusreg ( 1'b0          ),   
    .o_tsr_empty           (  ),                
    .o_int_serial_data     (  ),                
    .o_serial_data         ( o_serial_data )    
    ); */ 
uart_tx u_uart_tx
  (
   .i_Clock(CLKOP),
   .i_Tx_DV(o_rx_data_ready),
   .i_Tx_Byte(o_rx_data), 
   .o_Tx_Active(),
   .o_Tx_Serial(o_serial_data),
   .o_Tx_Done()
   );
                                          

// LED display ASCII code
 assign led = i_tx_data ;                      

 reg [4:0] ir_tx_reg ;  
 wire ir_tx ;
 
 assign sd = 0 ;  // 0: enable  
 //always @ (posedge CLKOP) ir_tx_reg[4:0] <= {ir_tx_reg[3:0], bit_sample_en} ; 
 assign ir_tx = |ir_tx_reg ;
 assign to_ir = ir_tx & ~(w_from_pc&from_io) ;
  
 // debug
 assign test1 =  to_ir ;
 assign test2 =  w_from_pc&from_io ;
 assign test3 =  i_rst ; 
  
endmodule