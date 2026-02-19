/*Led Bridge lamp code v1b
Led strip is WS2811, data wire is on pin 2
Standart rotary encoder
Janis Jakaitis 03.08.2016
absolutelly no varranty of any kond, use ta your won risk
GPL licence
*/

#include <Encoder.h>
#include <NeoPixelBus.h>
#include <EEPROM.h>

//configuration
const uint8_t PixelPin = 2;
const uint8_t encButtonPin = 4;
const uint16_t PixelCount = 119; 

//objects
Encoder myEnc(5, 6);
NeoPixelBus<NeoGrbFeature, Neo800KbpsMethod> strip(PixelCount, PixelPin);

//variables
uint8_t oldPosition  = 0;
int buttonState = 0;
bool waitingForPress = true;
bool waitingForRelease = false;
bool confRGBIDone = false;
bool confRGBInprogress = false;
int confRGBIparamater = 0;
int confR = 255;
int confG = 255;
int confB = 255;
int confI = 255;
long newPosition = 0;
RgbColor curentColor(0, 0, 0);

void setup() {
  Serial.begin(9600);
  Serial.println("Basic Encoder Test:");
  
  //setup encoder
  pinMode(encButtonPin, INPUT);
  myEnc.write(255);

  //read RGBI values from EEPROM
  confR = EEPROM.read(0);
  confG = EEPROM.read(1);
  confB = EEPROM.read(2);
  confI = EEPROM.read(3);
  
  //display stored values
  Serial.print("EEPROM values R:" );
  Serial.print(confR );
  Serial.print(" / G:" );
  Serial.print(confG );
  Serial.print(" / B:" );
  Serial.print(confB );
  Serial.print( " / I: " );
  Serial.println(confI );
  
  //set strip to original color
  RgbColor curentColor(confR, confG, confB);
  strip.ClearTo(curentColor);
  strip.Show();

}


void loop() {

  if (confRGBInprogress == true) {
    newPosition = myEnc.read();
    if (newPosition != oldPosition) {

      //limit encoder values 0 to 2550
      if (newPosition > 255) {
        myEnc.write(255);
        newPosition = 255;
        
          curentColor = RgbColor(0, 0, 0);
          strip.ClearTo(curentColor);
          strip.Show();
          delay(300);
          curentColor = RgbColor(confR, confG, confB);
          strip.ClearTo(curentColor);
          strip.Show();
        
      }
      if (newPosition < 0) {
          curentColor = RgbColor(0, 0, 0);
          strip.ClearTo(curentColor);
          strip.Show();
          delay(300);
          curentColor = RgbColor(confR, confG, confB);
          strip.ClearTo(curentColor);
          strip.Show();
        myEnc.write(0);
        newPosition = 0;
      }

      oldPosition = newPosition;
      Serial.println(newPosition);

      // change colors on the fly according to encoder values
      switch (confRGBIparamater) {
        case 1:
          curentColor = RgbColor(newPosition, confG, confB);
          strip.ClearTo(curentColor);
          break;
        case 2:
          curentColor = RgbColor(confR, newPosition, confB);
          strip.ClearTo(curentColor);
          break;
        case 3:
          curentColor = RgbColor(confR, confG, newPosition);
          strip.ClearTo(curentColor);
          break;
        default:
          break;
      }
      strip.Show();
    }
  }

// read encoder button press
  buttonState = digitalRead(encButtonPin);

  //wait for button to go LOW
  if (waitingForPress == true) {
    if (buttonState == LOW) {
      waitingForPress = false;
      waitingForRelease = true;
      // Serial.println("Press" );
    }
  }

  // button goes HIGH after LOW = begin strip config
  if (waitingForRelease == true) {
    if (buttonState == HIGH) {
      // Serial.println("Relese" );
      waitingForPress = true;
      waitingForRelease = false;
      confRGBInprogress = true;

     proceed according to button press counts
      switch (confRGBIparamater) {
        case 0:
          Serial.println("Config, set red" );
          myEnc.write(confR);
          curentColor = RgbColor(255, 0, 0);
          strip.ClearTo(curentColor);
          strip.Show();
          delay(500);
          curentColor = RgbColor(confR, confG, confB);
          strip.ClearTo(curentColor);
          strip.Show();
          break;
        case 1:
          Serial.println("Set green" );
          curentColor = RgbColor(0, 255, 0);
          strip.ClearTo(curentColor);
          strip.Show();
          delay(500);
          curentColor = RgbColor(confR, confG, confB);
          strip.ClearTo(curentColor);
          strip.Show();
          confR = +newPosition;
          myEnc.write(confG);
          break;
        case 2:
          Serial.println("Set blue" );
          curentColor = RgbColor(0, 0, 255);
          strip.ClearTo(curentColor);
          strip.Show();
          delay(500);
          curentColor = RgbColor(confR, confG, confB);
          strip.ClearTo(curentColor);
          strip.Show();
          confG = +newPosition;
          myEnc.write(confB);
          break;
       /* case 3:
        *  // intensidty code is nobready
          Serial.println("Set intenisty" );
          curentColor = RgbColor(255, 255, 255);
          strip.ClearTo(curentColor);
          strip.Show();
          delay(500);
          curentColor = RgbColor(confR, confG, confB);
          strip.ClearTo(curentColor);
          strip.Show();
          confB = +newPosition;
          myEnc.write(confB);
         */
        case 3:
          Serial.println("Done config" );
          curentColor = RgbColor(255, 255, 255);
          strip.ClearTo(curentColor);
          strip.Show();
          delay(500);
          curentColor = RgbColor(confR, confG, confB);
          strip.ClearTo(curentColor);
          strip.Show();
          confB = +newPosition;
          confRGBIparamater = 0;
          myEnc.write(confI);
          confRGBIDone = true;
          break;
        default:
          break;

      }

// save data to EEPROM
      if (confRGBIDone == true) {
        //reset loop flags
        confRGBIDone = false;
        confRGBInprogress = false;
        confRGBIparamater = 0;
        // save to EEPROM
        EEPROM.write(0, confR);
        EEPROM.write(1, confG);
        EEPROM.write(2, confB);
        EEPROM.write(3, confI);
        //display
        Serial.print("EEPROM saved R:" );
        Serial.print(confR );
        Serial.print(" / G:" );
        Serial.print(confG );
        Serial.print(" / B:" );
        Serial.print(confB );
        Serial.print( " / I: " );
        Serial.println(confI );
      }
      else
      {

        confRGBIparamater++;

      }


    }

  }

}
