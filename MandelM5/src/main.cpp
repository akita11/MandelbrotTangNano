#include <Arduino.h>
#include <M5Stack.h>
#include <Wire.h>

// convert float to Q12-formatted 16bit binary
uint16_t float2q12(float a)
{
  uint16_t i, f, d;
  float aa;
  if (a > 0) aa = a; else aa = -a;
  i = (byte)(aa);
  f = (uint16_t)((aa - (byte)aa) * 4096);
  d = (i << 12)| f;
  if (a < 0) d = ~d + 1;
  return(d);
}

void send_word(uint16_t d)
{
  Serial2.write(d >> 8);
  Serial2.write(d & 0xff);
}

uint8_t f = 0;
uint8_t jx0, jy0;

#define X 240
#define Y 160

float width = 3;
float xs = -2.0;
float ys = -1.0;
float dp = 0.0125;

void setup() {
  M5.begin();
  Serial.begin(115200);
  Serial2.begin(921600, SERIAL_8N1, 16, 17);
  Serial2.setRxBufferSize(65536);

  Wire.begin();
  for (int i = 0; i < 5; i++){
    Wire.requestFrom(0x52, 3);
    while(Wire.available()){
      jx0 = Wire.read(); jy0 = Wire.read(); Wire.read();
    }
  }
}

int x, y;

void start_calc()
{
  Serial2.write(X);
  Serial2.write(Y);
  dp = width / (float)X;
  send_word(float2q12(xs));
  send_word(float2q12(ys));
  send_word(float2q12(dp));
  send_word(float2q12(dp));
  x = 0; y = 0; f = 1;
  M5.Lcd.clear(BLACK);
  Serial.println("Settings:");
  Serial.print("x: "); Serial.print(xs);
  Serial.print(" - "); Serial.println(xs + width);
  Serial.print("y: "); Serial.print(ys);
  Serial.print(" - "); Serial.println(ys + width*2.0/3.0);
  Serial.println(dp);
  Serial.println(width);
}

uint8_t fj = 0;

void loop() {
  Wire.requestFrom(0x52, 3);
  if (Wire.available()){
    uint8_t jx, jy;
    jx = Wire.read(); jy = Wire.read(); Wire.read();
#define JOY_TH 30
    if (jx < jx0 - JOY_TH && fj == 0){ xs -= dp * (X/4); start_calc(); fj = 1;}
    if (jx > jx0 + JOY_TH && fj == 0){ xs += dp * (X/4); start_calc(); fj = 1;}
    if (jy < jy0 - JOY_TH && fj == 0){ ys -= dp * (Y/4); start_calc(); fj = 1;}
    if (jy > jy0 + JOY_TH && fj == 0){ ys += dp * (Y/4); start_calc(); fj = 1;}
    if (fj == 1 
        && jx < jx0 + JOY_TH && jx > jx0 - JOY_TH
        && jy < jy0 + JOY_TH && jy > jy0 - JOY_TH) fj = 0;
  }

  M5.update();
  if (M5.BtnB.wasReleased()) { // reset position
    xs = -2.0; ys = -1.0; width = 3.0; start_calc();
  }
  #define MAG_STEP 1.5
  if (M5.BtnC.wasReleased()) { // zoom-out
    float xc, yc;
    xc = xs + (width / 2.0); yc = ys + (width / 3.0);
    Serial.println(xc); Serial.println(yc);
    width = width / MAG_STEP;
    dp = dp / MAG_STEP;
    xs = xc - (width / 2.0); ys = yc - (width / 3.0);
    start_calc();
  }
  if (M5.BtnA.wasReleased()) { // zoom-in
    float xc, yc;
    xc = xs + (width / 2.0); yc = ys + (width / 3.0);
    Serial.println(xc); Serial.println(yc);
    width = width * MAG_STEP;
    dp = dp * MAG_STEP;
    xs = xc - (width / 2.0); ys = yc - (width / 3.0);
    start_calc();
  }


  while(Serial2.available()){
    byte d = Serial2.read();
    if (f == 1){
      if (d == 0x64) M5.Lcd.drawPixel(x, y, BLACK);
      else{
        switch(d % 7){
          case 0 : M5.lcd.drawPixel(x, y, BLUE); break;
          case 1 : M5.lcd.drawPixel(x, y, RED); break;
          case 2 : M5.lcd.drawPixel(x, y, MAGENTA); break;
          case 3 : M5.lcd.drawPixel(x, y, GREEN); break;
          case 4 : M5.lcd.drawPixel(x, y, CYAN); break;
          case 5 : M5.lcd.drawPixel(x, y, YELLOW); break;
          case 6 : M5.lcd.drawPixel(x, y, WHITE); break;
        }
      }
      y++; if (y == Y){ y = 0; x++; if (x == X){ x = 0; f = 0; } }
    }
  }
}
