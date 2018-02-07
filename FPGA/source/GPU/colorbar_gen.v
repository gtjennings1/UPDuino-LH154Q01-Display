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


module colorbar_gen #(
    parameter h_active      = 'd1920     ,
    parameter h_total       = 'd2200     ,
    parameter v_active      = 'd1080     ,
    parameter v_total       = 'd1125     ,
    parameter H_FRONT_PORCH =   'd88     ,
    parameter H_SYNCH       =   'd44     ,
    parameter H_BACK_PORCH  =  'd148     ,
    parameter V_FRONT_PORCH =    'd4     ,
    parameter V_SYNCH       =    'd5     ,
    parameter mode          =     0         //0 = colorbar, 1 = walking 1's
)
( 
    input                     rstn       , 
    input                     pixclk , 
    output         reg        fv         , 
    output  reg               lv         , 
    output  reg [7:0]         data       ,
    //input  system_down,
    //input ini_done,
    output         reg        vsync      ,
    output         reg        hsync      ,
    output                    de
        
); 
 
    reg [11:0] pixcnt; 
    reg [11:0] linecnt;
    reg [11:0] color_cntr;	
    reg [1:0] rgb_cntr;
    reg [7:0] vsync_cnt;
    reg q_lv;
    reg [15:0] q_lv_cnt;


    always @(posedge pixclk or negedge rstn) begin 
       if (!rstn) begin 
          color_cntr <= 12'd00;
          q_lv       <= 0;
          q_lv_cnt   <= 0;
       	  pixcnt     <= 12'd0; 
       	  rgb_cntr   <= 2'd0;
       	  data       <= 24'd0;        	  
       	  linecnt    <= 12'd0;
       	  lv        <= 1'b0;  
       	  fv        <= 1'b0;                                             
          hsync     <= 1'b0;
          vsync     <= 1'b0; 
          vsync_cnt <= 8'd0;        
       end                                   
       else begin 
          color_cntr <= lv ? color_cntr+1 : 0;
          q_lv <= lv;
          q_lv_cnt <= fv ? (q_lv_cnt<'d240) ? q_lv_cnt+(~lv & q_lv) : 'd0 : 'd0;
          pixcnt    <= pixcnt < h_total ? pixcnt+1 : 0;	   
		  
		  rgb_cntr   <= ~lv | rgb_cntr==2'd2 ? 0            : rgb_cntr+1;
		  data       <= q_lv_cnt < 'd80 ?   
		                               (rgb_cntr==2'b00) ? 8'h00 :
                                       (rgb_cntr==2'b01) ? 8'h00 : 8'hF0 :		  
		                q_lv_cnt < 'd160 ?
		                               (rgb_cntr==2'b00) ? 8'h00 :
                                       (rgb_cntr==2'b01) ? 8'hF0 : 8'h00 :		                
		                               
		                               (rgb_cntr==2'b00) ? 8'hF0 :
                                       (rgb_cntr==2'b01) ? 8'h00 : 8'h00 ;     
		  
		                /*vsync_cnt[6:5]==2'b00 ? 
		                               (rgb_cntr==2'b00) ? 8'h00 :
                                       (rgb_cntr==2'b01) ? 8'h00 : 8'hF0 :
                        vsync_cnt[6:5]==2'b01 ? 
		                               (rgb_cntr==2'b00) ? 8'h00 :
                                       (rgb_cntr==2'b01) ? 8'hF0 : 8'h00 :
                        vsync_cnt[6:5]==2'b10 ? 
		                               (rgb_cntr==2'b00) ? 8'hF0 :
                                       (rgb_cntr==2'b01) ? 8'h00 : 8'h00 :                                       
		                color_cntr<240                         ? 
                                       (rgb_cntr==2'b00) ? 8'h00 :
                                       (rgb_cntr==2'b01) ? 8'h00 : 8'hF0 :
                        color_cntr<480                         ?       
                                       (rgb_cntr==2'b00) ? 8'h00 :
                                       (rgb_cntr==2'b01) ? 8'hF0 : 8'h00 :
                                       
                                       (rgb_cntr==2'b00) ? 8'hF0 :
                                       (rgb_cntr==2'b01) ? 8'h00 : 8'h00 ;*/	
         	                 
          linecnt   <= (linecnt==v_total-1 && pixcnt ==h_total-1)  ? 0         :  
                       (linecnt< v_total-1 && pixcnt ==h_total-1)  ? linecnt+1 : linecnt; 
  	            
       	  lv        <= (pixcnt<h_active) & (linecnt>=v_total-v_active);
     
       	  fv        <= (linecnt>=v_total-v_active);

       	  hsync     <= (pixcnt>=H_FRONT_PORCH)   & (pixcnt<H_FRONT_PORCH+H_SYNCH) & (linecnt>=v_total-v_active); 
       	               	   
          vsync     <= (linecnt>=V_FRONT_PORCH) & (linecnt<V_FRONT_PORCH+V_SYNCH); 
          vsync_cnt <=  linecnt==V_FRONT_PORCH & (pixcnt==H_FRONT_PORCH) ? vsync_cnt+1 : vsync_cnt; 	   
       end 
    end   

    assign de = (lv & rgb_cntr==0);   
 	      
endmodule                  