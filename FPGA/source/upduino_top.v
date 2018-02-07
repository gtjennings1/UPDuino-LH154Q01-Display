/******************************************************************************
Copyright 2017 Gnarly Grey LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
******************************************************************************/


module upduino_top (

  output          DCK_P     , //LVDS25E
  output          DCK_N     , //LVDS25E
  output          D0_P      , //LVDS25E
  output          D0_N      , //LVDS25E
  output [1:0]    LPCLK     ,
  output [1:0]    LP0       ,

  input           osc_clk   ,

  input           uart_rx   ,
  output          uart_tx   ,
  
  input           b_sync    ,
  output          b_sync_o  ,
  output          clk_o1    ,
  output          clk_o0
  
);

  wire            vsync;
  wire            hsync;
  wire            de;
  wire   [7:0]    pixdata;
  wire            ini_done;

  wire            w_clk_div4    /* synthesis syn_keep = 1 */ /* synthesis syn_isclock = 1 */;
  wire            byte_clk      /* synthesis syn_keep = 1 */ /* synthesis syn_isclock = 1 */;
  reg    [3:0]    clk_gen       /* synthesis syn_preserve = 1 */;
  wire   [7:0]    uart_data_rx;
  reg    [4:0]    q_de;
  wire            lv;
  wire   [7:0]    w_dout, w_dout_2dsi;
  wire   [19:0]   ram_addr;
  wire   [7:0]    ram_data;
  reg    [6:0]    divclk, divclkneg;
  reg    [12:0]   reset_delay_cnt;
  wire            reset_out;
  reg             reset_out_latch;
  reg             reset_out_trigger;


  assign          b_sync_o = b_sync;

  SB_HFOSC u_SB_HFOSC (
    .CLKHFPU  ( 1'b1    ), 
    .CLKHFEN  ( 1'b1    ), 
    .CLKHF    ( int_osc )
  );	

  assign osc_en = 1;

  always @(posedge int_osc)
    divclk <= divclk+1;
    
  always @(negedge int_osc)
    divclkneg <= divclkneg+1;

  assign          reset_n = (&reset_delay_cnt) && (!reset_out_trigger);

  assign          clk_o0 = divclk[0];
  assign          clk_o1 = divclkneg[0];                            

  //byte clock generation
  always @(posedge clk_o0 or negedge reset_n) 
    begin
      if(!reset_n)
        clk_gen <= 0;
      else   
        clk_gen <= clk_gen+1;
    end  

  assign          w_clk_div4 = clk_gen[1];               
  assign          byte_clk = w_clk_div4;

  //UART
  uart uart0 (
    .clk_in             ( byte_clk          ), 
    .from_io            ( uart_rx           ),
    .to_ir              (                   ),
    .i_serial_data      ( 1'b0              ),
    .o_serial_data      (                   ),
    .o_serial_data_io   ( uart_tx           ),
    .led                ( uart_data_rx      ),
    .o_rx_data_ready    ( uart_data_rx_rdy  ),
    .CLKOS              ( clkos             )            
  );

  //GPU Config control
  cfg_ctrl cfg_ctrl0 (
    .reset_n    ( reset_n           ),
    .byte_clk   ( byte_clk          ),
    .uart_rdy   ( uart_data_rx_rdy  ),
    .uart_data  ( uart_data_rx      ),
    .ram_wr     ( ram_wr            ),
    .ram_addr   ( ram_addr          ),
    .ram_data   ( ram_data          ),
    .reset_out  ( reset_out         )         
  );

  //reset delay generator
  always @ (posedge int_osc)
    begin
      if (!reset_n)
        reset_delay_cnt <= reset_delay_cnt + 13'h0001;
      else  
        reset_delay_cnt <= reset_delay_cnt;
    end  

  //reset out latch
  always @ (posedge byte_clk or negedge reset_n)
    begin
      if (!reset_n)
        reset_out_latch <= 1'b0;
      else
      if (reset_out)
        reset_out_latch <= 1'b1;
      else
        reset_out_latch <= reset_out_latch;      
//    else
//      reset_out_latch <= 1'b0;    
    end
  
  //reset out trigger
  always @ (posedge byte_clk or negedge reset_n)
    begin
      if (!reset_n)
        reset_out_trigger <= 1'b0;
      else
      if ((reset_out_latch) && (!fv))
        reset_out_trigger <= 1'b1;
      else
        reset_out_trigger <= 1'b0;    
    end  
  
  //Frame Buffer
  always @ (posedge byte_clk or negedge reset_n)
    begin
      if(!reset_n) 
        begin
          q_de <= 5'b0;
        end
      else 
        begin
          q_de <= {q_de[4:0],lv};
        end
    end  

  DPRAM DPRAM0 (
    .RSTN     ( reset_n   ),
    .CLK      ( byte_clk  ),
    .WR       ( ram_wr    ),
    .DIN      ( ram_data  ),
    .WADDR    ( ram_addr  ),
    .DOUT_EN  ( lv        ),     
    .DOUT     ( w_dout    )
  );    
       
  //display readout generator/driver
  colorbar_gen 	#(
    .h_active       ( 'd720 ),
    .h_total        ( 'd780 ), 
    .v_active       ( 'd240 ),
    .v_total        ( 'd244 ),
    .H_FRONT_PORCH  ( 'd30  ), 
    .H_SYNCH        ( 'd40  ),
    .V_FRONT_PORCH  ( 'd2   ),
    .V_SYNCH        ( 'd2   ),
    .mode           ( 0     ) 
  ) colorbar_gen0 ( 
    .rstn     ( reset_n & ini_done  ),
    .pixclk   ( byte_clk            ), 
    .fv       ( fv                  ),
    .lv       ( lv                  ), 
    .data     ( pixdata             ),
    .vsync    ( vsync               ),
    .de       ( de                  ),
    .hsync    ( hsync               )
  );
     
  //MIPI DSI TX Top
  top #(
    .VC           ( 0       ),
    .WC           ( 'h02d1  ),    //recalculate
    .word_width   ( 24      ),
    .DT           ( 6'h39   ),    //dcs long wr in default
    .testmode     ( 0       ), 
    .crc16        ( 1       ),  
    .EoTp         ( 0       ),  
    .reserved     ( 0       )                
  ) mipi_dsi_tx_top (
    .ini_done   ( ini_done    ),
    .clk0       ( clk_o0      ),
    .clk1       ( clk_o1      ),
    .byte_clk   ( byte_clk    ),
    .reset_n    ( reset_n     ),
    .PIXCLK     ( 1'b0        ),
    .VSYNC      ( 1'b0        ),  //simplify package transfered in HS state;
    .HSYNC      ( 1'b0        ),
    .DE         ( q_de[4]     ),
    .PIXDATA    ( w_dout_2dsi ),         
    .DCK_P      ( DCK_P       ),  //HS (High Speed) Clock  
    .DCK_N      ( DCK_N       ),                   
    .D0_P       ( D0_P        ),  //HS (High Speed) Data Lane 0    
    .D0_N       ( D0_N        ),  //HS (High Speed) Data Lane 0      
    .LPCLK      ( LPCLK       ),                                                                                               
    .LP0        ( LP0         )   //LP (Low Power) External Interface Signals for Data Lane 0    
  );	

  assign          w_dout_2dsi = w_dout;

endmodule