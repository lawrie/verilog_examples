#include <EEPROM.h>
#include <SPI.h>
#include <GD2.h>
#include <MyStorm.h>
#include <QSPI.h>

#define GRID_SIZE  34
#define W 480
#define H 272
#define NUM_SAMPLES 1024
#define QSPI_CHUNK 1

#define TAG_DIAL 1
#define TAG_VOLTS_PER_DIV 2
#define TAG_SPEED 3
#define TAG_MODE 4
#define TAG_TRIGGER_TYPE 5
#define TAG_TRIGGER 6
#define TAG_AC_DC 7
#define TAG_OFFSET 8
#define TAG_OTHER 100

// Set to switch on debugging
static bool  debug = 0;

static const char input_names[7][12] = {"volts/div", "speed", "mode", 
                      "trig type", "trigger", "AC/DC", "offset"};

static const char trigger_names[4][12] = {"rising", "falling", "none", "reserved"};

static const float Pi = 3.141593;

// The samples
static signed char samples[NUM_SAMPLES];

// Parameters to send to FPGA
static signed char parameters[14];

// Parameters
static float volts_per_div = 1.5; // volts
static int micros_per_div = 1;  //microseconds
static char mode = 0; // 0 = normal, others test
static char trigger_type = 0; 
static float trigger = 1.0; // volts
static bool ac_dc; // false: dc, true ac
static float offset = 0; // offset in volts

// Measurements
static long avg;
static int vmin, vmax;
static int speed = 63;
static float vrms;
static long frequency;
static int duty = 50;

// Selected parameter
static byte selected = 2;

// Interrupt flag
volatile bool dataFlag = false;

// Used by dial
static int value;

void setup()
{
  Serial.begin(9600);

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

void drawBoxes() {
  char num[20];

  if (debug) Serial.println("Drawing rects");
  
  GD.Begin(RECTS);

  // Green volts per division
  GD.Tag(TAG_VOLTS_PER_DIV);
  GD.ColorRGB(0x2e8b57); 
  GD.Vertex2ii(15,5);
  GD.Vertex2ii(55,15);

  // Cyan microseconds per  division
  GD.Tag(TAG_SPEED);
  GD.ColorRGB(0x00ced1); 
  GD.Vertex2ii(70,5);
  GD.Vertex2ii(110,15);

  // Yellow mode
  GD.Tag(TAG_MODE); 
  GD.ColorRGB(0xeedd82);
  GD.Vertex2ii(125,5);
  GD.Vertex2ii(175,15);

  // Pink trigger type
  GD.Tag(TAG_TRIGGER_TYPE);
  GD.ColorRGB(0xffc0cb); 
  GD.Vertex2ii(190,5);
  GD.Vertex2ii(240,15);

  // Orange trigger value
  GD.Tag(TAG_TRIGGER);
  GD.ColorRGB(0xffa500); 
  GD.Vertex2ii(255,5);
  GD.Vertex2ii(300,15);

  // violet AC/DC
  GD.Tag(TAG_AC_DC);
  GD.ColorRGB(0xdda0dd); 
  GD.Vertex2ii(315,5);
  GD.Vertex2ii(345,15);

  // Blue offset
  GD.Tag(TAG_OFFSET);
  GD.ColorRGB(0x1e90ff);
  GD.Vertex2ii(360,5);
  GD.Vertex2ii(400,15);

  GD.Tag(TAG_OTHER);
  
  // Green average voltage
  GD.ColorRGB(0x2e8b57); 
  GD.Vertex2ii(15,255);
  GD.Vertex2ii(55,265);

  // Cyan Vpp
  GD.ColorRGB(0x00ced1); 
  GD.Vertex2ii(70,255);
  GD.Vertex2ii(110,265);

  // Yellow Vmax
  GD.ColorRGB(0xeedd82); 
  GD.Vertex2ii(125,255);
  GD.Vertex2ii(165,265);

  // Pink Vmin
  GD.ColorRGB(0xffc0cb); 
  GD.Vertex2ii(180,255);
  GD.Vertex2ii(230,265);

  // Orange vrms
  GD.ColorRGB(0xffa500); 
  GD.Vertex2ii(245,255);
  GD.Vertex2ii(290,265);

  // violet frequency
  GD.ColorRGB(0xdda0dd); 
  GD.Vertex2ii(305,255);
  GD.Vertex2ii(345,265);

  // Blue duty
  GD.ColorRGB(0x1e90ff); 
  GD.Vertex2ii(365,255);
  GD.Vertex2ii(405,265);

  if (debug) Serial.println("Drawing Button");
  
  GD.Begin(0);

  if (debug) Serial.println("Drawing text");
  
  GD.ColorRGB(0x0); 
  
  sprintf(num, "%1.1fv",volts_per_div);
  GD.Tag(TAG_VOLTS_PER_DIV);
  GD.cmd_text(35, 10, 16, OPT_CENTER, num);
  
  if (micros_per_div < 1024) sprintf(num,"%3dus", micros_per_div);
  else sprintf(num,"%3dms", micros_per_div/1024);
  GD.Tag(TAG_SPEED);
  GD.cmd_text(90, 10, 16, OPT_CENTER, num);

  sprintf(num, "mode:%d",value/8192);
  GD.Tag(TAG_MODE);
  GD.cmd_text(150, 10, 16, OPT_CENTER, num);

  sprintf(num, "%s",trigger_names[trigger_type]);
  GD.Tag(TAG_TRIGGER_TYPE);
  GD.cmd_text(215, 10, 16, OPT_CENTER, num);

  sprintf(num, "%1.1fv",trigger);
  GD.Tag(TAG_TRIGGER);
  GD.cmd_text(280, 10, 16, OPT_CENTER, num);

  sprintf(num, "%s",(ac_dc ? "DC" : "AC"));
  GD.Tag(TAG_AC_DC);
  GD.cmd_text(330, 10, 16, OPT_CENTER, num);

  sprintf(num,"%2.1fv",offset);
  GD.Tag(TAG_OFFSET);
  GD.cmd_text(380, 10, 16, OPT_CENTER, num); 

  if (debug) Serial.println("Drawing dial");

  switch (selected) {
    case 0: value = (((int) (volts_per_div * 4)) - 1) * 4096; break;
    case 1: value = ((int) log2(speed+1))  * 7000; break;
    case 2: value = mode * 8192; break;
    case 3: value = trigger_type * 16384; break;
    case 4: value = (((int) (trigger * 2))  * 3276) + 32768; break;
    case 5: value = ac_dc * 32768; break;
    case 6: value = (((int) offset * 2) * 3276) + 32768; break;
  }
  
  GD.Tag(TAG_DIAL);
  GD.cmd_dial(445,30, 25, 0, value);
  GD.cmd_track(445, 30, 1, 1, TAG_DIAL);

  GD.Tag(TAG_OTHER);
  
  sprintf(num, "%2.1fv",((float) avg * 5 / 128));
  GD.cmd_text(30, 260, 16, OPT_CENTER, num);

  sprintf(num, "%2.1fv",((float) (vmax - vmin) * 5 / 128));
  GD.cmd_text(90, 260, 16, OPT_CENTER, num); 

  sprintf(num, "%2.1fv",((float) vmax * 5 / 128));
  GD.cmd_text(150, 260, 16, OPT_CENTER, num); 

  sprintf(num, "%2.1fv",((float) vmin * 5 / 128));
  GD.cmd_text(210, 260, 16, OPT_CENTER, num);

  sprintf(num, "%2.1fv",vrms);
  GD.cmd_text(270, 260, 16, OPT_CENTER, num);  

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
  GD.cmd_text(325, 260, 16, OPT_CENTER, num);

  sprintf(num, "%d%%",duty);
  GD.cmd_text(385, 260, 16, OPT_CENTER, num);  

  GD.cmd_text(440, 70, 16, OPT_CENTER, input_names[selected]);  

  if (debug) Serial.println("Getting track input");

  switch (GD.inputs.track_tag & 0xff) {
  case TAG_DIAL:
    value = GD.inputs.track_val;
  }

  switch (selected) {
    case 0: volts_per_div = ((float) (value / 4096) + 1) / 4; break;
    case 1: speed = pow(2, (value / 7000)) -1; break;
    case 2:  mode = value/8192; break;
    case 3: trigger_type = value / 16384; break;
    case 4: trigger = (((float) value - 32768) / 3276) / 2; break;
    case 5: ac_dc = value / 32768; break;
    case 6: offset = (((float) value - 32768) / 3276) / 2; break;
  }

  micros_per_div = (speed + 1) * 4;

  byte tag = GD.inputs.tag;

  if (tag > 0) {
    if (debug) Serial.print("Tag: ");
    if (debug) Serial.println(tag);
    if (tag > 1 && tag < 9) {
      selected = tag-2;
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

#define MAX_POINTS 1500
#define VOLTS_FACTOR 0.7

void drawGraph() {
  GD.Begin(POINTS);
  GD.ColorRGB(0x0000cd);
  long points = 0;
  for(int i=0;i<NUM_SAMPLES;i++) {
    if (points++ > MAX_POINTS) return;
    GD.Vertex2ii((i*W)/NUM_SAMPLES, H/2 - ((int) GRID_SIZE*offset) -((int) samples[i]/(volts_per_div*VOLTS_FACTOR)));
    if (i > 0 && abs(samples[i-1] - samples[i]) > 20) {
      if ((int) samples[i] < (int) samples[i-1]) {
        for(int j=(int) samples[i]+1;j<(int) samples[i-1]-1;j+= 2) {
          if (points++ > MAX_POINTS) return;
          GD.Vertex2ii((i*W)/NUM_SAMPLES, H/2 - ((int) GRID_SIZE*offset) -(j/(volts_per_div*VOLTS_FACTOR)));
        }
      } else {
        for(int j=(int) samples[i-1]+1;j<(int) samples[i]-1;j+= 2) {
          char buf[10];
          int px = (i*W)/NUM_SAMPLES;
          int py = H/2 - ((int) GRID_SIZE*offset) -(j/(volts_per_div*VOLTS_FACTOR));
          sprintf(buf,"(%d,%d)", px, py);
          if (debug) Serial.println(buf);
          GD.Vertex2ii(px, py);  
          if (points++ > MAX_POINTS) return;
        }         
      }
    }
  }

  if (debug) Serial.print("Points: ");
  if (debug) Serial.println(points);
}

void drawGrid()
{
  GD.ClearColorRGB(0xb0e0e6);
  GD.Clear();
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
    long rms = 0;

    parameters[0] = mode; 
    parameters[1] = speed; 
    parameters[2] = (int) ((5 - trigger) * -25.5); 
    parameters[3] = trigger_type;

    micros_per_div = (speed == 0 ? 8 : 4 * speed);

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
    
    sprintf(buff, "Took %ld microeconds", duration);
    if (debug) Serial.println(buff);
    
    if (debug) 
       printSamples();
    
    int triggerred = 0;

    // Process the samples
    for(int i=0;i<NUM_SAMPLES;i++) {
        bool rising = false;
        bool falling = false;
        if (mode == 0) samples[i] = (int) samples[i] + 128; // Samples is negative and offset by 2
      
        tot += (int) samples[i];
        if ((int) samples[i] > vmax) vmax = (int) samples[i];
        if ((int) samples[i] < vmin) vmin = (int) samples[i];
        rms += ((int) samples[i]) * ((int) samples[i]);
        if (i > 0 && (int) samples[i] > (int) samples[i-1]) rising = true;
        if (i > 0 && (int) samples[i] < (int) samples[i-1]) falling = true;

        if (rising && trigger_type == 0 && 
            (int) samples[i] >= (int) (trigger * 25.5) && 
            (int) samples[i-1] < (int) (trigger * 25.5)) {
              
          triggerred++; 
        }

        if (falling && trigger_type == 1 && 
            (int) samples[i] <= (int) (trigger * 25.5) &&
            (int) samples[i-1] > (int) (trigger * 25.5)) {
              
          triggerred++; 
        }
    }

    vrms = sqrt((float) rms / NUM_SAMPLES) * 5/128;
    avg = tot /NUM_SAMPLES;
    frequency = (float) triggerred * 128 * 1024 / micros_per_div;

    sprintf(buff,"Avg: %ld, max: %d, min: %d, rms: %2.1f. trig: %d, freq: %ld, sel %d, speed: %d, tt: %d", 
            avg, (int) vmax, (int) vmin, vrms, triggerred, frequency, selected, speed, trigger_type);
    Serial.println(buff);
  }

  GD.get_inputs();
  if (debug) Serial.println("Drawing grid");
  drawGrid();
  if (debug) Serial.println("Drawing graph");
  drawGraph();
  if (debug) Serial.println("Drawing boxes");
  drawBoxes();
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
  //Serial.println("Data ready");
  dataFlag = true;
}

