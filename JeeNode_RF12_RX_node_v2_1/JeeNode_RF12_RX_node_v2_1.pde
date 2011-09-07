
// Nanode Receiver V2.0 with Pachube feed and I2C LCD display
// Adapted from Simple RFM12B wireless Demo and Simple demo Pachube feed
// Glyn Hudson openenergymonitor.org GNU GPL V3 7/7/11
// Credit to JCW from Jeelabs.org for RFM12

// Version 2.0 - added Pachube logic
// Version 2.1 - added RX packet counter

//    Added I2C LCD display
//  Arduino analog input 5 - I2C SCL
//  Arduino analog input 4 - I2C SDA

#include <EtherCard.h>
#include <RF12.h>
#include <Ports.h> //from jeelabs.org
#include <Wire.h>
#include <LCDi2cNHD.h> 

// Pachube settings 
#define FEED    Your Feed #
#define APIKEY  "Your API Key"

// ethernet interface mac address, must be unique on the LAN
byte mymac[] = { 0x74,0x69,0x69,0x2F,0x30,0x34 };

char website[] PROGMEM = "api.pachube.com";

byte Ethernet::buffer[700];
uint32_t timer;
Stash stash;

#define RADIO_SYNC_MODE 2 //sync mode to 2 if fuses are Arduino default. Mode 3, full powerdown) only used with 258 CK startup fuse

#define COLLECT 0x20 // collect mode, i.e. pass incoming without sending acks


typedef struct {		//data Structure to be sent, called payload
  	  float data1;		// Battery Voltage
	  float data2;          // Temp Inside
          float data3;          // Temp Outside
} Payload;

Payload temps;

//NewHaven I2C LCD init
LCDi2cNHD lcd = LCDi2cNHD(4,20,0x50>>1,0);
uint8_t rows = 4;
uint8_t cols = 20;

// Nanode LED - ON during Pachube Update
int ledPin=6;   //  Activity LED

int x=0;  // received packet counter

void setup() {
   lcd.init(); 
   Serial.begin(9600); 
  Serial.println("Nanode RX node + Pachube feeder"); 
  rf12_config();  //same as rf12_initialize but uses EEPROM settings (See RF12 lib example RF12demo to set EEPROM)
 
  
   pinMode(ledPin,OUTPUT);  // Pachube update LED

// LCD "Boot Screen"
  lcd.clear(); 
  lcd.setCursor(0,0);  
  lcd.print("Nanode Receiver");
  lcd.setCursor(1,0);  
  lcd.print("Init Ethernet...");

 Serial.println("\n[webClient]");

  if (ether.begin(sizeof Ethernet::buffer, mymac) == 0) 
    Serial.println( "Failed to access Ethernet controller");
  if (!ether.dhcpSetup())
    Serial.println("DHCP failed");

  ether.printIp("IP:  ", ether.myip);
  ether.printIp("GW:  ", ether.gwip);  
  ether.printIp("DNS: ", ether.dnsip);  

  if (!ether.dnsLookup(website))
    Serial.println("DNS failed");
    
  ether.printIp("SRV: ", ether.hisip);


 
  lcd.setCursor(2,0);  
  lcd.print("Success!");
  lcd.setCursor(3,0);  
  lcd.print("Waiting for RX...");
 // lcd.clear();
}

void loop() {
  
 
   ether.packetLoop(ether.packetReceive());
   
  if (rf12_recvDone() && rf12_crc == 0 && (rf12_hdr & RF12_HDR_CTL) == 0) {
    temps=*(Payload*) rf12_data;            // Get the payload

    x++;  // inc received packet counter
    
 
  // LCD display update
  if (x==1) lcd.clear();  //clear screen after every pachube update
  lcd.setCursor(0,19);
  lcd.print ("*");  // Set the RX "blink" - indicates packet received
  lcd.setCursor(0,0);  
  lcd.print("Battery ");
  lcd.setCursor(0,8);
  lcd.print(temps.data1);
  lcd.setCursor(0,13);
  lcd.print("V");
  lcd.setCursor(1,0);
  lcd.print("Inside Temp ");
  lcd.setCursor(1,12);
  lcd.print(temps.data2);
  lcd.setCursor(1,17);
  lcd.print("F");
  lcd.setCursor(2,0);
  lcd.print("Outside Temp ");
  lcd.setCursor(2,13);
  lcd.print(temps.data3);
  lcd.setCursor(2,18);
  lcd.print("F");
  lcd.setCursor(3,0);
  lcd.print("Rec. packets ");
  lcd.setCursor(3,13);
  lcd.print(x);
  delay(500); //for the blink "*" when updating
  lcd.setCursor(0,19);
  lcd.print (" "); // blank the blink
  
  // serial output
   Serial.print(x); Serial.print("  ");
   Serial.print(temps.data1); Serial.print("  ");
   Serial.print(temps.data2); Serial.print("  ");
   Serial.println(temps.data3);  

}
  
  
  
   if (millis() > timer && temps.data1 !=0) {  //timer test & make sure that bat voltage is not =0 indicating no RF data received yet
    timer = millis() + 60000;
   
   digitalWrite(ledPin, LOW);   // sets the TX LED on (inverted on Nanode)
   
    // generate payload - by using a separate stash,
    // we can determine the size of the generated message ahead of time
    byte sd = stash.create();
    stash.print("0,");
    stash.println(temps.data1);
    stash.print("1,");
    stash.println(temps.data2);
    stash.print("2,");
    stash.println(temps.data3);
    stash.print("3,");
    stash.println(x);  // Rec. packet count for last 60s

    stash.save();
    
    // generate the header with payload - note that the stash size is used,
    // and that a "stash descriptor" is passed in as argument using "$H"
    Stash::prepare(PSTR("PUT http://$F/v2/feeds/$D.csv HTTP/1.0" "\r\n"
                        "Host: $F" "\r\n"
                        "X-PachubeApiKey: $F" "\r\n"
                        "Content-Length: $D" "\r\n"
                        "\r\n"
                        "$H"),
            website, FEED, website, PSTR(APIKEY), stash.size(), sd);

    // send the packet - this also releases all stash buffers once done
    ether.tcpSend();
  digitalWrite(ledPin, HIGH);    // sets the TX LED off (inverted on Nanode)  
 
  x=0; //reset packet counter
  lcd.setCursor(3,13);  //Update LCD RX count
  lcd.print("0  ");  // used txt to clear out counts over 10
  }
}

