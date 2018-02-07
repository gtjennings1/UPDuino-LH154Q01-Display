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

`include "compiler_directives.v"

module top #(
     parameter              VC         = 0             ,  //2-bit Virtual Channel Number
     parameter              WC         = 16'h02d0      ,  //16-bit Word Count in byte packets.  16'h05A0 = 16'd1440 bytes = 1440 * (8-bits per byte) / (24-bits per pixel for RGB888) = 480 pixels
     parameter              word_width = 24            ,  //Pixel Bus Width.  Example: RGB888 = 8-bits Red, 8-bits Green, 8-bits Blue = 24 bits/pixel
     parameter              DT         = 6'h3E         ,  //6-bit MIPI DSI Data Type.  Example: dt = 6'h3E = RGB888
     parameter              testmode   = 0             ,  //adds colorbar pattern generator for testing purposes.  Operates off of PIXCLK input clock and reset_n input reset
     parameter              crc16      = 1             ,  //appends 16-bit checksum to the end of long packet transfers.  0 = off, 1 = on.  Turning off will append 16'hFFFF to end of long packet.  Turning off will reduce resource utilization.
     parameter              EoTp       = 1             ,  //appends End of Transfer packet after any short packet or long packet data transfer.  0 = off, 1 = on.  appened as a data burst after packet.
     parameter              reserved   = 0                //reserved=0 at all times
)(
	 //input					screen_rdy, //screen initialized, begin DSI stuff
     input                  reset_n                    ,  // resets design (active low)
     input                  clk0,
     input                  clk1,
     input                  byte_clk,	 
     output                 DCK_P                        ,  // HS (High Speed) Clock
     output                 DCK_N                        ,  // HS (High Speed) Clock
     //input                  system_down, 
     //input                  system_run, 
     //input                  hs_start, 
     //input                  cmd_11, 
     output                 ini_done,                         
                                                                         
                                     
          output        D0_P                             ,   
          output        D0_N                             ,                 
                                    
          output   [1:0] LPCLK                          ,  //LP (Low Power) External Interface Signals for Clock Lane                                                                                                             
          output  [1:0] LP0                            ,  //LP (Low Power) External Interface Signals for Data Lane 0    
                                                                                                             
                                                       
     input                  PIXCLK                     ,  //Pixel clock input for parallel interface
     input                  VSYNC                      ,  //Vertical Sync input for parallel interface
     input                  HSYNC                      ,  //Horizontal Sync input for parallel interface
     input                  DE                         ,  //Data Enable input for parallel interface
     input [8-1:0] PIXDATA                       //Pixel data bus for parallel interface
);
     wire [7:0] byte_D3, byte_D2, byte_D1, byte_D0;
     wire [7:0] byte_D3_out, byte_D2_out, byte_D1_out, byte_D0_out;
     wire [15:0] word_cnt;
     wire [1:0] lp_clk;
     wire [1:0] lp_data;
     wire [word_width-1:0] w_pixdata;
     wire [word_width-1:0] w_pixdata1;
     wire w_pixclk, CLKOP, CLKOS, byte_clk;
     wire ini_done;

     parameter  lane_width = `ifdef HS_3  4
                             `elsif HS_2  3
                             `elsif HS_1  2
                             `elsif HS_0  1
							 `endif
                             ;  
 wire done = 1;
 assign  CLKOP =clk0;    
 assign  CLKOS =clk1;
 //assign  byte_clk = clk2;
// assign  ini_done = done;
/* 
generate
    if(DT=='h3E & lane_width==1) 
         pll_pix2byte_RGB888_1lane u_pll_pix2byte_RGB888_1lane(.RST(~reset_n), .CLKI(w_pixclk), .CLKOP(CLKOP), .CLKOS(CLKOS), .CLKOS2(byte_clk), .LOCK());
endgenerate
generate
    if(DT=='h3E & lane_width==2) 
         pll_pix2byte_RGB888_2lane u_pll_pix2byte_RGB888_2lane(.RST(~reset_n), .CLKI(w_pixclk), .CLKOP(CLKOP), .CLKOS(CLKOS), .CLKOS2(byte_clk), .LOCK());
endgenerate
generate
    if(DT=='h3E & lane_width==4) 
         pll_pix2byte_RGB888_4lane u_pll_pix2byte_RGB888_4lane(.RST(~reset_n), .CLKI(w_pixclk), .CLKOP(CLKOP), .CLKOS(CLKOS), .CLKOS2(byte_clk), .LOCK());
endgenerate
*/
wire w_de;
wire [1:0] w_LP0;

assign word_cnt = w_de? WC : 16'h0000;  
     BYTE_PACKETIZER #(
          .word_width(word_width) ,
          .lane_width(lane_width) ,
          .dt        (DT        ) ,
          .crc16     (crc16     )   
     )
     u_BYTE_PACKETIZER (
          .reset_n         (reset_n)  ,
          .PIXCLK          (w_pixclk)   ,
          .VSYNC           (w_vsync)    ,
          .HSYNC           (w_hsync)    ,
          .DE              (w_de)       ,
          .PIXDATA         (w_pixdata)  ,
          //.system_run      (system_run), 
          //.cmd11          (cmd_11),                 
          .VC              (VC)       ,
          .WC              (word_cnt)       ,
          
          .byte_clk        (byte_clk) ,   
          
          .hs_en           (hs_en)    ,
          .byte_D3         (byte_D3)  ,
          .byte_D2         (byte_D2)  ,
          .byte_D1         (byte_D1)  ,
          .byte_D0         (byte_D0)  ,
          .EoTp            (EoTp)     ,
          .ini_done        (ini_done) 
     );
    
     LP_HS_DELAY_CNTRL 
     u_LP_HS_DELAY_CNTRL(
         .reset_n   (reset_n),
         .byte_clk  (byte_clk),
         //.system_down     (system_down),
         //.hs_start  (hs_start),
         .hs_en     (hs_en),
         .byte_D3_in(byte_D3),
         .byte_D2_in(byte_D2),
         .byte_D1_in(byte_D1),
         .byte_D0_in(byte_D0),
		  .hs_clk_en  (hs_clk_en)               ,
    .hsxx_clk_en(hsxx_clk_en)         ,
    .hs_data_en (hs_data_en)          ,
         .lp_clk  (lp_clk),
         .lp_data (lp_data),
         .byte_D3_out(byte_D3_out),
         .byte_D2_out(byte_D2_out),
         .byte_D1_out(byte_D1_out),
         .byte_D0_out(byte_D0_out)
);


   DPHY_TX_INST u_DPHY_TX_INST (
          .reset_n         (reset_n)       ,      //Resets the Design                   
          .DCK_P           (DCK_P)         ,      //HS (High Speed) Clock
          .DCK_N           (DCK_N)         ,      //HS (High Speed) Clock
		  `ifdef PLL         
              .byte_clk (byte_clk)         ,      //Byte Clock
		   `else  
          .CLKOP           (CLKOP)         ,      //Byte Clock                    
          .CLKOS           (CLKOS)         ,
            `endif                                                                      
          `ifdef HS_3                                                                   
               .D3         (D3)            ,      //HS (High Speed) Data Lane 3         
               .D2         (D2)            ,      //HS (High Speed) Data Lane 2         
               .D1         (D1)            ,      //HS (High Speed) Data Lane 1         
               .D0         (D0)            ,      //HS (High Speed) Data Lane 0         
               .byte_D3    (byte_D3_out)       ,      //HS (High Speed) Byte Data, Lane 3   
               .byte_D2    (byte_D2_out)       ,      //HS (High Speed) Byte Data, Lane 2   
               .byte_D1    (byte_D1_out)       ,      //HS (High Speed) Byte Data, Lane 1   
               .byte_D0    (byte_D0_out)       ,      //HS (High Speed) Byte Data, Lane 0   
          `elsif HS_2      
               .D2         (D2)            ,      
               .D1         (D1)            ,
               .D0         (D0)            ,
               .byte_D2    (byte_D2_out)       ,
               .byte_D1    (byte_D1_out)       ,
               .byte_D0    (byte_D0_out)       ,        
          `elsif HS_1                      
               .D1         (D1)            ,
               .D0         (D0)            ,
               .byte_D1    (byte_D1_out)       ,
               .byte_D0    (byte_D0_out)       ,            
          `elsif HS_0                      
               .D0_P         (D0_P)            ,
               .D0_N         (D0_N)            ,
               .byte_D0    (byte_D0_out)       ,                       
          `endif                           
          `ifdef LP_CLK                    
               .LPCLK      (LPCLK)         ,        
               .lpclk_out  (lp_clk)         ,        
               .lpclk_in   ()              ,        
               .lpclk_dir  (1'b1)             ,        
          `endif                                              
          `ifdef LP_3                                         
               .LP3        (LP3)           ,        
               .lp3_out    (lp_data)         ,        
               .lp3_in     ()              ,        
               .lp3_dir    (1'b1)             ,        
          `endif                                              
          `ifdef LP_2                                         
               .LP2        (LP2)           ,        
               .lp2_out    (lp_data)         ,        
               .lp2_in     ()              ,        
               .lp2_dir    (1'b1)             ,        
          `endif                                              
          `ifdef LP_1                                         
               .LP1        (LP1)           ,        
               .lp1_out    (lp_data)         ,        
               .lp1_in     ()              ,        
               .lp1_dir    (1'b1)             ,        
          `endif                                              
          `ifdef LP_0                                         
               .LP0        (LP0)           ,        
               .lp0_out    (w_LP0)         ,        
               .lp0_in     ()              ,        
               .lp0_dir    (1'b1)             ,        
          `endif                                         
               .hs_clk_en  (hs_clk_en),//~(|lp_clk)& done)         ,
               .hsxx_clk_en(hsxx_clk_en ),				   
               .hs_data_en (hs_data_en),//~(|lp_data) & done) 
               .byte_clk (byte_clk)                                
);      
wire Lp, Ln;
assign w_LP0 = done ? lp_data : {Lp,Ln};

wire [7:0] dcs_data;


    /* DCS_ROM u_DCS_ROM
     (
        .resetn    (reset_n      ) ,
        .clk       (byte_clk     ) ,
        .data_en   (dcs_data_en  ) ,
        .escape_en (dcs_escape_en) ,
        .stop_en   (dcs_stop_en  ) ,
        .data      (dcs_data     ) ,
        .ready     (dcs_ready & screen_rdy   ) ,
        .done      (       )             ///remove DCS in low power state
     );
     DCS_Encoder u_DCS_Encoder
     (
        .resetn     (reset_n      ) ,
        .clk        (byte_clk     ) ,
        .data_en    (dcs_data_en  ) ,
        .escape_en  (dcs_escape_en) ,
        .stop_en    (dcs_stop_en  ) ,
        .data       (dcs_data     ) ,
        .ready      (dcs_ready    ) ,
        .Lp         (Lp           ),
        .Ln         (Ln           )
     );*/

        assign w_pixclk  = PIXCLK;
        assign w_de      = DE;  
        assign w_vsync   = VSYNC;
        assign w_hsync   = HSYNC;
        assign w_pixdata = PIXDATA;
        assign w_pixclk  = PIXCLK;
endmodule