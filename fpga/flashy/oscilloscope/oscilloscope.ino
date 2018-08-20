#include <EEPROM.h>
#include <SPI.h>
#include <GD2.h>
#include <MyStorm.h>
#include <QSPI.h>

#define GRID_SIZE  34
#define W 480
#define H 272
#define NUM_SAMPLES 4096
#define QSPI_CHUNK 1
#define CHUNK_SIZE 1024
#define SAMPLES_PER_PAGE 1024
#define CLK_FREQ 60000000

#define MAX_POINTS 1500

// Approx 256/ GRID_SIZE * VOLTS_MULTIPLIER
#define VOLTS_FACTOR 0.45

#define TAG_DIAL 1
#define TAG_VOLTS_PER_DIV 2
#define TAG_SPEED 3
#define TAG_MODE 4
#define TAG_TRIGGER_TYPE 5
#define TAG_TRIGGER 6
#define TAG_AC_DC 7
#define TAG_OFFSET 8
#define TAG_PROBE 9
#define TAG_FFT 10
#define TAG_RUNNING 11
#define TAG_OTHER 100

#define FONT 26

#define VOLTS_MULTIPLIER 0.064
#define ZERO_OFFSET -37

// Set to switch on debugging
static bool  debug = 0;
static bool vertical = true;
static bool play_sample = false;

static const char input_names[9][12] = {"volts/div", "speed", "mode", 
                      "trig type", "trigger", "AC/DC", "offset", "x1/x10", 
                      "scope/fft"};

static const char trigger_names[4][12] = {"rising", "falling", "none", "reserved"};

static const float Pi = 3.141593;

// The samples
static signed char samples[NUM_SAMPLES];

// Parameters to send to FPGA
static unsigned char parameters[14];

// Parameters
static float volts_per_div = 1.0; // volts
static long nanos_per_div = 1000;  // nanoseconds
static char mode = 0; // 0 = normal, others test
static char trigger_type = 2; 
static float trigger = 0.0; // volts
static bool ac_dc = true; // false: dc, true ac
static float offset = 0; // offset in volts
static int dc_offset = 0; // dc offset when in ac mode
static boolean draw_fft = false;
static boolean probe_x10 = true;
int probe_factor = 1;
static bool running = true;

// Measurements
static long avg;
static int vmin, vmax;
static int speed = 63;
static float vrms;
static long frequency;
static int wavelength;
static int duty = 50;

// Selected parameter
static byte selected = 2;

// Interrupt flag
volatile bool dataFlag = false;

// Used by dial
static int value;

// FFT stuff------------------------------------------------------------------
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

// End of FFT stuff

void setup()
{
  Serial.begin(9600);
  //while(!Serial);

  //initialize FFT variables
  init_hamming_window(hammingwindow,FFTLEN);
  fill(y,0,FFTLEN);
  fill(data32,1,FFTLEN);
  fill(data16,1,FFTLEN);
   
  //selftest();

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

void drawTaggedRect(byte tag, uint32_t color, int x1, int y1, 
                    int x2, int y2) {  
  GD.Tag(tag);
  GD.ColorRGB(color); 
  GD.Vertex2ii(x1, y1);
  GD.Vertex2ii(x2, y2);
}

void drawColoredRect(uint32_t color, int x1, int y1, 
                    int x2, int y2) {  
  GD.ColorRGB(color); 
  GD.Vertex2ii(x1, y1);
  GD.Vertex2ii(x2, y2);
}

void drawBoxes() {
  char num[20];

  if (debug) Serial.println("Drawing rects");
  
  GD.Begin(RECTS);

  // Green volts per division
  drawTaggedRect(TAG_VOLTS_PER_DIV, 0x2e8b57, 15, 5, 55, 15);

  // Cyan microseconds per  division
  drawTaggedRect(TAG_SPEED,0x00ced1,70, 5, 110, 15);

  // Yellow mode
  drawTaggedRect(TAG_MODE, 0xeedd82, 125, 5, 175, 15);

  // Pink trigger type
  drawTaggedRect(TAG_TRIGGER_TYPE, 0xffc0cb, 185, 5, 225, 15);

  // Orange trigger value
  drawTaggedRect(TAG_TRIGGER, 0xffa500, 235, 5, 280, 15);

  // violet AC/DC
  drawTaggedRect(TAG_AC_DC, 0xdda0dd, 290, 5, 320, 15);

  // Orange red probe
  drawTaggedRect(TAG_PROBE, 0xff4500, 330, 5, 360, 15);

  // Blue offset
  drawTaggedRect(TAG_OFFSET, 0x1e90ff, 370, 5, 410, 15);

  // Orange Red Scope/FFT
  drawTaggedRect(TAG_FFT, 0xff4500, 425, 255, 465, 265);

  // Acquamarine running
  drawTaggedRect(TAG_RUNNING, 0x66cdaa, 425, 225, 465, 240);

  GD.Tag(TAG_OTHER);
  
  // Green average voltage
  drawColoredRect(0x2e8b57, 15, 255, 55, 265);

  // Cyan Vpp
  drawColoredRect(0x00ced1, 70, 255, 110, 265);

  // Yellow Vmax
  drawColoredRect(0xeedd82, 125, 255, 165, 265);

  // Pink Vmin
  drawColoredRect(0xffc0cb, 180, 255, 230, 265);

  // Orange vrms
  drawColoredRect(0xffa500, 245, 255, 290, 265);

  // violet frequency
  drawColoredRect(0xdda0dd, 305, 255, 345, 265);

  // Blue duty
  drawColoredRect(0x1e90ff, 365, 255, 405, 265);
  
  GD.Begin(0);

  if (debug) Serial.println("Drawing text");
  
  GD.ColorRGB(0x0); 
  
  sprintf(num, "%1.1fv",volts_per_div);
  GD.Tag(TAG_VOLTS_PER_DIV);
  GD.cmd_text(35, 10, FONT, OPT_CENTER, num);
  
  if (nanos_per_div < 1000) sprintf(num,"%3dns", nanos_per_div);
  else if (nanos_per_div < 1000000) sprintf(num,"%3dus", nanos_per_div / 1000);
  else sprintf(num,"%3dms", nanos_per_div/100000);
  GD.Tag(TAG_SPEED);
  GD.cmd_text(90, 10, FONT, OPT_CENTER, num);

  sprintf(num, "mode:%d",mode);
  GD.Tag(TAG_MODE);
  GD.cmd_text(150, 10, FONT, OPT_CENTER, num);

  sprintf(num, "%s",trigger_names[trigger_type]);
  GD.Tag(TAG_TRIGGER_TYPE);
  GD.cmd_text(205, 10, FONT, OPT_CENTER, num);

  sprintf(num, "%1.2fv",trigger);
  GD.Tag(TAG_TRIGGER);
  GD.cmd_text(260, 10, FONT, OPT_CENTER, num);

  sprintf(num, "%s",(ac_dc ? "AC" : "DC"));
  GD.Tag(TAG_AC_DC);
  GD.cmd_text(305, 10, FONT, OPT_CENTER, num);

  sprintf(num, "%s",(probe_x10 ? "x10" : "x1"));
  GD.Tag(TAG_PROBE);
  GD.cmd_text(345, 10, FONT, OPT_CENTER, num);

  sprintf(num,"%2.1fv",offset);
  GD.Tag(TAG_OFFSET);
  GD.cmd_text(390, 10, FONT, OPT_CENTER, num); 

  GD.Tag(TAG_FFT);
  GD.cmd_text(445, 260, FONT, OPT_CENTER, draw_fft ? "FFT" : "Scope");  

  GD.Tag(TAG_RUNNING);
  GD.cmd_text(445, 235, FONT, OPT_CENTER, (running ? "Stop" : "Run"));

  if (debug) Serial.println("Drawing dial");

  switch (selected) {
    case 0: value = (((int) (volts_per_div * 4)) - 1) * 4096; break;
    case 1: value = ((int) log2(speed+1))  * 5461; break;
    case 2: value = mode * 8192; break;
    case 3: value = trigger_type * 16384; break;
    case 4: value = (((int) (trigger * 4))  * 819) + 32768; break;
    case 5: value = ac_dc * 32768; break;
    case 6: value = (((int) offset * 2) * 1638) + 32768; break;
    case 7: value = probe_x10 * 32768; break;
    case 8: value = draw_fft * 32768; break;
  }
  
  GD.Tag(TAG_DIAL);
  GD.cmd_dial(445,30, 25, 0, value);
  GD.cmd_track(445, 30, 1, 1, TAG_DIAL);

  GD.Tag(TAG_OTHER);
  
  sprintf(num, "%2.2fv",((float) (avg - ZERO_OFFSET) * VOLTS_MULTIPLIER)/probe_factor);
  GD.cmd_text(35, 260, FONT, OPT_CENTER, num);

  sprintf(num, "%2.2fv",((float) (vmax - vmin) * VOLTS_MULTIPLIER)/probe_factor);
  GD.cmd_text(90, 260, FONT, OPT_CENTER, num); 

  sprintf(num, "%2.2fv",((float) (vmax - ZERO_OFFSET) * VOLTS_MULTIPLIER)/probe_factor);
  GD.cmd_text(150, 260, FONT, OPT_CENTER, num); 

  sprintf(num, "%2.2fv",((float) (vmin - ZERO_OFFSET) * VOLTS_MULTIPLIER)/probe_factor);
  GD.cmd_text(210, 260, FONT, OPT_CENTER, num);

  sprintf(num, "%2.2fv",vrms/probe_factor);
  GD.cmd_text(270, 260, FONT, OPT_CENTER, num);  

  char units[2];
  units[1] = 0;
  int freq;
  
  if (frequency < 1024) {
    units[0] = 0;
    freq = frequency;
  } else if (frequency < 1024*1024) {
    units[0] = 'k';
    freq = frequency / 1024; 
  } else {
    units[0] = 'm';
    freq = frequency / (1024*1024);
  }
  sprintf(num, "%d%shz",freq, units);
  GD.cmd_text(325, 260, FONT, OPT_CENTER, num);

  sprintf(num, "%d%%",duty);
  GD.cmd_text(385, 260, FONT, OPT_CENTER, num); 

  GD.cmd_text(440, 70, FONT, OPT_CENTER, input_names[selected]);  

  if (debug) Serial.println("Getting track input");

  switch (GD.inputs.track_tag & 0xff) {
  case TAG_DIAL:
    value = GD.inputs.track_val;
  }

  switch (selected) {
    case 0: volts_per_div = ((float) (value / 4096) + 1) / 4; break;
    case 1: speed = pow(2, (value / 5461)) -1; break;
    case 2: mode = value/8192; break;
    case 3: trigger_type = value / 16384; break;
    case 4: trigger = (((float) value - 32768) / 819) / 4; break;
    case 5: ac_dc = value / 32768; break;
    case 6: offset = (((float) value - 32768) / 1638) / 2; break;
    case 7: probe_x10 = value / 32768; break;
    case 8: draw_fft = value /32768; break;
  }
  
  nanos_per_div = ((speed + 1) * 125);
  probe_factor = (probe_x10 ? 1 : 10);

  byte tag = GD.inputs.tag;

  if (tag > 0) {
    if (debug) Serial.print("Tag: ");
    if (debug) Serial.println(tag);
    if (tag >= TAG_VOLTS_PER_DIV && tag <= TAG_FFT) {
      selected = tag-2;
    } else if (tag == TAG_RUNNING) {
      running ^= 1;
      delay(500);
    }
  }
}

void createSamples() {
  for(int i=0;i<NUM_SAMPLES;i++) samples[i] = 127 * sin(8*Pi * (((float) i)/NUM_SAMPLES));
}

void printSamples() {
  for(int i=0;i<NUM_SAMPLES;i+=32) {
    char buf[70];
    for(int j=0;j<32;j++) 
      sprintf(&buf[j*2],"%02x",samples[i+j] & 0xFF);
    Serial.println(buf);
  }
}

void drawFFT(int start) {
  long points = 0;
  GD.Begin(LINES);
  GD.PointSize(32);

  unsigned int max_vol= 0;
  unsigned int max_freq = 0;

  for(int i=0;i<=FFTLEN;i++) 
    data16[i] = ((int) samples[start+i] + 128) * 40;
  real_to_complex(data16, data32, FFTLEN);
  uint32_t fft_micros = perform_fft(data32, y, FFTLEN);

  for(int i=0;i<480;i++) {
    unsigned int yy = y[i+2]/10;
    if (y[i+2] > max_vol) {
      max_freq = i;
      max_vol = y[i+2];
    }
    if (yy > 230) yy = 230;
    if (points+= 3 > MAX_POINTS) return;
    uint8_t blue = 255 - yy;
    uint8_t red = yy * 2;
    GD.ColorRGB((red << 16) | blue);
    GD.Vertex2ii(i,245);
    GD.Vertex2ii(i,245 - yy); 
  } 

  char buf[12];
  sprintf(buf, "%lu", (unsigned long) (((float) max_freq * CLK_FREQ) / (1024 * (float) ((speed/8) + 1))));
  GD.cmd_text(240, 40, 30, OPT_CENTER, buf);
}

void drawGraph() {
  GD.Begin(POINTS);
  GD.PointSize(16);
  GD.ColorRGB(0x0000cd);
  long points = 0;
  int oldx, oldy;
  int divisor = (nanos_per_div >= 1000 ? 1 : 1024 / nanos_per_div);
  
  for(int i=0;i<SAMPLES_PER_PAGE;i++) {
    int ii = i/ divisor;
    int px = (i*W)/SAMPLES_PER_PAGE;
    int py = H/2 - ((int) GRID_SIZE*offset/volts_per_div) -((int) (samples[ii] - dc_offset)/(volts_per_div*VOLTS_FACTOR/probe_factor));
    if (i == 0 || px != oldx || abs(py - oldy) > 0) {
      if (points++ > MAX_POINTS) return;
      GD.Vertex2ii(px,py);
    }
    oldx = px;
    oldy = py;
    if (vertical && i > 0 && abs(samples[ii-1] - samples[ii]) > 20) {
      if ((int) samples[ii] < (int) samples[ii-1]) {
        for(int j=(int) samples[ii]+1;j<(int) samples[ii-1]-1;j+= 2) {
          if (points++ > MAX_POINTS) return;
          px = (i*W)/SAMPLES_PER_PAGE;
          py = H/2 - ((int) GRID_SIZE*offset/volts_per_div) -((j - dc_offset)/(volts_per_div*VOLTS_FACTOR/probe_factor));
          GD.Vertex2ii(px, py);
        }
      } else {
        for(int j=(int) samples[ii-1]+1;j<(int) samples[ii]-1;j+= 2) {     
          if (points++ > MAX_POINTS) return;
          char buf[10];
          px = (i*W)/SAMPLES_PER_PAGE;
          py = H/2 - ((int) GRID_SIZE*offset/volts_per_div) -((j - dc_offset)/(volts_per_div*VOLTS_FACTOR/probe_factor));
          sprintf(buf,"(%d,%d)", px, py);
          if (debug) Serial.println(buf);
          GD.Vertex2ii(px, py);  
        }         
      }
    }
  }

  if (debug) Serial.print("Points: ");
  if (debug) Serial.println(points);
}

void drawTrigger() {
  Poly po;
  GD.ColorRGB(0xffff00);
  po.begin();
  int y = H/2 + (ac_dc ? (avg - ZERO_OFFSET)/(volts_per_div*VOLTS_FACTOR/probe_factor) : 0) - ((int) (((trigger + offset) * GRID_SIZE)) / volts_per_div);
  if (debug) Serial.print("Trigger y value = ");
  if (debug) Serial.println(y);
  po.v(0, (y-5) * 16);
  po.v(5 * 16, (y-5) * 16);
  po.v(10 * 16, y * 16);
  po.v(5 * 16, (y+5) * 16);
  po.v(0,(y+5) * 16);
  po.draw();
}

void drawGrid()
{
  GD.Begin(LINES);
  
  for(int i=1;i<(H+GRID_SIZE-1)/GRID_SIZE;i++) {
    GD.ColorRGB(i == 4 ? 0 : 0x708090); 
    GD.Vertex2ii(0, i*GRID_SIZE); GD.Vertex2ii(W-1, i*GRID_SIZE);
  }
  for(int i=1;i<(W+GRID_SIZE-1)/GRID_SIZE;i++) {
    GD.ColorRGB(i == 7 ? 0 : 0x708090); 
    GD.Vertex2ii(i*GRID_SIZE, 0); GD.Vertex2ii(i*GRID_SIZE, H-1);
  }
}

void loop() {
  if (debug) Serial.println("Start of loop");
  
  if (dataFlag) {
    dataFlag = false;

    long tot = 0;
    vmax = -128;
    vmin = 127;
    unsigned long start = micros();
    long long rms = 0;

    parameters[0] = mode;
    parameters[1] = speed / 8;
    parameters[2] = (int) ((trigger / VOLTS_MULTIPLIER) + 128 + ZERO_OFFSET);
    parameters[3] = trigger_type;

    if (debug) Serial.println("Fetching data");
    
    // Fetch the data
    for(int i=0;i<NUM_SAMPLES;i+=QSPI_CHUNK) {
        if (!QSPI.write(&parameters[i<sizeof(parameters) ? i : 0], QSPI_CHUNK))
          Serial.println("QSPI.transmit failed");
        if (!QSPI.read(&samples[i], QSPI_CHUNK))
          Serial.println("QSPI.receive failed");
    }

    unsigned long duration = micros() - start;
    char buff[100];
    
    if (debug) {
      sprintf(buff, "Took %ld microeconds", duration);
      Serial.println(buff);
      printSamples();
    }
      
    int triggered = 0;
    int trig_time = 0, untrig_time = 0;

    // Process the samples
    for(int i=0;i<NUM_SAMPLES;i++) {
        bool rising = false;
        bool falling = false;
        if (mode == 0) {
          samples[i] = (int) samples[i] + 128; // Make signed
        }
        tot += (int) samples[i];
        if ((int) samples[i] > vmax) vmax = (int) samples[i];
        if ((int) samples[i] < vmin) vmin = (int) samples[i];

        if (i > 0 && (int) samples[i] > (int) samples[i-1]) rising = true;
        if (i > 0 && (int) samples[i] < (int) samples[i-1]) falling = true;

        if (rising && trigger_type == 0 && 
            (int) samples[i] - ZERO_OFFSET >= (int) (trigger /VOLTS_MULTIPLIER) && 
            (int) samples[i-1] - ZERO_OFFSET < (int) (trigger / VOLTS_MULTIPLIER)) {
          if (triggered == 0) trig_time = i;  
          if (triggered == 1) wavelength = i - trig_time;           
          triggered++; 
        }

        if (falling && trigger_type == 0 && 
            (int) samples[i] - ZERO_OFFSET <= (int) (trigger / VOLTS_MULTIPLIER) && 
            (int) samples[i-1] - ZERO_OFFSET  > (int) (trigger / VOLTS_MULTIPLIER)) {
          if (triggered == 1 && i > trig_time) untrig_time = i;             
        }

        if (falling && trigger_type == 1 && 
            (int) samples[i] - ZERO_OFFSET <= (int) (trigger / VOLTS_MULTIPLIER) &&
            (int) samples[i-1]- ZERO_OFFSET > (int) (trigger / VOLTS_MULTIPLIER)) {
          if (triggered == 0) trig_time = i;    
          if (triggered == 1) wavelength = i - trig_time; 
          triggered++; 
        }
                
        if (rising && trigger_type == 1 && 
            (int) samples[i] >= (int) (trigger / VOLTS_MULTIPLIER) && 
            (int) samples[i-1] < (int) (trigger / VOLTS_MULTIPLIER)) {
          if (triggered == 1 && i > trig_time) untrig_time = i;            
        }
    }

    duty = 100 * (((float) (untrig_time - trig_time)) / wavelength);
    int fft_start = 1024;
           
    if (draw_fft) {
      for(int i=0;i<=FFTLEN;i++) 
        data16[i] = ((uint) ((samples[fft_start+i] - 128) & 0xff)) * 40;
      real_to_complex(data16, data32, FFTLEN);
      uint32_t fft_micros = perform_fft(data32, y, FFTLEN);
      Serial.print("FFT took (micros): ");
      Serial.println(fft_micros); 
      printdata16(data16,FFTLEN);
      printdataset(y,FFTLEN/2+1,1024);
    }

    avg = tot /NUM_SAMPLES;

    for(int i=0;i<NUM_SAMPLES;i++) {
      rms += ((int) samples[i] - avg) * ((int) samples[i] - avg);
    }

    vrms = sqrt((float) rms / NUM_SAMPLES) * VOLTS_MULTIPLIER;
    
    dc_offset = (ac_dc ? avg : ZERO_OFFSET);
    frequency = ((float) triggered * CLK_FREQ) / (NUM_SAMPLES * (speed / 8) + 1);

    sprintf(buff,"Avg: %ld, max: %d, min: %d, rms: %2.1f. trig: %d, freq: %ld, sel %d, speed: %d, tt: %d, duty: %d%%", 
            avg, (int) vmax, (int) vmin, vrms, triggered, frequency, selected, speed, trigger_type, duty);
    Serial.println(buff);

    // Play the sample
    if (play_sample) {
      if (debug) Serial.println("Copying RAM");
      GD.cmd_memwrite(0, NUM_SAMPLES);
      for(int i=0;i<NUM_SAMPLES/CHUNK_SIZE;i++) 
        GD.copyram((byte*) (samples + i*CHUNK_SIZE), CHUNK_SIZE);
      if (debug) Serial.println("Playing sample");
      GD.sample(0, NUM_SAMPLES, 6000, LINEAR_SAMPLES, 1);
    }
  }

  GD.get_inputs();
  if (debug) Serial.println("Drawing grid");
  GD.ClearColorRGB(0xb0e0e6);
  GD.Clear();
  if (!draw_fft) {
    drawGrid();
    if (debug) Serial.println("Drawing graph");
    drawGraph();
  } else {
    if (debug) Serial.println("Drawing FFT");

    drawFFT(0);
  }
  if (debug) Serial.println("Drawing boxes");
  drawBoxes();
  if (!draw_fft) drawTrigger();
  if (debug) Serial.println("Swapping");
  
  GD.swap();

  if (debug) Serial.println("Checking for serial");

  if (Serial.available()) {
    int c = Serial.read();
  
    if (c == 0xFF) {
      // Configure from USB1
      Serial.println("Configuring the FPGA");
      digitalWrite(LED_BUILTIN, 1);
      if (myStorm.FPGAConfigure(Serial)) {
        while (Serial.available())
          Serial.read();
      }
      digitalWrite(LED_BUILTIN, 0);
    } else if (c == '0') {
      Serial.println("Selecting STM32 SPI");
      myStorm.muxDisable();
    } else if (c == '1') {
      Serial.println("Selecting Leds");
      myStorm.muxSelectLeds();   
    } else if (c == '2') {
      Serial.println("Selecting RPi");
      myStorm.muxSelectPi();   
    } else if (c == '?') {
      volts_per_div = ((float) (Serial.read() - '0'))/2; 
      Serial.print("Volts per division: ");
      Serial.println(volts_per_div); 
    }
  }

  if (debug) Serial.println("End of loop"); 
}

void dataReady() {
  if (running) dataFlag = true;
}

