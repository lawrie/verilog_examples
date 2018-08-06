#include <EEPROM.h>
#include <SPI.h>
#include <GD2.h>
#include <MyStorm.h>
#include <QSPI.h>

#define NUM_SAMPLES 16384
#define QSPI_CHUNK 1
#define W 480
#define H 272
#define CHUNK_SIZE 1024

// The samples
static signed char samples[NUM_SAMPLES];

#define MAX_POINTS 1500

// Interrupt flag
volatile bool dataFlag = false;

// Parameters to send to FPGA
static signed char parameters[14];

//FFT stuff------------------------------------------------------------------
#define FFTLEN 1024
#include "cr4_fft_1024_stm32.h"
uint16_t data16[FFTLEN];
uint32_t data32[FFTLEN];
uint32_t y[FFTLEN];
uint16_t hammingwindow[FFTLEN/2];
uint16_t bins = FFTLEN;

void init_hamming_window(uint16_t * windowtarget, int len){
  for(int i = 0;i<len/2; i++){ windowtarget[i] = (0.54 - 0.46 * cos((2 * i * 3.141592)/(len-1))) * 65536; }
}
  
void window(uint32_t * data, uint16_t * weights, int len, int scale){
  for(int i =0; i<len; i++){
    int weight_index = i;
    if( i > len/2 ) weight_index = len-i;
    data[i] = ((data[i] * scale * weights[weight_index]) >> 16) & 0xFFFF;
  }
}

uint16_t asqrt(uint32_t x) { //good enough precision, 10x faster than regular sqrt
  /*      From http://medialab.freaknet.org/martin/src/sqrt/sqrt.c
   *   Logically, these are unsigned. We need the sign bit to test
   *   whether (op - res - one) underflowed.
   */
  int32_t op, res, one;

  op = x;
  res = 0;
  /* "one" starts at the highest power of four <= than the argument. */
  one = 1 << 30;   /* second-to-top bit set */
  while (one > op) one >>= 2;
  while (one != 0) {
    if (op >= res + one) {
      op = op - (res + one);
      res = res +  2 * one;
    }
    res /= 2;
    one /= 4;
  }
  return (uint16_t) (res);
}

void fill(uint32_t * data, uint32_t value, int len){
  for (int i =0; i< len;i++) data[i]=value;
}

void fill(uint16_t * data, uint32_t value, int len){
  for (int i =0; i< len;i++) data[i]=value;
}

void real_to_complex(uint16_t * in, uint32_t * out, int len){
  for (int i = 0;i<len;i++) out[i]=in[i]*8;
}

void generate_squarewave_data(uint16_t * data, uint32_t period, uint32_t amplitude, int len){
  for (int i =0; i< len;i++){
    if ((i/(period/2)) & 1 ==1){
    data[i] = amplitude;
  }else{
    data[i]= 0;
    }
  }
}

void generate_sawtoothwave_data(uint16_t * data, uint32_t period, uint32_t amplitude, int len){
  for (int i =0; i< len;i++){
    data[i] = (i - period * (int (i/period))) * (amplitude/period);
  }
}

void selftest(){
  Serial.println("Performing self FFT test");
  generate_sawtoothwave_data(data16,64, 1337, FFTLEN);
  real_to_complex(data16, data32, FFTLEN);
  uint32_t fft_micros = perform_fft(data32, y, FFTLEN);
  Serial.print("FFT took (micros): ");
  Serial.println(fft_micros);
  printdataset(data32,FFTLEN,0);
  printdataset(y,FFTLEN,1024);
}

void inplace_magnitude(uint32_t * target, uint16_t len){
  uint16_t * p16;
  for (int i=0;i<len;i++){
     int16_t real = target[i] & 0xFFFF;
     int16_t imag = target[i] >> 16;
     uint32_t magnitude = asqrt(real*real + imag*imag);
     target[i] = magnitude; 
  }
}

float bin_frequency(uint32_t samplerate, uint32_t binnumber, uint32_t len){
  return (binnumber*samplerate)/((float)len);
}
  
uint32_t perform_fft(uint32_t * indata, uint32_t * outdata,const int len){
  uint32_t timetaken = micros();
  //window(indata,hammingwindow,len,8); //scaling factor of 4 for 4095> 16 bits
  cr4_fft_1024_stm32(outdata,indata,len);
  inplace_magnitude(outdata,len);
  return micros() - timetaken;
}

void printdataset(uint32_t * data, int len, int samplerate){
  Serial.println("Printing dataset");
  if (samplerate > 0){
    Serial.println("Bin#  freq  mag");
    for (int i =0; i< len; i++){
      Serial.print(i);
      Serial.print("  ");
      Serial.print(bin_frequency(samplerate,i,len));
      Serial.print("  ");
      Serial.println(data[i]);
    }
  }else{
    Serial.println("i value");
    for (int i =0; i< len; i++){
      Serial.print(i);
      Serial.print("  ");
      Serial.println(data[i]);
    }
  } 
}

void printdata16(uint16_t * data, int len) {
  Serial.println("i value");
  for (int i =0; i< len; i++){
    Serial.print(i);
    Serial.print("  ");
    Serial.println(data[i]);
  } 
}

void drawFFT(int start) {
  long points = 0;
  GD.Begin(LINES);
  GD.PointSize(32);


  for(int i=0;i<=FFTLEN;i++) 
    data16[i] = ((int) samples[start+i] + 128) * 40;
  real_to_complex(data16, data32, FFTLEN);
  uint32_t fft_micros = perform_fft(data32, y, FFTLEN);

  for(int i=0;i<480;i++) {
    unsigned int yy = y[i+2]/10;
    if (yy > 230) yy = 230;
    if (points+= 3 > MAX_POINTS) return;
    uint8_t blue = 255 - yy;
    uint8_t red = yy * 2;
    GD.ColorRGB((red << 16) | blue);
    GD.Vertex2ii(i,245);
    GD.Vertex2ii(i,245 - yy); 
  } 
}

void setup() {
  Serial.begin(9600);

  //initialize FFT variables
  init_hamming_window(hammingwindow,FFTLEN);
  fill(y,0,FFTLEN);
  fill(data32,1,FFTLEN);
  fill(data16,1,FFTLEN);
   
  selftest();

   // Configure any bitstream in flash memory
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, 1);
  myStorm.FPGAConfigure((const byte*)0x0801F000, 135100);
  digitalWrite(LED_BUILTIN, 0);

  // Start Gameduino, QSPI and interupts
  GD.begin();
  attachInterrupt(PIN_BUTTON2, dataReady, FALLING);
  QSPI.begin(40000000, QSPI.Mode3);
  QSPI.beginTransaction();
}

char n = 0;

void loop() {
  if (Serial.available()) {
    // Configure from USB1
    Serial.println("Configuring the FPGA");
    digitalWrite(LED_BUILTIN, 1);
    myStorm.FPGAConfigure(Serial);
    while (Serial.available()) Serial.read();
    digitalWrite(LED_BUILTIN, 0);
    dataFlag = true;
  }
  
  if (dataFlag) {
    dataFlag = false;

    Serial.println("Fetching the data");
  
    // Fetch the data
    for(int i=0;i<NUM_SAMPLES;i+=QSPI_CHUNK) {
        if (!QSPI.write(&parameters[i<sizeof(parameters) ? i : 0], QSPI_CHUNK))
          Serial.println("QSPI.transmit failed");
        if (!QSPI.read(&samples[i], QSPI_CHUNK))
          Serial.println("QSPI.receive failed");
        samples[i] = samples[i] + 128;
    }
  
    GD.cmd_memwrite(0, NUM_SAMPLES);
    for(int i=0;i<NUM_SAMPLES/CHUNK_SIZE;i++) 
      GD.copyram((byte*) (samples + i*CHUNK_SIZE), CHUNK_SIZE);
    GD.sample(0, NUM_SAMPLES, 6000, LINEAR_SAMPLES, 1);
  }

  GD.ClearColorRGB(0xb0e0e6);
  GD.Clear();
  //GD.Begin(0);
  GD.ColorRGB(0x7f0000); 
  GD.cmd_text(240, 10, 26, OPT_CENTER, "Voice Recorder");
  drawFFT((n++ % (NUM_SAMPLES/1024)) * 1024);
  GD.swap();
  delay(150);
}

void dataReady() {
  Serial.println("Data available");
  dataFlag = true;
}
