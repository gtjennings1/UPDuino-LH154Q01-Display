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
#include "FreeSans9pt7b.h"
#include "FreeSansBold12pt7b.h"
#include "bitmap.h"

Adafruit_GFX tft = Adafruit_GFX(240, 240);

unsigned int i, j, fg;
int k;
long time_stamp;
String stringText;
  

void setup(){

  Serial.begin(1000000);
  Serial.write(0x00);
  Serial.write(0x20);
  time_stamp = millis();
  while((millis() - time_stamp) < 100); 

  tft.fillScreen(0x0000);
    
  tft.drawBitmap(56, 56, call2BM, 128 , 128, 0x22F);

  stringText = "Gnarly Grey";
  tft.setFont(&FreeSansBold12pt7b); 
  tft.setTextSize(1);
  tft.setCursor(50, 210); 
  tft.print(stringText); 

  stringText = "INCOMING CALL";
  tft.setFont(&FreeSans9pt7b); 
  tft.setCursor(47, 40);
  tft.setTextColor(0x0000, 0x000);
  tft.setTextSize(1);
  tft.print(stringText);

  tft.drawTriangle(184,115, 184,125, 193,120, 0x0F0);
  tft.drawTriangle(194,115, 194,125, 203,120, 0x0F0);
  tft.drawTriangle(204,115, 204,125, 213,120, 0x0F0);
  tft.fillTriangle(214,115, 214,125, 223,120, 0x0F0);

  tft.drawTriangle(55,115, 55,125, 46,120, 0xF00);
  tft.drawTriangle(45,115, 45,125, 36,120, 0xF00);
  tft.drawTriangle(35,115, 35,125, 26,120, 0xF00);
  tft.fillTriangle(25,115, 25,125, 16,120, 0xF00);
  i=0; 
  j=0;  
  k=1;
}

void loop(){

  tft.setCursor(47, 40);
  fg = ((j&0xF)<<8) | ((j&0xF)<<4) | ((j&0xF));
  tft.setTextColor(fg , 0x000); 
  tft.print(stringText);
  switch ((i&0x6)>>1)
  { 
    case 0  :   tft.drawTriangle(184,115, 184,125, 193,120, 0x0F0);
                tft.drawTriangle(194,115, 194,125, 203,120, 0x0F0);
                tft.fillTriangle(204,115, 204,125, 213,120, 0x000);
                tft.drawTriangle(204,115, 204,125, 213,120, 0x0F0);
                tft.fillTriangle(214,115, 214,125, 223,120, 0x0F0);
              
                tft.drawTriangle(55,115, 55,125, 46,120, 0xF00);
                tft.drawTriangle(45,115, 45,125, 36,120, 0xF00);
                tft.fillTriangle(35,115, 35,125, 26,120, 0x000);
                tft.drawTriangle(35,115, 35,125, 26,120, 0xF00);
                tft.fillTriangle(25,115, 25,125, 16,120, 0xF00);
                break;
    case 1  :   tft.fillTriangle(184,115, 184,125, 193,120, 0x0F0);
                tft.drawTriangle(194,115, 194,125, 203,120, 0x0F0);
                tft.drawTriangle(204,115, 204,125, 213,120, 0x0F0);
                tft.fillTriangle(214,115, 214,125, 223,120, 0x000);
                tft.drawTriangle(214,115, 214,125, 223,120, 0x0F0);
              
                tft.fillTriangle(55,115, 55,125, 46,120, 0xF00);
                tft.drawTriangle(45,115, 45,125, 36,120, 0xF00);
                tft.drawTriangle(35,115, 35,125, 26,120, 0xF00);
                tft.fillTriangle(25,115, 25,125, 16,120, 0x000);
                tft.drawTriangle(25,115, 25,125, 16,120, 0xF00);
                break;
    case 2  :   tft.fillTriangle(184,115, 184,125, 193,120, 0x000);
                tft.drawTriangle(184,115, 184,125, 193,120, 0x0F0);
                tft.fillTriangle(194,115, 194,125, 203,120, 0x0F0);
                tft.drawTriangle(204,115, 204,125, 213,120, 0x0F0);
                tft.drawTriangle(214,115, 214,125, 223,120, 0x0F0);
              
                tft.fillTriangle(55,115, 55,125, 46,120, 0x000);
                tft.drawTriangle(55,115, 55,125, 46,120, 0xF00);
                tft.fillTriangle(45,115, 45,125, 36,120, 0xF00);
                tft.drawTriangle(35,115, 35,125, 26,120, 0xF00);
                tft.drawTriangle(25,115, 25,125, 16,120, 0xF00);
                break;
    case 3  :   tft.drawTriangle(184,115, 184,125, 193,120, 0x0F0);
                tft.fillTriangle(194,115, 194,125, 203,120, 0x000);
                tft.drawTriangle(194,115, 194,125, 203,120, 0x0F0);
                tft.fillTriangle(204,115, 204,125, 213,120, 0x0F0);
                tft.drawTriangle(214,115, 214,125, 223,120, 0x0F0);
              
                tft.drawTriangle(55,115, 55,125, 46,120, 0xF00);
                tft.fillTriangle(45,115, 45,125, 36,120, 0x000);
                tft.drawTriangle(45,115, 45,125, 36,120, 0xF00);
                tft.fillTriangle(35,115, 35,125, 26,120, 0xF00);
                tft.drawTriangle(25,115, 25,125, 16,120, 0xF00);
                break;
    default :   tft.drawTriangle(184,115, 184,125, 193,120, 0x0F0);
                tft.drawTriangle(194,115, 194,125, 203,120, 0x0F0);
                tft.drawTriangle(204,115, 204,125, 213,120, 0x0F0);
                tft.fillTriangle(214,115, 214,125, 223,120, 0x0F0);
              
                tft.drawTriangle(55,115, 55,125, 46,120, 0xF00);
                tft.drawTriangle(45,115, 45,125, 36,120, 0xF00);
                tft.drawTriangle(35,115, 35,125, 26,120, 0xF00);
                tft.fillTriangle(25,115, 25,125, 16,120, 0xF00);
                break;
  }

  i++;
  if (j==15)
    k = -1;
  if (j==0)
    k = 1;
  j=j+k;  
    
}

