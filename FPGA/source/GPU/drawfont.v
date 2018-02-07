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

module drawfont #(
  
  parameter DATA_WIDTH  = 8           //Parameter for datawidth includes co-ordinates
  
  ) (
  
  input                   clk       , //Clock input
  input                   reset_n   , //Active low reset input
  input                   clk_en    , //Clock enable to slow down output data
  
  input                   enable    , //Trigger to start the function
  
  input  [DATA_WIDTH-1:0] x0        , //Co-ordinate x0
  input  [DATA_WIDTH-1:0] y0        , //Co-ordinate y0
  input  [DATA_WIDTH-1:0] char      , //Character ASCII code
  input  [DATA_WIDTH-1:0] size      , //Character size

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

  reg    [FSM_WIDTH-1:0]  current_state, next_state;
  reg    [DATA_WIDTH-1:0] x0r, y0r, charr, sizer;  
  reg    [DATA_WIDTH-1:0] xk, yk;
    
  reg    [2:0]            row_cnt, col_cnt;
  reg    [10:0]           mem_addr;
  reg    [10:0]           mem_addr_base;
  reg    [7:0]            x_inc, y_inc;
  reg    [7:0]            xk_inc, yk_inc;
  
  reg                     valid_reg, done_reg;
  
  wire   [7:0]            mem_data;
  
  wire                    xk_inc_reset = (xk_inc == (sizer - 8'h01));
  wire                    yk_inc_reset = (yk_inc == (sizer - 8'h01)) && xk_inc_reset;
  wire                    col_cnt_inc = (row_cnt == 3'h7) && yk_inc_reset;
  
  wire                    completed = ((col_cnt==3'h4) && col_cnt_inc && clk_en);  

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
          x0r   <= #UD {DATA_WIDTH{1'b0}};
          y0r   <= #UD {DATA_WIDTH{1'b0}};
          charr <= #UD {DATA_WIDTH{1'b0}};
          sizer <= #UD {DATA_WIDTH{1'b0}};
        end
      else
      if (enable)
        begin
          x0r   <= #UD x0;
          y0r   <= #UD y0;
          charr <= #UD char;
          sizer <= #UD size;
        end
      else
        begin
          x0r   <= #UD x0r;
          y0r   <= #UD y0r;
          charr <= #UD charr;
          sizer <= #UD sizer;
        end        
    end
 
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        mem_addr_base <= #UD 11'h000;
      else
        mem_addr_base <= #UD charr * 3'h5;      
    end
  
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          x_inc <= #UD 8'h00;
          y_inc <= #UD 8'h00;
        end
      else
        begin
          x_inc <= #UD col_cnt * sizer;
          y_inc <= #UD row_cnt * sizer;
        end        
    end
  
  
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          xk       <= #UD {DATA_WIDTH{1'b0}};
          yk       <= #UD {DATA_WIDTH{1'b0}};
          xk_inc   <= #UD {DATA_WIDTH{1'b0}};
          yk_inc   <= #UD {DATA_WIDTH{1'b0}};
          row_cnt  <= #UD 3'h0;
          col_cnt  <= #UD 3'h0;
          mem_addr <= #UD 11'h000;
        end
      else
        case(current_state)
          IDLE    : begin
                      xk       <= #UD {DATA_WIDTH{1'b0}};
                      yk       <= #UD {DATA_WIDTH{1'b0}};          
                      row_cnt  <= #UD 3'h0;
                      col_cnt  <= #UD 3'h0;
                      xk_inc   <= #UD {DATA_WIDTH{1'b0}};
                      yk_inc   <= #UD {DATA_WIDTH{1'b0}};
                      mem_addr <= #UD 11'h000;
                     end
          PREP    : begin
                      xk       <= #UD x0r;
                      yk       <= #UD y0r;          
                      row_cnt  <= #UD 3'h0;
                      col_cnt  <= #UD 3'h0;
                      xk_inc   <= #UD {DATA_WIDTH{1'b0}};
                      yk_inc   <= #UD {DATA_WIDTH{1'b0}};
                      mem_addr <= #UD mem_addr_base;          
                    end
          DRAW    : begin
                      if (clk_en)
                        begin
                          xk       <= #UD x0r + x_inc + xk_inc;
                          yk       <= #UD y0r + y_inc + yk_inc;
                          xk_inc   <= #UD xk_inc_reset ? 8'h00 : xk_inc + 8'h01;
                          yk_inc   <= #UD yk_inc_reset ? 8'h00 : (xk_inc_reset ? yk_inc + 8'h01 : yk_inc);                          
                          row_cnt  <= #UD yk_inc_reset ? row_cnt + 3'h1 : row_cnt;
                          col_cnt  <= #UD col_cnt_inc ? col_cnt + 3'h1 : col_cnt;
                          mem_addr <= #UD col_cnt_inc ? mem_addr + 11'h001 : mem_addr;          
                        end
                      else
                        begin
                          xk       <= #UD xk;
                          yk       <= #UD yk;          
                          xk_inc   <= #UD xk_inc;
                          yk_inc   <= #UD yk_inc;
                          row_cnt  <= #UD row_cnt; 
                          col_cnt  <= #UD col_cnt;
                          mem_addr <= #UD mem_addr;                        
                        end          
                    end
          DONE    : begin
                      xk       <= #UD {DATA_WIDTH{1'b0}};
                      yk       <= #UD {DATA_WIDTH{1'b0}};  
                      xk_inc   <= #UD {DATA_WIDTH{1'b0}};
                      yk_inc   <= #UD {DATA_WIDTH{1'b0}};                      
                      row_cnt  <= #UD 3'h0;	
                      col_cnt  <= #UD 3'h0;
                      mem_addr <= #UD 11'h000;             
                    end
          default : begin
                      xk       <= #UD {DATA_WIDTH{1'b0}};
                      yk       <= #UD {DATA_WIDTH{1'b0}};    
                      xk_inc   <= #UD {DATA_WIDTH{1'b0}};
                      yk_inc   <= #UD {DATA_WIDTH{1'b0}};                      
                      row_cnt  <= #UD 3'h0;	
                      col_cnt  <= #UD 3'h0;
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
                          valid_reg <= #UD mem_data[row_cnt];//1'b1;
						            else
						              valid_reg <= #UD 1'b0;
                        done_reg  <= #UD 1'b0;
                      end
            DRAW    : begin
                        if (clk_en)
                          valid_reg <= #UD mem_data[row_cnt];//1'b1;
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
 
  ebr_font_mem font_rom (
    .clk   (clk),
    .addr  (mem_addr),
    .data  (mem_data)
  );  
  
endmodule  