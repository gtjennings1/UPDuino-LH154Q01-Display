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

module DPRAM (
  input             RSTN    ,
  input             CLK     ,
  input             WR      ,
  input      [7:0]  DIN     ,
  input      [19:0] WADDR   ,
  input             DOUT_EN ,     
  output reg [7:0]  DOUT
);

  parameter      IDLE   = 3'b000;
  parameter      RAM_RD = 3'b010;
  parameter      RAM_WR = 3'b100;

  reg       [2:0]   current_state, next_state;
  reg       [1:0]   ram_read_cnt;
  reg       [15:0]  read_addr_cnt;
  reg       [31:0]  fifo_in;
  reg               fifo_wr;
  reg               fifo_rd_fl;
  reg       [5:0]   ram_rd_fl;
  reg       [15:0]  ram_rdata;

  wire      [31:0]  fifo_out;
  wire              fifo_empty, fifo_aempty;
  wire      [15:0]  ram_rdata0, ram_rdata1, ram_rdata2;
  wire              ram_read_en = (ram_read_cnt == 0) && DOUT_EN;
  wire              fifo_not_empty = !(fifo_empty || fifo_aempty);
  wire              fifo_read = (current_state == RAM_WR);
  wire              ram_rd = (current_state == RAM_RD);
  wire      [13:0]  ram_addr = fifo_rd_fl ? fifo_out[23:10] : read_addr_cnt[13:0];
  wire              ram_wr0 = fifo_rd_fl && (fifo_out[25:24] == 2'b00);
  wire              ram_wr1 = fifo_rd_fl && (fifo_out[25:24] == 2'b01);
  wire              ram_wr2 = fifo_rd_fl && (fifo_out[25:24] == 2'b10);
  wire      [3:0]   ram_wr_mask = {(fifo_out[9:8] == 2'b11),(fifo_out[9:8] == 2'b10),(fifo_out[9:8] == 2'b01),(fifo_out[9:8] == 2'b00)};
  wire      [15:0]  ram_wdata = {fifo_out[7:4], fifo_out[7:4], fifo_out[7:4], fifo_out[7:4]};
  wire              reset_ram_addr_cnt = (read_addr_cnt == 16'd43199);

  always @ (posedge CLK or negedge RSTN)
    begin
      if (!RSTN)
        current_state <= IDLE;
      else
        current_state <= next_state;    
    end
    
  always @ (current_state or ram_read_en or fifo_not_empty)
    begin
      case (current_state)
        IDLE    : begin
                    if (ram_read_en)
                      next_state <= RAM_RD;
                    else
                    if (fifo_not_empty)
                      next_state <= RAM_WR;
                    else
                      next_state <= IDLE;                  
                  end
        RAM_RD  : begin
                    if (fifo_not_empty)
                      next_state <= RAM_WR;
                    else
                      next_state <= IDLE;                 
                  end
        RAM_WR  : begin
                    if (ram_read_en)
                      next_state <= RAM_RD;
                    else
                    if (!fifo_not_empty)
                      next_state <= IDLE;
                    else
                      next_state <= RAM_WR;                  
                  end
        default : next_state <= IDLE;
      endcase
    end  

  always @ (posedge CLK or negedge RSTN)
    begin
      if (!RSTN)
        ram_read_cnt <= 2'b00;
      else
      if (!DOUT_EN)
        ram_read_cnt <= 2'b00;
      else
        ram_read_cnt <= ram_read_cnt + 2'b01;    
    end  

  always @ (posedge CLK or negedge RSTN)
    begin
      if (!RSTN)
        read_addr_cnt <= 16'h0000;
      else
        case ({reset_ram_addr_cnt, ram_rd_fl[1]})
          2'b00   : read_addr_cnt <= read_addr_cnt;
          2'b01   : read_addr_cnt <= read_addr_cnt + 16'h0001;
          2'b10   : read_addr_cnt <= read_addr_cnt;
          2'b11   : read_addr_cnt <= 16'h0000;
          default : read_addr_cnt <= read_addr_cnt;
        endcase          
    end
    
  always @ (posedge CLK or negedge RSTN)
    begin
      if (!RSTN)
        begin
          fifo_in <= 32'h00000000;
          fifo_wr <= 1'b0;
        end  
      else
        begin
          fifo_in <= {4'h0,WADDR,DIN};
          fifo_wr <= WR;
        end      
    end  

  always @ (posedge CLK or negedge RSTN)
    begin
      if (!RSTN)
        fifo_rd_fl <= 1'b0;
      else
        fifo_rd_fl <= fifo_read;    
    end  

  always @ (posedge CLK or negedge RSTN)
    begin
      if (!RSTN)
        ram_rd_fl <= 5'h00;
      else
        ram_rd_fl <= {ram_rd_fl[4:0], ram_rd};    
    end  

  always @ (posedge CLK or negedge RSTN)
    begin
      if (!RSTN)
        ram_rdata <= 16'h0000;
      else
      if (ram_rd_fl[1])
        case (read_addr_cnt[15:14])
          2'b00   : ram_rdata <= ram_rdata0;
          2'b01   : ram_rdata <= ram_rdata1;
          2'b10   : ram_rdata <= ram_rdata2;
          default : ram_rdata <= ram_rdata;
        endcase
      else
        ram_rdata <= ram_rdata;    
    end  
    
  always @ (posedge CLK or negedge RSTN)
    begin
      if (!RSTN)
        DOUT <= 8'h00;
      else
        case (ram_rd_fl[5:2])
          4'b0001 : DOUT <= {ram_rdata[3:0],   4'h0};
          4'b0010 : DOUT <= {ram_rdata[7:4],   4'h0};
          4'b0100 : DOUT <= {ram_rdata[11:8],  4'h0};
          4'b1000 : DOUT <= {ram_rdata[15:12], 4'h0};
          default : DOUT <= DOUT;
        endcase
    end  

  //RAM instantiations
  SB_SPRAM256KA u_spram0 (
    .ADDRESS      ( ram_addr      ), 
    .DATAIN       ( ram_wdata     ), 
    .MASKWREN     ( ram_wr_mask   ),
    .WREN         ( ram_wr0       ),
    .CHIPSELECT   ( 1'b1          ),
    .CLOCK        ( CLK           ),
    .STANDBY      ( 1'b0          ),
    .SLEEP        ( 1'b0          ),
    .POWEROFF     ( 1'b1          ),
    .DATAOUT      ( ram_rdata0    )
    );
    
  SB_SPRAM256KA u_spram1 (
    .ADDRESS      ( ram_addr      ), 
    .DATAIN       ( ram_wdata     ), 
    .MASKWREN     ( ram_wr_mask   ),
    .WREN         ( ram_wr1       ),
    .CHIPSELECT   ( 1'b1          ),
    .CLOCK        ( CLK           ),
    .STANDBY      ( 1'b0          ),
    .SLEEP        ( 1'b0          ),
    .POWEROFF     ( 1'b1          ),
    .DATAOUT      ( ram_rdata1    )
    );

  SB_SPRAM256KA u_spram2 (
    .ADDRESS      ( ram_addr      ), 
    .DATAIN       ( ram_wdata     ), 
    .MASKWREN     ( ram_wr_mask   ),
    .WREN         ( ram_wr2       ),
    .CHIPSELECT   ( 1'b1          ),
    .CLOCK        ( CLK           ),
    .STANDBY      ( 1'b0          ),
    .SLEEP        ( 1'b0          ),
    .POWEROFF     ( 1'b1          ),
    .DATAOUT      ( ram_rdata2    )
    );

  generic_fifo_lfsr wr_fifo (
    .clk      ( CLK         ),
    .nReset   ( RSTN        ),
    .rst      ( 1'b0        ),
    .wreq     ( fifo_wr     ),
    .rreq     ( fifo_read   ),
    .d        ( fifo_in     ),
    .q        ( fifo_out    ),
    .empty    ( fifo_empty  ),
    .full     (             ),
    .aempty   ( fifo_aempty ),
    .afull    (             )
  );
	
	                                       
endmodule