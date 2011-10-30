/*******************************************************************************
 * Gizmologist Bluenumi Clock Firmware
 * Version 1.0
 *
 * Copyright (C) 2010 Gizmologist, LLC. All rights reserved.
 * Author: Sean Voisen
 * Last Modified: 12/31/2009
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 ******************************************************************************/
 
#include <avr/interrupt.h> // Used for adding interrupts
#include "Wire.h" // Used for communicating with RTC
#include "DS1307RTC.h" // Ditto

/*******************************************************************************
 * Pin Mappings
 /*****************************************************************************/
#define SECONDS0_PIN 9 // LED under 10s hour
#define SECONDS1_PIN 10 // LED under 1s hour
#define SECONDS2_PIN 11 // LED under 10s minute
#define SECONDS3_PIN 3 // LED under 1s minute
#define DATA_PIN 13 // Data input to A6278 shift registers
#define LATCH_PIN 12 // Latch control for A6278 shift registers
#define CLK_PIN 6 // Clock for A6278 shift registers
#define OE_PIN 7 // Output enable on A6278 shift registers, active low
#define AMPM_PIN 0 // Both RX and used for AMPM indicator LED
#define ALRM_PIN 1 // Both TX and used for alarm indicator LED
#define PIEZO_PIN 8 // Piezo alarm
#define HZ_PIN 4 // 1 Hz pulse from DS1307 RTC
#define LEFT_BTN_PIN 2 // Time set/left button
#define RIGHT_BTN_PIN 5 // Alarm set/right button

#define SDA_PIN 4 // Analog pin, used for 2wire communication to DS1307
#define SCL_PIN 5 // Analog pin, used for 2wire communicatino to DS1307

/*******************************************************************************
 * Mode Defines
 /*****************************************************************************/
#define RUN_MODE 0
#define RUN_BLANK_MODE 1
#define SET_TIME_MODE 2
#define SET_ALARM_MODE 3

/*******************************************************************************
 * Misc Defines
 /*****************************************************************************/
#define DEBOUNCE_INTERVAL 20 // Interval to wait when debouncing buttons
#define LONG_PRESS 3000 // Length of time that qualifies as a long button press
#define BLINK_DELAY 500 // Length of display blink on/off interval

/*******************************************************************************
 * Debug Defines
 /*****************************************************************************/
#define DEBUG true
#if DEBUG
#define DEBUG_BAUD 9600
#endif

/*******************************************************************************
 * Time/Alarm Variables
 /*****************************************************************************/
unsigned int alarmHours, alarmMinutes = 0; // Variables that store when to set off the alarm!

/*******************************************************************************
 * Misc Variables
 /*****************************************************************************/
const int numbers[] = {123, 96, 87, 118, 108, 62, 47, 112, 127, 124};  // Array translates BCD to 7-segment output
volatile boolean updateDisplay = true; // Set to true when time display needs updating
byte mode = RUN_MODE; // Default to run mode
volatile unsigned long timeSetButtonPressTime = 0; // Keeps track of when time (left) button was pressed
volatile unsigned long alarmSetButtonPressTime = 0; // Keeps track of when alarm (right) button was pressed

/**
 * Sets up the program before running the continuous loop()
 */
void setup()
{
#if DEBUG
Serial.begin(DEBUG_BAUD);
Serial.println("Bluenumi");
Serial.println("Firmware Version 001");
#endif
 
  // Set up pin modes
  pinMode(SECONDS0_PIN, OUTPUT);
  pinMode(SECONDS1_PIN, OUTPUT);
  pinMode(SECONDS2_PIN, OUTPUT);
  pinMode(SECONDS3_PIN, OUTPUT);
  pinMode(DATA_PIN, OUTPUT);
  pinMode(LATCH_PIN, OUTPUT);
  pinMode(CLK_PIN, OUTPUT);
  pinMode(OE_PIN, OUTPUT);
  pinMode(AMPM_PIN, OUTPUT);
  pinMode(ALRM_PIN, OUTPUT);
  pinMode(PIEZO_PIN, OUTPUT);
  pinMode(HZ_PIN, INPUT);
  pinMode(LEFT_BTN_PIN, INPUT);
  pinMode(RIGHT_BTN_PIN, INPUT);
 
  // Pull-up resistors for buttons and DS1307 square wave
  digitalWrite(HZ_PIN, HIGH);
  digitalWrite(LEFT_BTN_PIN, HIGH);
  digitalWrite(RIGHT_BTN_PIN, HIGH);
  
  // Enable output
  digitalWrite(OE_PIN, LOW);
  
  // Set up interrupts
  //attachInterrupt(0, leftButtonPressed, LOW);
  //attachInterrupt(1, rightButtonPressed, LOW);
  
  // Arduino environment has only 2 interrupts, here we add a 3rd interrupt on Arduino digital pin 4 (PCINT20 XCK/TO)
  // This interrupt will be used to interface with the DS1307RTC square wave, and will be called every second (1Hz)
  PCICR |= (1 << PCIE2);
  PCMSK2 |= (1 << PCINT20);
  interrupts();

  // Start 2-wire communication with DS1307
  DS1307RTC.begin();
  
  // Check CH bit in DS1307, if it's 1 then the clock is not started
  if (!DS1307RTC.isRunning()) 
  {
#if DEBUG
Serial.println("RTC not running; switching to set time mode");
#endif
    // Clock is not running, probably powering up for the first time, change mode to set time
    //mode = SET_TIME_MODE;
    DS1307RTC.setDateTime(0, 0, 12, 1, 1, 1, 10, true, true, true, 0x10);
  }
}

/**
 * This function runs continously as long as the clock is powered on. When the clock is not
 * powered on the DS1307 will continue to keep time as long as it has a battery :)
 */
void loop()
{
  // Take care of any button presses first
  if (timeSetButtonPressTime > 0)
    handleTimeButtonPress();
  
  if (alarmSetButtonPressTime > 0)
    handleAlarmButtonPress();
  
  switch (mode) 
  {
    case RUN_MODE:
      if (updateDisplay) 
      { 
        // Only update time display as necessary
        fetchAndOutputTime();
        updateDisplay = false;
      }
      break;
    
    case RUN_BLANK_MODE:
      break;
      
    case SET_TIME_MODE:
      if (updateBlink()) 
      { 
        
      }
      else 
      {
        blankDisplay();
      }
      break;
      
    case SET_ALARM_MODE:
      break;
  }
}

/**
 * Used for blinking the display on and off. Determines if the display should be on (true) or off (false) using
 * a set interval BLINK_DELAY.
 */
boolean updateBlink()
{
  static unsigned long lastBlinkTime = 0;
  static boolean blinkOn = true;
  if (millis() - lastBlinkTime >= BLINK_DELAY) 
  {
    blinkOn = !blinkOn;
    lastBlinkTime = millis();
  }
  return blinkOn;
}

/**
 * Fetches the time from the DS1307 RTC and displays the time on the numitrons.
 */
void fetchAndOutputTime()
{
#if DEBUG
Serial.println("Fetching time from RTC");
#endif
  byte second, minute, hour, dayOfWeek, dayOfMonth, month, year;
  bool twelveHourMode, ampm;
  DS1307RTC.getDateTime(&second, &minute, &hour, &dayOfWeek, &dayOfMonth, &month, &year, &twelveHourMode, &ampm);

#if DEBUG
Serial.print("Got time from RTC: ");
Serial.print(hour, DEC);
Serial.print(":");
Serial.println(minute, DEC);
#endif
  
  digitalWrite(LATCH_PIN, LOW);
  shiftOut(DATA_PIN, CLK_PIN, MSBFIRST, numbers[hour/10]);
  shiftOut(DATA_PIN, CLK_PIN, MSBFIRST, numbers[hour%10]);
  shiftOut(DATA_PIN, CLK_PIN, MSBFIRST, numbers[minute/10]);
  shiftOut(DATA_PIN, CLK_PIN, MSBFIRST, numbers[minute%10]);
  digitalWrite(LATCH_PIN, HIGH);
  
  digitalWrite(AMPM_PIN, (ampm ? HIGH : LOW)); // Also output AMPM indicator light
}

void leftButtonPressed()
{
  static unsigned long lastInterruptTime = 0;
  unsigned long interruptTime = millis();
  
  if( interruptTime - lastInterruptTime > DEBOUNCE_INTERVAL ) {
    timeSetButtonPressTime = interruptTime;
  }
  
  lastInterruptTime = interruptTime;
}

void rightButtonPressed()
{
  static unsigned long lastInterruptTime = 0;
  unsigned long interruptTime = millis();
  
  if( interruptTime - lastInterruptTime > DEBOUNCE_INTERVAL ) {
    alarmSetButtonPressTime = interruptTime;
  }
  
  lastInterruptTime = interruptTime;
}

void setTimeReleased()
{
}

void setAlarmReleased()
{
}

void handleTimeButtonPress()
{
  boolean longPress = false;
  
  while( digitalRead( LEFT_BTN_PIN ) == LOW ) {
    if( millis() - timeSetButtonPressTime >= LONG_PRESS ) {
      longPress = true;
    }
  }
  
  switch( mode ) {
    case RUN_MODE:
      if( longPress ) {
        mode = SET_TIME_MODE;
      }
      break;
      
    case SET_TIME_MODE:
      if( longPress ) {
        // Save new time in DS1307
        mode = RUN_MODE;
      }
      else {
      }
      break;
  }
  
  timeSetButtonPressTime = 0;
}

void handleAlarmButtonPress()
{
  boolean longPress = false;
  
  while( digitalRead( RIGHT_BTN_PIN ) == LOW ) {
    if( millis() - alarmSetButtonPressTime >= LONG_PRESS ) {
      longPress = true;
    }
  }
  
  switch( mode ) {
    case RUN_MODE:
      if( longPress ) {
        mode = SET_ALARM_MODE;
      }
      break;
  }
}

/**
 * Blanks the display, both numitrons and all LEDs.
 */
void blankDisplay()
{
  digitalWrite( OE_PIN, HIGH );
  digitalWrite( SECONDS0_PIN, LOW );
  digitalWrite( SECONDS1_PIN, LOW );
  digitalWrite( SECONDS2_PIN, LOW );
  digitalWrite( SECONDS3_PIN, LOW );
  digitalWrite( AMPM_PIN, LOW );
  digitalWrite( ALRM_PIN, LOW );
}

/**
 * This interrupt will be called every time the DS1307 square wave pin changes. At 1Hz this means
 * 2 changes per second (high to low, low to high).
 */
ISR (PCINT2_vect)
{
  // Instead of digitalRead, we'll read the port directly for Arduino digital pin 4 (which resides in PORTD)
  // This keeps the execution time of the interrupt a bit shorter
  // Here, we look for when pin 4 (4th bit in PIND) is pulled low (value == 0), meaning 1 second has passed
  if ((PIND & 0x10) == 0) 
  {
    // TICK! Update the time!
    updateDisplay = true;
  }
}

