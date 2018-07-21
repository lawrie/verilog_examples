#include <EEPROM.h>
#include <SPI.h>
#include <GD2.h>
#include <MyStorm.h>
#include <QSPI.h>

#define grid_size  34
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

int debug = 0;

char input_names[7][12] = {"volts/div", "speed", "mode", 
                      "trig type", "trigger", "AC/DC", "offset"};

const float Pi = 3.141593;

signed char samples[NUM_SAMPLES];
signed char parameters[14];

float volts_per_div = 1.5;
int micros_per_div = 1;
bool trigger_mode;
float trigger = 1.0;
bool ac_dc;
long avg;
int vmin, vmax;
int speed = 64;
float vrms;
char mode = 1;
long frequency;
int duty = 50;
char* selected_name;
byte selected = 2;
int offset = 0;

volatile bool dataFlag = false;

void setup()
{
  Serial.begin(9600);
  selected_name = input_names[selected];

   // Configure any bitstream in flash memory
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, 1);
  myStorm.FPGAConfigure((const byte*)0x0801F000, 135100);
  digitalWrite(LED_BUILTIN, 0);
  
  GD.begin();

  attachInterrupt(PIN_BUTTON2, dataReady, FALLING);
  QSPI.begin(40000000, QSPI.Mode3);
  QSPI.beginTransaction();
}

int value;

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
  GD.ColorRGB(0x8a2be2); 
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

  // Cyan microseconds per  division
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
  GD.ColorRGB(0x8a2be2); 
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

  sprintf(num, "%s",(trigger_mode ? "falling" : "rising"));
  GD.Tag(TAG_TRIGGER_TYPE);
  GD.cmd_text(215, 10, 16, OPT_CENTER, num);

  sprintf(num, "%1.1fv",trigger);
  GD.Tag(TAG_TRIGGER);
  GD.cmd_text(280, 10, 16, OPT_CENTER, num);

  sprintf(num, "%s",(ac_dc ? "DC" : "AC"));
  GD.Tag(TAG_AC_DC);
  GD.cmd_text(330, 10, 16, OPT_CENTER, num);

  sprintf(num,"%d",offset);
  GD.Tag(TAG_OFFSET);
  GD.cmd_text(360, 10, 16, OPT_CENTER, num); 

  if (debug) Serial.println("Drawing dial");

  GD.Tag(TAG_DIAL);
  GD.cmd_dial(445,30, 25, 0, value);
  GD.cmd_track(445, 30, 1, 1, TAG_DIAL);

  GD.Tag(TAG_OTHER);
  
  sprintf(num, "%2.1fv",((float) avg * 10 / 128));
  GD.cmd_text(30, 260, 16, OPT_CENTER, num);

  sprintf(num, "%2.1fv",((float) (vmax - vmin) * 10 / 128));
  GD.cmd_text(90, 260, 16, OPT_CENTER, num); 

  sprintf(num, "%2.1fv",((float) vmax * 10 / 128));
  GD.cmd_text(150, 260, 16, OPT_CENTER, num); 

  sprintf(num, "%2.1fv",((float) vmin * 10 / 128));
  GD.cmd_text(210, 260, 16, OPT_CENTER, num);

  sprintf(num, "%2.1fv",vrms * 10 / 128);
  GD.cmd_text(270, 260, 16, OPT_CENTER, num);  

  char units[2];
  units[1] = 0;
  int freq;
  
  if (frequency < 1024) {
    units[0] = '0';
    freq = frequency;
  } else if (frequency < 1024*1024) {
    units[0] = 'k';
    freq = frequency / 1024; 
  } else {
    units[0] = 'm';
    freq = frequency / (1024*1024);
  }
  sprintf(num, "%d%shz",freq, units);
  GD.cmd_text(320, 260, 16, OPT_CENTER, num);

  sprintf(num, "%d%%",duty);
  GD.cmd_text(385, 260, 16, OPT_CENTER, num);  

  GD.cmd_text(440, 70, 16, OPT_CENTER, selected_name);  

  if (debug) Serial.println("Getting track input");

  switch (GD.inputs.track_tag & 0xff) {
  case TAG_DIAL:
    value = GD.inputs.track_val;
  }

  mode = value/8192;

  byte tag = GD.inputs.tag;

  if (tag > 0) {
    if (debug) Serial.print("Tag: ");
    if (debug) Serial.println(tag);
    if (tag > 1 && tag < 9) {
      selected = tag-2;
      selected_name = input_names[selected];
    }
  }

}

void create_samples() {
  for(int i=0;i<NUM_SAMPLES;i++) samples[i] = 127 * sin(8*Pi * (((float) i)/NUM_SAMPLES));
}

void draw_graph() {
  GD.Begin(POINTS);
  GD.ColorRGB(0x0000cd);
  
  for(int i=0;i<NUM_SAMPLES;i++) {
    GD.Vertex2ii((i*W)/NUM_SAMPLES, H/2 - ((int) samples[i]/volts_per_div));
    if (i > 0 && abs(samples[i-1] - samples[i]) > 10) {
      GD.Begin(LINES);
      GD.Vertex2ii(((i-1)*W)/NUM_SAMPLES, H/2 - (((int) samples[i-1])/volts_per_div));
      GD.Vertex2ii((i*W)/NUM_SAMPLES, H/2 - (((int) samples[i])/volts_per_div));
      GD.Begin(POINTS);
    }
  }
}

void drawGrid()
{
  GD.ClearColorRGB(0xb0e0e6);
  GD.Clear();
  GD.Begin(LINES);
  
  for(int i=1;i<(H+grid_size-1)/grid_size;i++) {
    GD.ColorRGB(i == 4 ? 0 : 0x708090); 
    GD.Vertex2ii(0, i*grid_size); GD.Vertex2ii(W-1, i*grid_size);
  }
  for(int i=1;i<(W+grid_size-1)/grid_size;i++) {
    GD.ColorRGB(i == 7 ? 0 : 0x708090); 
    GD.Vertex2ii(i*grid_size, 0); GD.Vertex2ii(i*grid_size, H-1);
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
    char buff[80];
    
    sprintf(buff, "Took %ld microeconds", duration);
    Serial.println(buff);
    int triggerred = 0;
    
    for(int i=0;i<NUM_SAMPLES;i++) {
        bool rising = false;
        bool falling = false;
      
        tot += (int) samples[i];
        if ((int) samples[i] > vmax) vmax = (int) samples[i];
        if ((int) samples[i] < vmin) vmin = (int) samples[i];
        rms += ((int) samples[i]) * ((int) samples[i]);
        if (i > 0 && samples[i] > samples[i-1]) rising = true;
        if (i > 0 && samples[i] < samples[i-1]) falling = true;

        if (i>0 && rising && !trigger_mode && trigger > samples[i-1] &&
            trigger <= samples[i]) {
          triggerred++; 
        }

        if (i>0 && falling && trigger_mode && trigger < samples[i-1] &&
            trigger >= samples[i]) {
          triggerred++; 
        }
   
    }

    vrms = sqrt(rms / NUM_SAMPLES) * 10/128;

    avg = tot /NUM_SAMPLES;

    frequency = (micros_per_div / triggerred) * 16;

    sprintf(buff,"Avg: %ld, max: %d, min: %d, rms: %2.1f. triggerred: %d, freq: %ld, selected %d", 
            avg, (int) vmax, (int) vmin, vrms, triggerred, frequency, selected);
    Serial.println(buff);
  }

  GD.get_inputs();
  if (debug) Serial.println("Drawing grid");
  drawGrid();
  if (debug) Serial.println("Drawing graph");
  draw_graph();
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

