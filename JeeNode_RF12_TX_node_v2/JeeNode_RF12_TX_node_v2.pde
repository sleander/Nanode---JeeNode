// JeeNode Transmitter V2.0 
// Measures battery voltage and reads temps from 2 DS18B20 Dallas 1-Wire sensors
// using a JeeNode module from JeeLabs.  Total dray is less than 10mA - no power savings attempted as it's attached to a 7AH battery
// that's charged ny a 10W solar panel. LED added to JeeNode P3 (Arduino Digital 6) as a status led - pulses during TX
//
// Adapted from Simple RFM12B wireless Demo and Simple demo Pachube feed
// Glyn Hudson openenergymonitor.org GNU GPL V3 7/7/11
// Credit to JCW from Jeelabs.org for RFM12

// Version 2.0 - added Pachube logic

#include <OneWire.h>
#include <DallasTemperature.h>
#include <RF12.h>
#include <Ports.h> //from jeelabs.org

#define RADIO_SYNC_MODE 2 //sync mode to 2 if fuses are Arduino default. Mode 3, full powerdown) only used with 258 CK startup fuse

#define COLLECT 0x20 // collect mode, i.e. pass incoming without sending acks


typedef struct {		//data Structure to be sent, called payload
  	  float data1;		// Battery Voltage
	  float data2;          // Temp Inside
          float data3;          // Temp Outside
} Payload;

Payload temps;


int ledPin=6;   // TX Activity LED

// Data wire is plugged into port 8 on the Arduino
#define ONE_WIRE_BUS 5
//float Temp = 0;  

// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature sensors(&oneWire);

// arrays to hold device addresses
DeviceAddress insideThermometer, outsideThermometer;

//Voltage divider setup
  int analogInput = 1;
  float vout = 0.0;
  float vin = 0.0;
// Voltage divider to reduce 7AH gell cell (approx 13.8V) to measurable voltage on the JeeNode running at 3.3V
// R1 connects to battery +  (pulled off the "PWR" pin on the JeeNode).  R2 connects to R1 and GND.  AnalogInput connects
// to connection of R1 and R2. Use 1%, 1/8W resistors - measure actual values and enter here.  

  float R1 = 22030.0;    // !! resistance of R1 !!  
  float R2 = 4600.0;     // !! resistance of R2 !!
  
// variable to store the ADC value 
  int value = 0;




void setup(void)
{
  // start serial port
Serial.begin(9600);
  Serial.println("JeeNode Temp Module");
 
 
  rf12_config(); //same as rf12_initialize but uses EEPROM settings (see RF12 lib example RF12demo to set EEPROM values)
  
 // declaration of Voltmeter pin modes
  pinMode(analogInput, INPUT);
  
   pinMode(ledPin,OUTPUT);  // TX Led

  // Start up the 1-wire library
  sensors.begin();
  
   // locate devices on the bus
  digitalWrite(ledPin, HIGH);   // sets the Status LED ON
  Serial.print("Locating devices...");
  Serial.print("Found ");
  Serial.print(sensors.getDeviceCount(), DEC);
  Serial.println(" devices.");

  // report parasite power requirements
  Serial.print("Parasite power is: "); 
  if (sensors.isParasitePowerMode()) Serial.println("ON");
  else Serial.println("OFF");
  
   // assign address manually.  the addresses below will beed to be changed
  // to valid device addresses on your bus.  device address can be retrieved
  // by using either oneWire.search(deviceAddress) or individually via
  // sensors.getAddress(deviceAddress, index)
//  insideThermometer = { 0x28, 0xDA, 0x59, 0x46, 0x02, 0x00, 0x00, 0xD5 };  // Thermometer soldered to carrier board
//outsideThermometer  = { 0x28, 0x5F, 0x41, 0x46, 0x02, 0x00, 0x00, 0x96 };  // Remote Thermometer

  // search for devices on the bus and assign based on an index.  ideally,
  // you would do this to initially discover addresses on the bus and then 
  // use those addresses and manually assign them (see above) once you know 
  // the devices on your bus (and assuming they don't change).
  // 
  // method 1: by index
  if (!sensors.getAddress(insideThermometer, 0)) Serial.println("Unable to find address for Device 0"); 
  if (!sensors.getAddress(outsideThermometer, 1)) Serial.println("Unable to find address for Device 1"); 
  
  
  // show the addresses we found on the bus
  Serial.print("Device 0 Address: ");
  printAddress(insideThermometer);
  Serial.println();

  Serial.print("Device 1 Address: ");
  printAddress(outsideThermometer);
  Serial.println();
  
  // set the resolution to 12 bit
  sensors.setResolution(insideThermometer, 12);
  sensors.setResolution(outsideThermometer, 12);

  
}


// function to print a device address
void printAddress(DeviceAddress deviceAddress)
{
  for (uint8_t i = 0; i < 8; i++)
  {
    // zero pad the address if necessary
    if (deviceAddress[i] < 16) Serial.print("0");
    Serial.print(deviceAddress[i], HEX);
  }
}  
  

void loop()
{ 
 // for (int x=1; x < 9999; x++)
  
 // {
  // call sensors.requestTemperatures() to issue a global temperature 
  // request to all devices on the bus

  sensors.requestTemperatures(); // Send the command to get temperatures

temps.data2 = (sensors.getTempFByIndex(0));  
temps.data3 = (sensors.getTempFByIndex(1)); 
  
  //Voltmeter read and calc 
  // read the value on analog input
  value = analogRead(analogInput);
  vout = (value * 3.3) / 1024.0;
  vin = vout / (R2/(R1+R2));
  
  Serial.print(vin);
  Serial.print(" volt");
  Serial.print (",");  
  Serial.print (temps.data2);
  Serial.print (",");
  Serial.println (temps.data3);
  
  temps.data1=vin;
  
  digitalWrite(ledPin, HIGH);   // sets the TX LED on
  delay(40);
  digitalWrite(ledPin, LOW);    // sets the TX LED off

  while (!rf12_canSend())
    rf12_recvDone();
    rf12_sendStart(rf12_hdr, &temps, sizeof temps, RADIO_SYNC_MODE); 
  
  
delay (2000);  // no power savings implimened 
}

