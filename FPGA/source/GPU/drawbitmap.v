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

`timescale 1 ns/1 ns

module drawbitmap #(
  
  parameter DATA_WIDTH  = 8           //Parameter for datawidth includes co-ordinates
  
  ) (
  
  input                   clk       , //Clock input
  input                   reset_n   , //Active low reset input
  input                   clk_en    , //Clock enable to slow down output data
  
  input                   enable    , //Trigger to start the function
  
  input  [DATA_WIDTH-1:0] x0        , //Co-ordinate x0
  input  [DATA_WIDTH-1:0] y0        , //Co-ordinate y0
  input  [DATA_WIDTH-1:0] bm_no     , //Bitmap number

  output                  valid     , //Output data valid
  output                  done      , //Feedback of task completion  

  output [DATA_WIDTH-1:0] x_o       , //X co-ordinate output
  output [DATA_WIDTH-1:0] y_o         //Y co-ordinate output  
  );
  
  parameter UD = 1;  
  parameter FSM_WIDTH = 4;
  parameter IDLE = 4'b0001;
  parameter PREP = 4'b0010;
  parameter DRAW = 4'b0100;
  parameter DONE = 4'b1000;
  
  parameter BM_WIDTH  = 8'd64;
  parameter BM_HEIGHT = 8'h64;

  reg    [FSM_WIDTH-1:0]  current_state, next_state;
  reg    [DATA_WIDTH-1:0] x0r, y0r, bmnr;  
  reg    [DATA_WIDTH-1:0] xk, yk;
    
  reg    [2:0]            bit_cnt;
  reg    [8:0]            mem_addr;
  
  reg                     valid_reg, done_reg;
  
  wire   [7:0]            mem_data;
  
  wire                    completed = ((mem_addr==9'h1FF) && (bit_cnt==3'h7) && clk_en);  

  assign                  valid = valid_reg;
  assign                  done = done_reg;  
  
  assign                  x_o = xk;
  assign                  y_o = yk;  

  //FSM to keep track of function activity
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        current_state <= #UD IDLE;
      else
        current_state <= #UD next_state;  
    end    
 
  always @ (current_state or enable or completed or clk_en)
    begin
      case(current_state)
        IDLE    : begin
                    if (enable)
                      next_state <= #UD PREP;
                    else
                      next_state <= #UD IDLE;                    
                  end
        PREP    : begin
			              if (clk_en)
					            next_state <= #UD DRAW;
					          else  
                      next_state <= #UD PREP;
                  end        
        DRAW    : begin
                    if (completed)
                      next_state <= #UD DONE;
                    else
                      next_state <= #UD DRAW;                    
                  end
        DONE    : begin
                    next_state <= #UD IDLE;
                  end
        default : begin
                    next_state <= #UD IDLE;
                  end        
      endcase
    end

  //Store necessary parameters for function in internal registers
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          x0r  <= #UD {DATA_WIDTH{1'b0}};
          y0r  <= #UD {DATA_WIDTH{1'b0}};
          bmnr <= #UD {DATA_WIDTH{1'b0}};
        end
      else
      if (enable)
        begin
          x0r  <= #UD x0;
          y0r  <= #UD y0;
          bmnr <= #UD bm_no;
        end
      else
        begin
          x0r  <= #UD x0r;
          y0r  <= #UD y0r;
          bmnr <= #UD bmnr;
        end        
    end
  
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          xk       <= #UD {DATA_WIDTH{1'b0}};
          yk       <= #UD {DATA_WIDTH{1'b0}};
          bit_cnt  <= #UD 3'h0;
          mem_addr <= #UD 9'h000;
        end
      else
        case(current_state)
          IDLE    : begin
                      xk       <= #UD {DATA_WIDTH{1'b0}};
                      yk       <= #UD {DATA_WIDTH{1'b0}};          
                      bit_cnt  <= #UD 3'h0;
                      mem_addr <= #UD 9'h000;
                     end
          PREP    : begin
                      xk       <= #UD x0r;
                      yk       <= #UD y0r;          
                      bit_cnt  <= #UD 3'h0;
                      mem_addr <= #UD 9'h000;          
                    end
          DRAW    : begin
                      if (clk_en)
                        begin
                          xk       <= #UD x0r + {2'b00, mem_addr[2:0], bit_cnt};
                          yk       <= #UD y0r + {2'b00, mem_addr[8:3]};          
                          bit_cnt  <= #UD bit_cnt + 3'h1;
                          mem_addr <= #UD (bit_cnt == 3'h7) ? mem_addr + 9'h001 : mem_addr;          
                        end
                      else
                        begin
                          xk       <= #UD xk;
                          yk       <= #UD yk;          
                          bit_cnt  <= #UD bit_cnt;
                          mem_addr <= #UD mem_addr;                        
                        end          
                    end
          DONE    : begin
                      xk       <= #UD {DATA_WIDTH{1'b0}};
                      yk       <= #UD {DATA_WIDTH{1'b0}};          
                      bit_cnt  <= #UD 3'h0;
                      mem_addr <= #UD 9'h000;             
                    end
          default : begin
                      xk       <= #UD {DATA_WIDTH{1'b0}};
                      yk       <= #UD {DATA_WIDTH{1'b0}};          
                      bit_cnt  <= #UD 3'h0;
                      mem_addr <= #UD 9'h000;             
                    end                              
        endcase        
    end    

  //Handle valid and done signal
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          valid_reg <= #UD 1'b0;
          done_reg  <= #UD 1'b0;
        end
      else
        begin
          case (current_state)
            IDLE    : begin
                        valid_reg <= #UD 1'b0;
                        done_reg  <= #UD 1'b0;           
                      end            
            PREP    : begin
				                if (clk_en)
                          valid_reg <= #UD mem_data[~bit_cnt];//1'b1;
						            else
						              valid_reg <= #UD 1'b0;
                        done_reg  <= #UD 1'b0;
                      end
            DRAW    : begin
                        if (clk_en)
                          valid_reg <= #UD mem_data[~bit_cnt];//1'b1;
                        else
                          valid_reg <= #UD 1'b0;                        
                        done_reg  <= #UD 1'b0;            
                      end
            DONE    : begin
                        valid_reg <= #UD 1'b0;
                        done_reg  <= #UD 1'b1;            
                      end
            default : begin
                        valid_reg <= #UD 1'b0;
                        done_reg  <= #UD 1'b0;            
                      end
          endcase
        end        
    end      
 
  ebr_bm_mem bm_rom (
    .clk   (clk),
    .bm_no (bmnr[4:0]),
    .addr  (mem_addr),
    .data  (mem_data)
  );
  
endmodule  