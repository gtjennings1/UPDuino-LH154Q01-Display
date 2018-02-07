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

module DPHY_TX_INST (
          input         reset_n          ,      //Resets the Design                   
                                                                                      
          output        DCK_P            ,      //HS (High Speed) Clock  
          output        DCK_N            ,      //HS (High Speed) Clock        
     `ifdef PLL         
          input         byte_clk         ,      //Byte Clock
     `else                    
          input         CLKOP            ,      //HS Clock  
          input         CLKOS            ,      //HS Clock + 90 deg phase shift		  
     `endif                                                                                 
     `ifdef HS_3                                                                      
          output        D3               ,      //HS (High Speed) Data Lane 3         
          output        D2               ,      //HS (High Speed) Data Lane 2         
          output        D1               ,      //HS (High Speed) Data Lane 1         
          output        D0               ,      //HS (High Speed) Data Lane 0         
          input [7:0]   byte_D3          ,      //HS (High Speed) Byte Data, Lane 3   
          input [7:0]   byte_D2          ,      //HS (High Speed) Byte Data, Lane 2   
          input [7:0]   byte_D1          ,      //HS (High Speed) Byte Data, Lane 1   
          input [7:0]   byte_D0          ,      //HS (High Speed) Byte Data, Lane 0   
     `elsif HS_2 
          output        D2               ,      
          output        D1               ,
          output        D0               ,
          input [7:0]   byte_D2          ,
          input [7:0]   byte_D1          ,
          input [7:0]   byte_D0          ,        
     `elsif HS_1 
          output        D1               ,
          output        D0               ,
          input [7:0]   byte_D1          ,
          input [7:0]   byte_D0          ,            
     `elsif HS_0 
          output        D0_P             ,
          output        D0_N             ,
          input [7:0]   byte_D0          ,                       
     `endif
     `ifdef LP_CLK 
          output  [1:0] LPCLK            ,        //LP (Low Power) External Interface Signals for Clock Lane     
          input   [1:0] lpclk_out        ,        //LP (Low Power) Data Receiving Signals for Clock Lane         
          output  [1:0] lpclk_in         ,        //LP (Low Power) Data Transmitting Signals for Clock Lane      
          input         lpclk_dir        ,        //LP (Low Power) Data Receive/Transmit Control for Clock Lane  
     `endif                                                                                                      
     `ifdef LP_3                                                                                                 
          inout   [1:0] LP3              ,        //LP (Low Power) External Interface Signals for Data Lane 3    
          input   [1:0] lp3_out          ,        //LP (Low Power) Data Receiving Signals for Data Lane 3        
          output  [1:0] lp3_in           ,        //LP (Low Power) Data Transmitting Signals for Data Lane 3     
          input         lp3_dir          ,        //LP (Low Power) Data Receive/Transmit Control for Data Lane 3 
     `endif                                                                                                      
     `ifdef LP_2                                                                                                 
          inout   [1:0] LP2              ,        //LP (Low Power) External Interface Signals for Data Lane 2    
          input   [1:0] lp2_out          ,        //LP (Low Power) Data Receiving Signals for Data Lane 2        
          output  [1:0] lp2_in           ,        //LP (Low Power) Data Transmitting Signals for Data Lane 2     
          input         lp2_dir          ,        //LP (Low Power) Data Receive/Transmit Control for Data Lane 2 
     `endif                                                                                                      
     `ifdef LP_1                                                                                                 
          inout   [1:0] LP1              ,        //LP (Low Power) External Interface Signals for Data Lane 1    
          input   [1:0] lp1_out          ,        //LP (Low Power) Data Receiving Signals for Data Lane 1        
          output  [1:0] lp1_in           ,        //LP (Low Power) Data Transmitting Signals for Data Lane 1     
          input         lp1_dir          ,        //LP (Low Power) Data Receive/Transmit Control for Data Lane 1 
     `endif                                                                                                      
     `ifdef LP_0                                                                                                 
          output  [1:0] LP0              ,        //LP (Low Power) External Interface Signals for Data Lane 0    
          input   [1:0] lp0_out          ,        //LP (Low Power) Data Receiving Signals for Data Lane 0        
          output  [1:0] lp0_in           ,        //LP (Low Power) Data Transmitting Signals for Data Lane 0     
          input         lp0_dir          ,        //LP (Low Power) Data Receive/Transmit Control for Data Lane 0 
     `endif                                                                                                 
         input         hs_clk_en        ,        //HS (High Speed) Clock Enable                                                          
          input         hs_data_en     ,            //HS (High Speed) Data Enable      
         input          hsxx_clk_en	,
         input byte_clk	  
);                                                                      
      `ifdef PLL                                                                   
           pllx4   u_pllx4(.CLKI(byte_clk), .RST(~reset_n), .CLKOP(bit_clk), .CLKOS(bit_clk_90), .LOCK( ));
      `else
           assign bit_clk    = CLKOP;
	       assign bit_clk_90 = CLKOS;
	  `endif
	  
      //oDDRx4 u_oDDRx4(.clk_s(sclk), .clkop(bit_clk), .clkos(bit_clk_90), .clkout(hs_clk), .lock_chk(1'b1), .reset(~reset_n), .sclk(sclk), .tx_ready( ), .dataout({byte_D3, byte_D2, byte_D1, byte_D0}), .dout({hs_D3,hs_D2,hs_D1,hs_D0}), .hsxx_clk_en(hsxx_clk_en));
      //oDDRx4 u_oDDRx4(.clk_s(sclk), .clkop(bit_clk), .clkos(bit_clk_90), .clkout(hs_clk), .lock_chk(1'b1), .reset(~reset_n), .sclk(sclk), .tx_ready( ), .dataout({byte_D3, byte_D2, byte_D1, byte_D0}), .dout({hs_D3,hs_D2,hs_D1,hs_D0}), .hsxx_clk_en(hsxx_clk_en), .byte_clk(byte_clk), .hs_data_en(hs_data_en));
reg [7:0] byte_reg, byte_reg2;
reg [2:0] ser_cntr;
reg [1:0] bit_reg;
reg q_byte_clk_flg,q_byte_clk_flg2;
      
SB_IO Data_P         (
   .PACKAGE_PIN         (D0_P    ),
   .LATCH_INPUT_VALUE   (1'b0      ), 
   .CLOCK_ENABLE        (1'b1      ), 
   .INPUT_CLK           (1'b0      ), 
   .OUTPUT_CLK          (CLKOP   ), 
   .OUTPUT_ENABLE       (hs_data_en), 
   .D_OUT_0             (bit_reg[1]      ), 
   .D_OUT_1             (bit_reg[0]      ), 
   .D_IN_0              (          ), 
   .D_IN_1              (          ) 
);
defparam Data_P.PIN_TYPE = 6'b100000;
defparam Data_P.PULLUP = 1'b0;
defparam Data_P.NEG_TRIGGER = 1'b0;
defparam Data_P.IO_STANDARD = "SB_LVCMOS";  
             

SB_IO Data_N         (
   .PACKAGE_PIN         (D0_N    ),
   .LATCH_INPUT_VALUE   (1'b0      ), 
   .CLOCK_ENABLE        (1'b1      ), 
   .INPUT_CLK           (1'b0      ), 
   .OUTPUT_CLK          (CLKOP   ), 
   .OUTPUT_ENABLE       (hs_data_en), 
   .D_OUT_0             (~bit_reg[1]      ), 
   .D_OUT_1             (~bit_reg[0]      ), 
   .D_IN_0              (          ), 
   .D_IN_1              (          ) 
);
defparam Data_N.PIN_TYPE = 6'b100000;
defparam Data_N.PULLUP = 1'b0;
defparam Data_N.NEG_TRIGGER = 1'b0;
defparam Data_N.IO_STANDARD = "SB_LVCMOS";  

SB_IO DCK_P0           (
   .PACKAGE_PIN         (DCK_P    ),
   .LATCH_INPUT_VALUE   (1'b0     ), 
   .CLOCK_ENABLE        (1'b1     ), 
   .INPUT_CLK           (1'b0     ), 
   .OUTPUT_CLK          (CLKOS    ), 
   .OUTPUT_ENABLE       (hs_clk_en ), 
   .D_OUT_0             (1'b0     ), 
   .D_OUT_1             (hsxx_clk_en ? 1'b1:1'b0), 
   .D_IN_0              (         ),
   .D_IN_1              (         ) 
);
defparam DCK_P0.PIN_TYPE = 6'b100000;
defparam DCK_P0.PULLUP = 1'b0;
defparam DCK_P0.NEG_TRIGGER = 1'b0;
defparam DCK_P0.IO_STANDARD = "SB_LVCMOS";  

SB_IO DCK_N0            (
   .PACKAGE_PIN         (DCK_N    ),
   .LATCH_INPUT_VALUE   (1'b0     ), 
   .CLOCK_ENABLE        (1'b1     ), 
   .INPUT_CLK           (1'b0     ), 
   .OUTPUT_CLK          (CLKOS    ), 
   .OUTPUT_ENABLE       (hs_clk_en), 
   .D_OUT_0             (1'b1     ), 
   .D_OUT_1             (hsxx_clk_en ? 1'b0:1'b1), 
   .D_IN_0              (         ), 
   .D_IN_1              (         ) 
);
defparam DCK_N0.PIN_TYPE    = 6'b100000;
defparam DCK_N0.PULLUP      = 1'b0;
defparam DCK_N0.NEG_TRIGGER = 1'b0;
defparam DCK_N0.IO_STANDARD = "SB_LVCMOS"; 

 
     assign LPCLK = hs_clk_en  ? 2'b00     :
                                 lpclk_out ;
                          //lpclk_dir  ? lpclk_out : 2'bzz;
     assign LP0   = hs_data_en ? 2'b00     :
                                 lp0_out;
                          //lp0_dir    ? lp0_out : 2'bzz;
     assign LP1   = 2'b00; //hs_data_en ? 2'b00     :
                          //lp1_dir    ? lp1_out : 2'bzz;    
     assign LP2   = 2'b00; //hs_data_en ? 2'b00     :
                          //lp2_dir    ? lp2_out : 2'bzz;
     assign LP3   = 2'b00; //hs_data_en ? 2'b00     :
                          //lp3_dir    ? lp3_out : 2'bzz;

always@(negedge reset_n or posedge byte_clk)
    if(!reset_n)
      byte_reg <=8'h00;
    else
      byte_reg <= byte_D0;//{d70, d60, d50, d40, d30, d20, d10, d00};// {d00, d10, d20, d30, d40, d50, d60, d70};
      
    always@(negedge reset_n or posedge CLKOP)
    if(!reset_n) begin
      ser_cntr <=1;
      byte_reg2 <= 0;
      bit_reg <=0;
      q_byte_clk_flg  <= 0;
      q_byte_clk_flg2 <= 0;
    end
    else 
    begin 
      ser_cntr <= hs_data_en&~q_byte_clk_flg ? 3'd1 : ser_cntr+2;
      byte_reg2 <= byte_reg;
      bit_reg  <= {byte_reg2[ser_cntr], byte_reg2[ser_cntr-1]};
      q_byte_clk_flg  <= hs_data_en;
    end
//assign buf_clkout = hsxx_clk_en? clkos : 0;     
//assign buf_douto0 = bit_reg;
/*ODDRXE u_oddrx(
   .D0(bit_reg[0]), 
   .D1(bit_reg[1]), 
   .SCLK(clkop), 
   .RST(reset),
   .Q(buf_douto0) );*/
   
//assign dout = buf_douto0;

                                
 /*     IO_Controller_TX u_IO_Controller_TX(
           .reset_n(reset_n)                               , 
           .hs_clk (hs_clk)                                , 
           .hs_D0  (hs_D0)                                 , 
           .hs_D1  (hs_D1)                                 ,
           .hs_D2  (hs_D2)                                 , 
           .hs_D3  (hs_D3)                                 , 
           .DCK_P  (DCK_P)                                 , 
           .DCK_N  (DCK_N)                                 , 
           .D0_P   (D0_P)                                  , 
           .D0_N   (D0_N)                                  , 
           .D1     (D1)                                    , 
           .D2     (D2)                                    , 
           .D3     (D3)                                    , 
           .LPCLK  (`ifdef LP_CLK LPCLK `endif)            ,
           .LP0    (`ifdef LP_0 LP0 `endif)                , 
           .LP1    (`ifdef LP_1 LP1 `endif)                , 
           .LP2    (`ifdef LP_2 LP2 `endif)                , 
           .LP3    (`ifdef LP_3 LP3 `endif)                , 
           .hs_clk_en (hs_clk_en)                          ,  
           .hs_data_en(hs_data_en)                         , 
           .lpclk_dir(lpclk_dir)                           , 
           .lp0_dir(lp0_dir)                               ,
           .lp1_dir(lp1_dir)                               ,
           .lp2_dir(lp2_dir)                               ,
           .lp3_dir(lp3_dir)                               ,
           .lpclk_out(lpclk_out)                           , 
           .lp0_out(lp0_out)                               , 
           .lp1_out(lp1_out)                               , 
           .lp2_out(lp2_out)                               , 
           .lp3_out(lp3_out)                               , 
           .lpclk_in(lpclk_in)                             ,
           .lp0_in(lp0_in)                                 , 
           .lp1_in(lp1_in)                                 , 
           .lp2_in(lp2_in)                                 , 
           .lp3_in(lp3_in)
      );*/

                    
endmodule