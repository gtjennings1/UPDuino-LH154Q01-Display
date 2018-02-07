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

module packetheader #(
    parameter     lane_width = 4   
)(
    input         reset_n             ,
    input         short_en            ,
    input         long_en             ,
    input         byte_clk            ,
    //input         cmd_2a              ,
    //input         cmd_2b              ,
    input  [7:0] byte_data           ,
    input  [1:0]  vc                  ,
    input  [5:0]  dt                  ,
    input  [15:0] wc                  ,
    input         chksum_rdy          ,
    input [15:0]  chksum              , 
    output        crc_en      ,
    output  [7:0] crc_data         ,           
    output reg        bytepkt_en      ,
    output reg [7:0] bytepkt         ,
    input             EoTp             
);
reg q_short_en, q_short_en1, q_long_en, q_long_en_1, q_long_en_2;
reg q_long_pkt_indicator;
reg [7:0] q_byte_data_1, q_byte_data_2, q_byte_data;
reg [1:0]  q_vc;
reg [5:0]  q_dt;
reg [15:0] q_wc;
reg cmd2a, cmd2b;
wire [23:0] PH, PH_rev;
reg  [7:0]  q_ECC,q_byte_data_fifo;

reg PH_En, hsSync_En, DataID_En, WC_0_En, WC_1_En, ECC_En;
reg [5:0] PH_cnt;

reg lpkt_cnt_En;
reg [15:0] lpkt_cnt;
reg chksum_En, q_chksum_En;
reg [15:0] q_chksum;
reg [3:0] EoTp_En;

wire [7:0] byte_data_fifo;

reg q_bytepkt_en;
reg lngpkt_ofst;
wire fifo_wr_en, fifo_rd_en;
wire [7:0] fifo_wr_data;
reg [7:0] cmd2ab_data;
reg [7:0] q_cmd2ab_data;
wire wc_end_flag;
wire [15:0] sc = 16'd0;
wire [15:0] ec = 16'h239;
//wire [15:0] sp = 16'h2345;
//wire [15:0] ep = 16'h6789;
//locks input data to register on byte_en transition
assign crc_en = ECC_En|~wc_end_flag&lpkt_cnt_En;
assign crc_data = ECC_En ? (cmd2a? 8'h2a: cmd2b? 8'h2b:8'h3C) : cmd2a? cmd2ab_data: cmd2b? cmd2ab_data:byte_data_fifo;
always @(posedge byte_clk or negedge reset_n)
    if(!reset_n) begin
        q_short_en    <= 0;
        q_short_en1    <= 0;
        q_long_en     <= 0;
        q_long_en_1   <= 0;
        q_long_en_2   <= 0;
        q_long_pkt_indicator <= 0; 
        q_byte_data   <= 0;
        q_byte_data_1 <= 0;
        q_byte_data_2 <= 0;
        q_vc          <= 0;
        q_dt          <= 0;
        q_wc          <= 0;
        q_chksum      <= 16'hFFFF;
    end
    else begin
        q_short_en   <= short_en;
        q_short_en1    <= q_short_en;
        q_long_en    <= long_en;
        q_long_en_1  <= q_long_en;
        q_long_en_2  <= q_long_en_1;
        q_long_pkt_indicator <= (short_en&~q_short_en) ? 0 :
                                (long_en&~q_long_en)   ? 1 : q_long_pkt_indicator;
        q_byte_data    <= byte_data;
        q_byte_data_1  <= q_byte_data;
        q_byte_data_2  <= q_byte_data_1;
        q_vc           <= (short_en&~q_short_en | long_en&~q_long_en) ? vc         : q_vc;
        q_dt           <= (short_en&~q_short_en | long_en&~q_long_en) ? dt         : q_dt;
        q_wc           <= (/*short_en&~*/q_short_en | long_en&~q_long_en) ? wc         : q_wc;
        q_chksum       <= chksum_rdy ? chksum : q_chksum;
    end
    
//calculate ECC
assign PH     = {q_wc[15:0], q_vc, q_dt}; 
assign PH_rev = {PH[0],PH[1],PH[2],PH[3],PH[4],PH[5],PH[6],PH[7],PH[8],PH[9],PH[10],PH[11],PH[12],PH[13],PH[14],PH[15],PH[16],PH[17],PH[18],PH[19],PH[20],PH[21],PH[22],PH[23]};

always @(posedge byte_clk or negedge reset_n)
    if(!reset_n) begin
        q_ECC <= 0;
    end
    else begin
        q_ECC[7:6] <= 2'b00;
        q_ECC[5]   <= (q_short_en1 | q_long_en) ? PH[10]^PH[11]^PH[12]^PH[13]^PH[14]^PH[15]^PH[16]^PH[17]^PH[18]^PH[19]^PH[21]^PH[22]^PH[23]  : q_ECC[5];
        q_ECC[4]   <= (q_short_en1 | q_long_en) ? PH[4]^PH[5]^PH[6]^PH[7]^PH[8]^PH[9]^PH[16]^PH[17]^PH[18]^PH[19]^PH[20]^PH[22]^PH[23]        : q_ECC[4];
        q_ECC[3]   <= (q_short_en1 | q_long_en) ? PH[1]^PH[2]^PH[3]^PH[7]^PH[8]^PH[9]^PH[13]^PH[14]^PH[15]^PH[19]^PH[20]^PH[21]^PH[23]        : q_ECC[3];
        q_ECC[2]   <= (q_short_en1 | q_long_en) ? PH[0]^PH[2]^PH[3]^PH[5]^PH[6]^PH[9]^PH[11]^PH[12]^PH[15]^PH[18]^PH[20]^PH[21]^PH[22]        : q_ECC[2];
        q_ECC[1]   <= (q_short_en1 | q_long_en) ? PH[0]^PH[1]^PH[3]^PH[4]^PH[6]^PH[8]^PH[10]^PH[12]^PH[14]^PH[17]^PH[20]^PH[21]^PH[22]^PH[23] : q_ECC[1];
        q_ECC[0]   <= (q_short_en1 | q_long_en) ? PH[0]^PH[1]^PH[2]^PH[4]^PH[5]^PH[7]^PH[10]^PH[11]^PH[13]^PH[16]^PH[20]^PH[21]^PH[22]^PH[23] : q_ECC[0];
    end
//sets enable for individual PH components
always @(posedge byte_clk or negedge reset_n)
    if(!reset_n) begin
        PH_En       <= 0;
        PH_cnt      <= 0;
        hsSync_En   <= 0;
        DataID_En   <= 0;
        WC_0_En     <= 0;
        WC_1_En     <= 0;
        ECC_En      <= 0; 
        lngpkt_ofst <= 0;   
        cmd2a <= 0;
        cmd2b <= 0; 
    end
    else begin
        PH_En       <= ((short_en & ~q_short_en) | (long_en & ~q_long_en)           ) ? 1           :
                       (PH_cnt==15                                                   ) ? 0           : PH_En;
        PH_cnt      <= (PH_En                        ) ? PH_cnt+1    : 0;
        
        hsSync_En   <= (PH_cnt==1                    )                   ;
        DataID_En   <= (PH_cnt==2                    )                   ;
        WC_0_En     <= (lane_width==1                ) ? (PH_cnt==3) :     //one lane
                       (lane_width==2                ) ? (PH_cnt==2) :     //two lanes    
                       (lane_width==4                ) ? (PH_cnt==2) :  0; //four lanes
        WC_1_En     <= (lane_width==1                ) ? (PH_cnt==4) :     
                       (lane_width==2                ) ? (PH_cnt==3) :     
                       (lane_width==4                ) ? (PH_cnt==2) :  0; 
        ECC_En      <= (lane_width==1                ) ? (PH_cnt==5) :     
                       (lane_width==2                ) ? (PH_cnt==3) :      
                       (lane_width==4                ) ? (PH_cnt==2) :  0;
        lngpkt_ofst <=  long_en&~q_long_en & wc[0] ? 1 :
                        q_short_en                 ? 0 : lngpkt_ofst;
    end
    
assign wc_end_flag   =        (lane_width==1 & lpkt_cnt==(q_wc)-1                   ) ? 1            : 
                              (lane_width==2 & lpkt_cnt==(q_wc>>1)-1                ) ? 1            : 
                              (lane_width==4 & lpkt_cnt==(q_wc>>2)-1                ) ? 1            : 0;   
                              
//starts long packet data transmission
    always @(posedge byte_clk or negedge reset_n)
         if(!reset_n) begin
              lpkt_cnt_En  <= 0;
              lpkt_cnt     <= 0;
              chksum_En    <= 0;
              q_chksum_En  <= 0;
              EoTp_En      <= 0;
         end
         else begin
              lpkt_cnt_En  <= (lane_width==4 & PH_cnt==3     & q_long_pkt_indicator ) ? 1            :  ///NOT UPDATE
                              (lane_width==2 & PH_cnt==4     & q_long_pkt_indicator ) ? 1            :  ///NOT UPDATE
                              (lane_width==1 & PH_cnt==6     & q_long_pkt_indicator ) ? 1            :
                              (wc_end_flag                                          ) ? 0            : lpkt_cnt_En;
              lpkt_cnt     <= (lpkt_cnt_En                                          ) ? lpkt_cnt + 1 : 0;
              chksum_En    <= wc_end_flag ;
              q_chksum_En  <= chksum_En;
              EoTp_En[0]   <= (lane_width==1) ? EoTp & (q_chksum_En | (ECC_En & ~q_long_pkt_indicator)) :
                              (lane_width==2) ? EoTp & (chksum_En | (ECC_En & ~q_long_pkt_indicator)) :
                              (lane_width==4) ? EoTp & (wc_end_flag | (ECC_En & ~q_long_pkt_indicator)) : 0;
              EoTp_En[1]   <= EoTp_En[0];
              EoTp_En[2]   <= (lane_width==1) & EoTp_En[1]/* & lngpkt_ofst*/; 
              EoTp_En[3]   <= EoTp_En[2];
         end
assign fifo_wr_en =  (lane_width==1) ? q_long_en_2 :
                     (lane_width==2) ? q_long_en   : 
                     (lane_width==4) ? long_en   : 0;  /////////////Modified line///////////
assign fifo_rd_en =  bytepkt_en;
assign fifo_wr_data = (lane_width==1) ? q_byte_data_2   : 
                      (lane_width==2) ? q_byte_data     : 
                      (lane_width==4) ? byte_data       : 0;                     
//fifo to hold data until after PH is appended
////PH_DLY_FIFO u_PH_DLY_FIFO(.Data(fifo_wr_data), .WrClock(byte_clk), .RdClock(byte_clk), .WrEn(fifo_wr_en), .RdEn(fifo_rd_en), .Reset(q_bytepkt_en & ~bytepkt_en), .RPReset(q_bytepkt_en & ~bytepkt_en), .Q(byte_data_fifo), .Empty( ), .Full( ));

reg q_fifo_rd_en;
reg [7:0] q_fifo_rd_data_1, q_fifo_rd_data_2, q_fifo_rd_data_3, q_fifo_rd_data_4, q_fifo_rd_data_5;
    always @(posedge byte_clk or negedge reset_n)
        if(!reset_n) begin
            q_fifo_rd_en <=0;
            q_fifo_rd_data_1 <=0;
            q_fifo_rd_data_2 <=0;
            q_fifo_rd_data_3 <=0;
            q_fifo_rd_data_4 <=0;
            q_fifo_rd_data_5 <=0;
        end
        else begin
            q_fifo_rd_en     <= fifo_wr_en;
            q_fifo_rd_data_1 <= q_bytepkt_en & ~bytepkt_en ? 8'h00 : fifo_wr_data;
            q_fifo_rd_data_2 <= q_bytepkt_en & ~bytepkt_en ? 8'h00 : q_fifo_rd_data_1;
            q_fifo_rd_data_3 <= q_bytepkt_en & ~bytepkt_en ? 8'h00 : q_fifo_rd_data_2;
            q_fifo_rd_data_4 <= q_bytepkt_en & ~bytepkt_en ? 8'h00 : q_fifo_rd_data_3;
            q_fifo_rd_data_5 <= q_bytepkt_en & ~bytepkt_en ? 8'h00 : q_fifo_rd_data_4;
        end
assign fifo_rd_en = q_fifo_rd_en;
assign byte_data_fifo = q_fifo_rd_data_5;
             
//put the packet header and data on the bus
    always @(posedge byte_clk or negedge reset_n)
        if(!reset_n) begin
               bytepkt_en   <= 0;
               q_bytepkt_en <= 0;
               bytepkt      <= 8'h00;
               q_byte_data_fifo <= 8'h00;
        end
        else begin
               bytepkt_en   <= hsSync_En | DataID_En | WC_0_En | WC_1_En | ECC_En | lpkt_cnt_En | chksum_En | q_chksum_En | (|EoTp_En);
               q_bytepkt_en <= bytepkt_en;
               q_byte_data_fifo <= byte_data_fifo;               
               bytepkt     <=      hsSync_En   ? 8'hB8                                                     :
                                   DataID_En   ? {q_vc, q_dt}                                              :
                                   WC_0_En     ? q_wc[7:0]                                                 :
                                   WC_1_En     ? q_wc[15:8]                                                :
                                   ECC_En      ? q_ECC                                                     :
///                                   CMD_En      ? (cmd2a? 8'h2a: cmd2b? 8'h2b:8'h3C)                                                     :
                                   lpkt_cnt_En ? ((lpkt_cnt==0)?(cmd2a? 8'h2a: cmd2b? 8'h2b:8'h3C):(cmd2a|cmd2b)?q_cmd2ab_data:q_byte_data_fifo[7:0])                                   : 
                                   chksum_En   ? q_chksum[7:0]                                             : 
                                   q_chksum_En ? q_chksum[15:8]                                             : 
                                   EoTp_En[0]? {q_vc, 6'h08}                                             : 
                                   EoTp_En[1]? {8'h0F}                                                   : 
                                   EoTp_En[2]? {8'h0F}                                                   : 
                                   EoTp_En[3]? {8'h01}                                                   : 0;
       
        end    

endmodule