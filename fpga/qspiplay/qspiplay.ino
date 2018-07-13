#include <QSPI.h>
#include <FS.h>
#include <MyStorm.h>

const byte bitstream[] = {
#include "ice40bitstream.h"
};

bool configured;  // true if FPGA has been configured successfully

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, 0);
  QSPI.begin(40000000, QSPI.Mode3);
  Serial.begin(9600);
    // configure the FPGA
  configured = myStorm.FPGAConfigure(bitstream, sizeof bitstream);
  while (!Serial) ; // wait for USB serial connection to be established
  
  DOSFS.begin();

  Serial.println("SDCard files: ");
  Dir dir = DOSFS.openDir("/");
  do {
    Serial.println(dir.fileName());
  } while (dir.next());
  
  DOSFS.end();
}

void loop() {
  char fileName[64];

  // prompt and read the name of a bitstream file
  Serial.print("Bitstream file for ICE40: ");
  if (readLine(Serial, fileName, sizeof fileName) == 0)
    return;
  Serial.println();

  // open the file on the SD card file system
  DOSFS.begin();
  File file = DOSFS.open(fileName, "r");
  if (file) {
    // Send the file to the Ice40
    Serial.print("Sending: ");
    Serial.println(fileName);
    digitalWrite(LED_BUILTIN, 1);
    QSPI.beginTransaction();
    while(file.available()) {
      byte data = file.read();
      if (!QSPI.write(&data, 1)) {
        Serial.println("QPSI transmit failed");
        break;
      }
      delayMicroseconds(100);
    }
    digitalWrite(LED_BUILTIN, 0);
    file.close();
    QSPI.endTransaction();
  } else
    Serial.println("file not found");
  DOSFS.end();
}

/*
 * Read and echo a line from given input stream until terminated
 * by '\n', '\r' or '\0' or until the buffer is full.
 * Discard the terminating character and append a null character.
 * 
 * Returns the number of input characters in the buffer (excluding the null).
 */
int readLine(Stream &str, char *buf, int bufLen)
{
  int c, nread;

  // discard any extra CR or NL left from previous readLine
  do {
    c = str.read();
  } while (c == -1 || c == '\n' || c == '\r');
  // read until buffer until termination character seen or buffer full
  nread = 0;
  while (c != '\0' && c != '\n' && c != '\r') {
    str.write(c);
    buf[nread] = c;
    ++nread;
    if (nread == bufLen - 1)
      break;
    do {
      c = str.read();
    } while (c == -1);
  }
  // mark end of line and return
  buf[nread] = '\0';
  return nread;
}

