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

module LP_HS_DELAY_CNTRL #(

    parameter LP01CLK_dly           = 1,   //4-1 byte clock >50 ns;
    parameter LP00CLK_dly           = 1,
    parameter HS00CLK_dly           = 1,
    parameter HSXXCLK_dly           = 1,
    parameter CLK2DATA_dly          = 1,
    parameter LP01DATA_dly          = 1,
    parameter LP00DATA_dly          = 1,
    parameter HS00DATA_dly          = 1,
    parameter HSXXDATA_dly          = 1
)
(
    input       reset_n                  ,
    input       byte_clk                 ,
    input       hs_en                    ,
    input [7:0] byte_D3_in               ,
    input [7:0] byte_D2_in               ,
    input [7:0] byte_D1_in               ,
    input [7:0] byte_D0_in               ,
    
    output reg    hsxx_clk_en            ,
    output reg    hs_clk_en                 ,
    output reg    hs_data_en                ,
    output reg [1:0] lp_clk              ,
    output reg [1:0] lp_data             ,
    output [7:0] byte_D3_out             ,
    output [7:0] byte_D2_out             ,
    output [7:0] byte_D1_out             ,
    output [7:0] byte_D0_out             
);

//beginning timing numbers based on when hs_en is high
parameter p_LP01_clk = LP01CLK_dly;  
parameter p_LP00_clk = LP01CLK_dly+LP00CLK_dly;
parameter p_HS00_clk = LP01CLK_dly+LP00CLK_dly+HS00CLK_dly;
parameter p_HSXX_clk = LP01CLK_dly+LP00CLK_dly+HS00CLK_dly+HSXXCLK_dly;
parameter p_clk2data = LP01CLK_dly+LP00CLK_dly+HS00CLK_dly+HSXXCLK_dly+CLK2DATA_dly;
parameter p_LP01_data = LP01CLK_dly+LP00CLK_dly+HS00CLK_dly+HSXXCLK_dly+CLK2DATA_dly+LP01DATA_dly;
parameter p_LP00_data = LP01CLK_dly+LP00CLK_dly+HS00CLK_dly+HSXXCLK_dly+CLK2DATA_dly+LP01DATA_dly+LP00DATA_dly;
parameter p_HS00_data = LP01CLK_dly+LP00CLK_dly+HS00CLK_dly+HSXXCLK_dly+CLK2DATA_dly+LP01DATA_dly+LP00DATA_dly+HS00DATA_dly;
parameter p_HSXX_data = LP01CLK_dly+LP00CLK_dly+HS00CLK_dly+HSXXCLK_dly+CLK2DATA_dly+LP01DATA_dly+LP00DATA_dly+HS00DATA_dly+HSXXDATA_dly;

//ending timing numbers based on when hs_en is low
parameter p_HS00_data_end = p_HSXX_data+HS00DATA_dly;
parameter p_LP00_data_end = p_HSXX_data+HS00DATA_dly+LP00DATA_dly;
parameter p_LP11_data_end = p_HSXX_data+HS00DATA_dly+LP00DATA_dly;
parameter p_data2clk =      p_HSXX_data+HS00DATA_dly+LP00DATA_dly+CLK2DATA_dly;
parameter p_HS00_clk_end =  p_HSXX_data+HS00DATA_dly+LP00DATA_dly+CLK2DATA_dly+HS00CLK_dly;
parameter p_LP00_clk_end =  p_HSXX_data+HS00DATA_dly+LP00DATA_dly+CLK2DATA_dly+HS00CLK_dly+LP00CLK_dly;
parameter p_LP11_clk_end =  p_HSXX_data+HS00DATA_dly+LP00DATA_dly+CLK2DATA_dly+HS00CLK_dly+LP00CLK_dly;

//Delay the Data
genvar i;
reg [31:0] hold_data [p_HSXX_data:0];
reg [15:0] hs_en_high_cnt, hs_en_low_cnt,hs_extended;
reg q_hs_en;
    generate
    for(i=1; i<=p_HSXX_data; i=i+1)
          begin: data_dly
                always @(posedge byte_clk)
    		  hold_data[i] <= hold_data[i-1];	   
          end
    endgenerate
    
    always @(posedge byte_clk)
         hold_data[0] <= hs_en ? {byte_D3_in,byte_D2_in,byte_D1_in,byte_D0_in} : 0;
        	
    assign {byte_D3_out,byte_D2_out,byte_D1_out,byte_D0_out}  = hold_data[p_HSXX_data];

//count cycles that hs_en is high and low for
    always @(posedge byte_clk or negedge reset_n)
          if (!reset_n) begin
               hs_en_high_cnt <= 0;
               hs_en_low_cnt  <= 16'hffff;
               q_hs_en        <= 0;
               hs_extended    <= 0;
          end
          else begin
               q_hs_en        <= hs_en;
               hs_extended    <= hs_en & ~q_hs_en           ? 0  :                     //hs_extended keeps the hs_en_*_cnt running in the case of a short packet
                                 hs_extended<p_HSXX_data ? hs_extended+1 :
                                                              hs_extended;
                                                              
               hs_en_high_cnt <= hs_en |  (hs_extended !=  p_HSXX_data) ? 
                                          hs_en_high_cnt<16'hffff       ? hs_en_high_cnt+1 : hs_en_high_cnt
                                       :  
                                          0;
               hs_en_low_cnt  <= ~hs_en & (hs_extended ==  p_HSXX_data)? 
                                          hs_en_low_cnt<16'hffff  ? hs_en_low_cnt+1  : hs_en_low_cnt
                                       :  
                                          0;
          end

    always @(posedge byte_clk or negedge reset_n)
          if (!reset_n) begin
              hs_clk_en  <=  0;
              hsxx_clk_en<=  0;
              hs_data_en <=  0;
              lp_clk     <=  2'b11;
              lp_data    <=  2'b11;
          end
          else begin
                      
               hs_clk_en  <=  (hs_en_high_cnt == p_LP00_clk       ) ? 1'b1 :
                              (hs_en_low_cnt  == p_HS00_clk_end   ) ? 1'b0 :  hs_clk_en; 
                              
               hsxx_clk_en<=  (hs_en_high_cnt == p_HS00_clk       ) ? 1'b1 :
                              (hs_en_low_cnt  == p_HS00_clk_end   ) ? 1'b0 :  hsxx_clk_en; 
                              
               hs_data_en <=  (hs_en_high_cnt == p_LP00_data      ) ? 1'b1 :
                              (hs_en_low_cnt  == p_HS00_data_end  ) ? 1'b0 :  hs_data_en; 
               
               lp_clk     <=  (hs_en_high_cnt==1                  ) ? 2'b01 :
                              (hs_en_high_cnt==p_LP01_clk         ) ? 2'b00 : 
                              (hs_en_low_cnt == p_LP11_clk_end    ) ? 2'b11 : lp_clk;
                              
               lp_data    <=  (hs_en_high_cnt==p_clk2data         ) ? 2'b01 :
                              (hs_en_high_cnt==p_LP01_data        ) ? 2'b00 : 
                              (hs_en_low_cnt == p_LP11_data_end   ) ? 2'b11 : lp_data;
              
          end


endmodule