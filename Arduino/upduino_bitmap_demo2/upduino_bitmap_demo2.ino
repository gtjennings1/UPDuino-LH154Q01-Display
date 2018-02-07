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


}

void loop(){

  i=random(9);
  switch(i)
  { 
    case 0  : tft.drawRGBBitmap(12,12, candyCBM, 64, 64);
              break;
    case 1  : tft.drawRGBBitmap(88,12, candyCBM, 64, 64);
              break;
    case 2  : tft.drawRGBBitmap(164,12, candyCBM, 64, 64);
              break;
    case 3  : tft.drawRGBBitmap(12,88, candyCBM, 64, 64);
              break;
    case 4  : tft.drawRGBBitmap(88,88, candyCBM, 64, 64);
              break;
    case 5  : tft.drawRGBBitmap(164,88, candyCBM, 64, 64);
              break;
    case 6  : tft.drawRGBBitmap(12,164, candyCBM, 64, 64);
              break;
    case 7  : tft.drawRGBBitmap(88,164, candyCBM, 64, 64);
              break;
    case 8  : tft.drawRGBBitmap(164,164, candyCBM, 64, 64);
              break;                                                                                                            
    default : tft.drawRGBBitmap(164,164, candyCBM, 64, 64);
              break;
  }
  i=random(9);
  switch(i)
  { 
    case 0  : tft.drawRGBBitmap(12,12, cblossomCBM, 64, 64);
              break;
    case 1  : tft.drawRGBBitmap(88,12, cblossomCBM, 64, 64);
              break;
    case 2  : tft.drawRGBBitmap(164,12, cblossomCBM, 64, 64);
              break;
    case 3  : tft.drawRGBBitmap(12,88, cblossomCBM, 64, 64);
              break;
    case 4  : tft.drawRGBBitmap(88,88, cblossomCBM, 64, 64);
              break;
    case 5  : tft.drawRGBBitmap(164,88, cblossomCBM, 64, 64);
              break;
    case 6  : tft.drawRGBBitmap(12,164, cblossomCBM, 64, 64);
              break;
    case 7  : tft.drawRGBBitmap(88,164, cblossomCBM, 64, 64);
              break;
    case 8  : tft.drawRGBBitmap(164,164, cblossomCBM, 64, 64);
              break;                                                                                                            
    default : tft.drawRGBBitmap(164,164, cblossomCBM, 64, 64);
              break;
  }  
  
      
}
