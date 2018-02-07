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

#include "Adafruit_GFX.h"
#include "gfxfont.h"
#include "bitmap.h"

Adafruit_GFX tft = Adafruit_GFX(240, 240);

unsigned int i;
long time_stamp;



void setup(){

  Serial.begin(1000000);
  Serial.write(0x00);
  Serial.write(0x20);
  time_stamp = millis();
  while((millis() - time_stamp) < 100);   


  tft.fillScreen(0x0000);
  tft.fillCircle(120,40, 39, 0xF00);
  tft.drawBitmap(88, 8, mailBM, 64 , 64, 0xFFF);  
  tft.fillCircle(40,75, 39, 0xAA0);
  tft.drawBitmap(8, 43, msgBM, 64 , 64, 0xFFF);  
  tft.fillCircle(40,165, 39, 0x2E0);
  tft.drawBitmap(8, 133, walkBM, 64 , 64, 0xFFF);  
  tft.fillCircle(120,200, 39, 0x0F8);
  tft.drawBitmap(88, 168, callBM, 64 , 64, 0xFFF);  
  tft.fillCircle(200,165, 39, 0x02E);
  tft.drawBitmap(168, 133, locBM, 64 , 64, 0xFFF);  
  tft.fillCircle(200,75, 39, 0xA0A);
  tft.drawBitmap(168, 43, timerBM, 64 , 64, 0xFFF);
  i=0;   
}

void loop(){
  
  delay(2000);
  switch(i)
  {
    case 0  :  tft.fillCircle(200,75, 39, 0xA0A);
               tft.drawBitmap(168, 43, timerBM, 64 , 64, 0xFFF);
               tft.fillCircle(120,40, 39, 0xFFF);
               tft.drawBitmap(88, 8, mailBM, 64 , 64, 0x000);
               i++;
               break;
    case 1  :  tft.fillCircle(120,40, 39, 0xF00);
               tft.drawBitmap(88, 8, mailBM, 64 , 64, 0xFFF);
               tft.fillCircle(40,75, 39, 0xFFF);
               tft.drawBitmap(8, 43, msgBM, 64 , 64, 0x000);
               i++;
               break;
    case 2  :  tft.fillCircle(40,75, 39, 0xAA0);
               tft.drawBitmap(8, 43, msgBM, 64 , 64, 0xFFF);
               tft.fillCircle(40,165, 39, 0xFFF);
               tft.drawBitmap(8, 133, walkBM, 64 , 64, 0x000); 
               i++;
               break;
    case 3  :  tft.fillCircle(40,165, 39, 0x2E0);
               tft.drawBitmap(8, 133, walkBM, 64 , 64, 0xFFF); 
               tft.fillCircle(120,200, 39, 0xFFF);
               tft.drawBitmap(88, 168, callBM, 64 , 64, 0x000);
               i++;
               break;
    case 4  :  tft.fillCircle(120,200, 39, 0x0F8);
               tft.drawBitmap(88, 168, callBM, 64 , 64, 0xFFF);
               tft.fillCircle(200,165, 39, 0xFFF);
               tft.drawBitmap(168, 133, locBM, 64 , 64, 0x000); 
               i++;
               break;
    case 5  :  tft.fillCircle(200,165, 39, 0x02E);
               tft.drawBitmap(168, 133, locBM, 64 , 64, 0xFFF); 
               tft.fillCircle(200,75, 39, 0xFFF);
               tft.drawBitmap(168, 43, timerBM, 64 , 64, 0x000);
               i=0;
               break;                                                                           
    default :  tft.fillCircle(200,165, 39, 0x02E);
               tft.drawBitmap(168, 133, locBM, 64 , 64, 0xFFF); 
               tft.fillCircle(200,75, 39, 0xFFF);
               tft.drawBitmap(168, 43, timerBM, 64 , 64, 0x000);
               i=0;
               break;
  }
      
}
