/*******************************************************************************
 * Copyright (C) 2009-2011 Sean Voisen <http://sean.voisen.org> 
 * All rights reserved.
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
#include "Wire.h" // Used for communicating over I2C
#include "DS1307RTC.h" // Library for RTC tasks
#include "Bluenumi.h" // Locally-used data types
#include "Display.h" // Numitron display control
#include "LEDController.h" // Underlighting control
#include "AudioController.h" // Piezo buzzer control
#include "Bounce.h" // Button debouncing

/*******************************************************************************
 *
 * Pin Mappings
 *
 ******************************************************************************/
#define AMPM_PIN 1 // Both RX and used for AMPM indicator LED
#define ALRM_PIN 0 // Both TX and used for alarm indicator LED
#define HZ_PIN 4 // 1 Hz pulse from DS1307 RTC
#define TIME_BTN_PIN 5 // Time set/left button
#define ALRM_BTN_PIN 2 // Alarm set/right button

/*******************************************************************************
 *
 * Misc Defines
 *
 ******************************************************************************/
#define DEBOUNCE_INTERVAL 40 // Interval to wait when debouncing buttons
#define LONG_PRESS 2000 // Length of time that qualifies as a long button press
#define BLINK_DELAY 500 // Length of display blink on/off interval

#define UNBLANK_INTERVAL 3000 // Length of time to temp unblank display in 
                              // run blank mode

/*******************************************************************************
 *
 * Debug Defines
 *
 ******************************************************************************/
//#define DEBUG true
//#define DEBUG_BAUD 9600

/*******************************************************************************
 *
 * Variables
 *
 ******************************************************************************/
byte timeSetHours = 12;
byte timeSetMinutes = 0;
boolean timeSetTwelveHourMode = true;
boolean timeSetAmPm = false;

byte alarmHours = 12; 
byte alarmMinutes = 0;
boolean alarmAmPm = false;
boolean alarmEnabled = false;
boolean alarmRecentlySnuffed = false;

boolean skipNextBlink = false;

Bounce timeSetButtonDebouncer = Bounce(TIME_BTN_PIN, DEBOUNCE_INTERVAL);
Bounce alarmSetButtonDebouncer = Bounce(ALRM_BTN_PIN, DEBOUNCE_INTERVAL);

// Timer to track temporary display unblanking when in run blank mode
unsigned long unblankTime = 0;

// Set to true when time display needs updating
volatile boolean displayDirty = true; 

// Keeps track of current run mode (RUN, SET_TIME, etc.)
enum RunMode currentRunMode = RUN;

// Keeps track of current sub-mode when setting time and alarm
enum SetMode currentSetMode = NONE;

// Keeps track of when time (left) button was pressed, mostly used to detect
// long presses (this value is set during an interrupt)
volatile unsigned long timeSetButtonPressTime = 0;

// Keeps track of when alarm (right) button was pressed, mostly used to detect
// long presses (this value is set during an interrupt)
volatile unsigned long alarmSetButtonPressTime = 0; 

// Function pointers for state machine handler functions
ModeHandler runModeHandlerMap[NUM_RUN_MODES] = {NULL};
ModeHandler setModeHandlerMap[NUM_SET_MODES] = {NULL};
ButtonHandler timeButtonHandlerMap[NUM_RUN_MODES] = {NULL};
ButtonHandler alarmButtonHandlerMap[NUM_RUN_MODES] = {NULL};
CycleHandler setModeCycleHandlerMap[NUM_SET_MODES] = {NULL};

/*******************************************************************************
 *
 * Arduino "Setup" and "Loop"
 *
 ******************************************************************************/

void setup()
{
#if DEBUG
Serial.begin(DEBUG_BAUD);
Serial.println("Bluenumi");
Serial.println("Firmware Version 001");
#endif
 
  // Set up pin modes
  pinMode(AMPM_PIN, OUTPUT);
  pinMode(ALRM_PIN, OUTPUT);
  pinMode(HZ_PIN, INPUT);
  pinMode(TIME_BTN_PIN, INPUT);
  pinMode(ALRM_BTN_PIN, INPUT);
 
  // Pull-up resistors for buttons and DS1307 square wave
  digitalWrite(HZ_PIN, HIGH);
  digitalWrite(TIME_BTN_PIN, HIGH);
  digitalWrite(ALRM_BTN_PIN, HIGH);
  
  // The Arduino libraries do not support enough interrupts, so here we use
  // standard AVR libc interrupt vectors for the two buttons, and the RTC
  // square wave
  PCICR |= (1 << PCIE2);
  PCMSK2 |= (1 << PCINT18); // Alarm button
  PCMSK2 |= (1 << PCINT20); // RTC square wave
  PCMSK2 |= (1 << PCINT21); // Time button

  // Start 2-wire communication with DS1307
  DS1307RTC.begin();

  // Start numitron display
  Display.begin();

  // Start LED patterns
  LEDs.begin();

  // Map handlers
  mapModeHandlers();
  mapButtonHandlers();
  mapCycleHandlers();

  // Set alarm indicator
  updateAlarmIndicator();
  
  // Check CH bit in DS1307, if it's 1 then the clock is not started
  if (!DS1307RTC.isRunning()) 
  {
#if DEBUG
Serial.println("RTC not running; switching to set time mode");
#endif
    // Start at default time
    DS1307RTC.setDateTime(0, timeSetMinutes, timeSetHours, 1, 1, 1, 0, 
        timeSetTwelveHourMode, timeSetAmPm, true, 0x10);

    // Set default alarm settings
    saveAlarmToRam();

    // Clock is not running, probably powering up for the first time, change 
    // mode to set time
    changeRunMode(SET_TIME);
  }
  else
  {
    getAlarmFromRam();
#if DEBUG
Serial.println("Got alarm settings from RAM");
Serial.print(alarmHours);
Serial.print(":");
Serial.println(alarmMinutes);
#endif
  }
}

void loop()
{
  // Take care of any button presses first
  if (timeSetButtonPressTime > 0 && alarmSetButtonPressTime > 0)
  {
    processDualButtonPress();
  }
  else if (timeSetButtonPressTime > 0)
  {
    processTimeButtonPress();
  }
  else if (alarmSetButtonPressTime > 0)
  {
    processAlarmButtonPress();
  }
  
  // Call the handler function for the current mode (state)
  runModeHandlerMap[currentRunMode]();
}

/*******************************************************************************
 *
 * Additional Setup
 *
 ******************************************************************************/

/**
 * Map the various run modes to run mode handler functions.
 * Map the various set sub-modes to set mode handler functions.
 */
void mapModeHandlers()
{
  runModeHandlerMap[RUN] = &runModeHandler;
  runModeHandlerMap[SET_TIME] = &setTimeModeHandler;
  runModeHandlerMap[SET_ALARM] = &setAlarmModeHandler;
  runModeHandlerMap[RUN_BLANK] = &runBlankModeHandler;
  runModeHandlerMap[RUN_ALARM] = &runAlarmModeHandler;

  setModeHandlerMap[NONE] = &noneSetModeHandler;
  setModeHandlerMap[HR_12_24] = &hour12_24SetModeHandler;
  setModeHandlerMap[HR_TENS] = &hourTensSetModeHandler;
  setModeHandlerMap[HR_ONES] = &hourOnesSetModeHandler;
  setModeHandlerMap[MIN_TENS] = &minTensSetModeHandler;
  setModeHandlerMap[MIN_ONES] = &minOnesSetModeHandler;
  setModeHandlerMap[AMPM] = &ampmSetModeHandler;
}

/**
 * Map button presses in different run modes to their handler functions.
 */
void mapButtonHandlers()
{
  // Time button handlers
  timeButtonHandlerMap[RUN] = &runModeTimeButtonHandler;
  timeButtonHandlerMap[SET_TIME] = &setModeTimeButtonHandler;
  timeButtonHandlerMap[RUN_BLANK] = &runBlankModeButtonHandler;
  timeButtonHandlerMap[SET_ALARM] = &setModeTimeButtonHandler;
  timeButtonHandlerMap[RUN_ALARM] = &runAlarmModeButtonHandler;

  // Alarm button handlers
  alarmButtonHandlerMap[RUN] = &runModeAlarmButtonHandler;
  alarmButtonHandlerMap[SET_TIME] = &setModeAlarmButtonHandler;
  alarmButtonHandlerMap[RUN_BLANK] = &runBlankModeButtonHandler;
  alarmButtonHandlerMap[SET_ALARM] = &setModeAlarmButtonHandler;
  alarmButtonHandlerMap[RUN_ALARM] = &runAlarmModeButtonHandler;
}

/**
 * Map handlers that cycle (advance) through the various set sub-modes.
 * For instance, the advance handler for the minute tens digit cycles
 * the output of that digit from 0 to 5.
 */
void mapCycleHandlers()
{
  // Convenience pointer
  CycleHandler *map = &setModeCycleHandlerMap[0];

  map[NONE] = &noneSetModeCycleHandler;
  map[HR_12_24] = &twelveHourSetModeCycleHandler;
  map[HR_TENS] = &hourTensSetModeCycleHandler;
  map[HR_ONES] = &hourOnesSetModeCycleHandler;
  map[MIN_TENS] = &minTensSetModeCycleHandler;
  map[MIN_ONES] = &minOnesSetModeCycleHandler;
  map[AMPM] = &ampmSetModeCycleHandler;
}

void changeRunMode(enum RunMode newMode)
{
  switch (newMode)
  {
    case SET_TIME:
      LEDs.setEnabled(false);
      fetchTime(&timeSetHours, &timeSetMinutes, &timeSetAmPm, &timeSetTwelveHourMode);
      changeSetMode(NONE);
      break;

    case SET_ALARM:
      LEDs.setEnabled(false);
      timeSetHours = alarmHours;
      timeSetMinutes = alarmMinutes;
      timeSetAmPm = alarmAmPm;
      changeSetMode(NONE);
      break;

    case RUN:
      enableEntireDisplay();
      break;

    case RUN_BLANK:
      disableEntireDisplay();
      break;

    case RUN_ALARM:
      enableEntireDisplay();
      break;

    default:
      // NO-OP
      break;
  }

  currentRunMode = newMode;
}

void changeSetMode(enum SetMode newMode)
{
  currentSetMode = newMode;
}

/*******************************************************************************
 *
 * Run Mode Handlers 
 *
 ******************************************************************************/

void runModeHandler()
{
  LEDs.update();
  updateTime();
}

void setTimeModeHandler()
{
  // Call the set mode sub-mode handlers
  setModeHandlerMap[currentSetMode]();
}

void setAlarmModeHandler()
{
  // Call the set mode sub-mode handlers
  setModeHandlerMap[currentSetMode]();
}

void runBlankModeHandler()
{
  updateTime();

  if (unblankTime == 0)
    return;

  if (millis() - unblankTime > UNBLANK_INTERVAL)
  {
    disableEntireDisplay();
    unblankTime = 0;
  }
}

void runAlarmModeHandler()
{
  updateTime();

  Audio.singleBeep();
  delay(DUR_E);
}

/*******************************************************************************
 *
 * Button Handlers 
 *
 ******************************************************************************/

void runModeTimeButtonHandler(boolean longPress)
{
  if (longPress)
    changeRunMode(SET_TIME);
}

void runModeAlarmButtonHandler(boolean longPress)
{
  if (longPress)
  {
    changeRunMode(SET_ALARM);
  }
  else
  {
    toggleAlarm();
  }
}

void setModeTimeButtonHandler(boolean longPress)
{
  if (longPress && currentRunMode == SET_TIME)
  {
    // Edge case that can happen when switching between 12/24 hour mode
    if (timeSetTwelveHourMode && timeSetHours > 12)
    {
      timeSetHours = timeSetHours % 12;
    }

    DS1307RTC.setDateTime(0, timeSetMinutes, timeSetHours, 1, 1, 1, 0, 
        timeSetTwelveHourMode, timeSetAmPm, true, 0x10);
    enableEntireDisplay();
    changeRunMode(RUN);
  }
  else
  {
#if DEBUG
Serial.println("Cycle current mode");
#endif
    cycleCurrentSetMode();
  }
}

void setModeAlarmButtonHandler(boolean longPress)
{
  if (longPress && currentRunMode == SET_ALARM)
  {
    enableEntireDisplay();
    alarmHours = timeSetHours;
    alarmMinutes = timeSetMinutes;
    alarmAmPm = timeSetAmPm;
    saveAlarmToRam();
    changeRunMode(RUN);
  }
  else
  {
#if DEBUG
Serial.println("Next set mode");
#endif
    proceedToNextSetMode();
  }
}

void runBlankModeButtonHandler(boolean longPress)
{
  if (longPress)
  {
    // NO-OP
  }
  else if (unblankTime == 0)
  {
    unblankTime = millis();
    enableDisplayWithoutLEDs();
  }
}

void runAlarmModeButtonHandler(boolean longPress)
{
  // Turn off the alarm
  alarmRecentlySnuffed = true;
  changeRunMode(RUN);
}

/*******************************************************************************
 *
 * Set Time/Alarm Sub-mode Handlers
 *
 ******************************************************************************/

void noneSetModeHandler()
{
  if (blinkShouldBeOn()) 
  { 
    outputSetTime();
    enableEntireDisplay();
  }
  else 
  {
    disableEntireDisplay();
  }
}

void hour12_24SetModeHandler()
{
  if (blinkShouldBeOn())
  {
    byte val = timeSetTwelveHourMode ? 12 : 24;

    Display.outputBytes(Display.mapBcd(val/10), Display.mapBcd(val%10), SegmentDisplay::H, SegmentDisplay::R);
    enableEntireDisplay();
  }
  else
  {
    disableEntireDisplay();
  }
}

void hourTensSetModeHandler()
{
  if (blinkShouldBeOn())
  {
    outputSetTime();
    enableEntireDisplay();
  }
  else
  {
    Display.outputDigits(0xFF, timeSetHours%10, timeSetMinutes/10, timeSetMinutes%10);
    Display.setEnabled(true);
    LEDs.setLEDStates(false, true, true, true);
  }
}

void hourOnesSetModeHandler()
{
  if (blinkShouldBeOn())
  {
    outputSetTime();
    enableEntireDisplay();
  }
  else
  {
    Display.outputDigits(timeSetHours/10, 0xFF, timeSetMinutes/10, timeSetMinutes%10);
    Display.setEnabled(true);
    LEDs.setLEDStates(true, false, true, true);
  }
}

void minTensSetModeHandler()
{
  if (blinkShouldBeOn())
  {
    outputSetTime();
    enableEntireDisplay();
  }
  else
  {
    Display.outputDigits(timeSetHours/10, timeSetHours%10, 0xFF, timeSetMinutes%10);
    Display.setEnabled(true);
    LEDs.setLEDStates(true, true, false, true);
  }
}

void minOnesSetModeHandler()
{
  if (blinkShouldBeOn())
  {
    outputSetTime();
    enableEntireDisplay();
  }
  else
  {
    Display.outputDigits(timeSetHours/10, timeSetHours%10, timeSetMinutes/10, 0xFF);
    Display.setEnabled(true);
    LEDs.setLEDStates(true, true, true, false);
  }
}

void ampmSetModeHandler()
{
  if (blinkShouldBeOn())
  {
    Display.outputBytes(
        0,
        timeSetAmPm ? SegmentDisplay::P : SegmentDisplay::A, 
        SegmentDisplay::M,
        0
    );
    Display.setEnabled(true);
    LEDs.setLEDStates(true, true, true, true);
    digitalWrite(AMPM_PIN, timeSetAmPm ? HIGH : LOW);
  }
  else
  {
    disableEntireDisplay();
  }
}

/*******************************************************************************
 *
 * Set Time/Alarm Sub-mode Cycle Handlers
 *
 ******************************************************************************/

void noneSetModeCycleHandler()
{
  // NO-OP
}

void twelveHourSetModeCycleHandler()
{
  timeSetTwelveHourMode = !timeSetTwelveHourMode;

  if (!timeSetTwelveHourMode)
    return;

  timeSetAmPm = timeSetHours > 12;
}

void hourTensSetModeCycleHandler()
{
  byte tens = timeSetHours / 10;
  byte ones = timeSetHours % 10;
  byte divisor = (timeSetTwelveHourMode ? 2 : 3);

  timeSetHours = ((tens + 1) % divisor)*10 + ones;

  if (!timeSetTwelveHourMode)
    return;

  timeSetAmPm = timeSetHours > 12;
}

void hourOnesSetModeCycleHandler()
{
  byte tens = timeSetHours / 10;
  byte ones = timeSetHours % 10;
  byte divisor;

  if (tens == 0)
  {
    divisor = 10;
  }
  else if (tens == 1)
  {
    divisor = (timeSetTwelveHourMode ? 3 : 10);
  }
  else
  {
    divisor = 4;
  }

  timeSetHours = tens*10 + ((ones + 1) % divisor);
}

void minTensSetModeCycleHandler()
{
  byte tens = timeSetMinutes / 10;
  byte ones = timeSetMinutes % 10;

  timeSetMinutes = ((tens + 1) % 6)*10 + ones;
}

void minOnesSetModeCycleHandler()
{
  byte tens = timeSetMinutes / 10;
  byte ones = timeSetMinutes % 10;

  timeSetMinutes = tens*10 + ((ones + 1) % 10);
}

void ampmSetModeCycleHandler()
{
  timeSetAmPm = !timeSetAmPm;
}

/*******************************************************************************
 *
 * Helper Methods
 *
 ******************************************************************************/

/**
 * Outputs the time to be set. This is the time that is temporarily stored
 * for manipulation while the clock is in time set mode or alarm set mode.
 */
void outputSetTime()
{
  Display.outputTime(timeSetHours, timeSetMinutes);
  digitalWrite(AMPM_PIN, timeSetAmPm);
}

void cycleCurrentSetMode()
{
  if (currentSetMode != NONE)
    skipNextBlink = true;

  setModeCycleHandlerMap[currentSetMode]();
}

/**
 * Moves to the next sub mode when setting the time or the alarm.
 */
void proceedToNextSetMode()
{
  // For 24 hour mode, skip setting AM/PM
  byte divisor = timeSetTwelveHourMode ? NUM_SET_MODES : NUM_SET_MODES - 1;

  // For alarm set, skip 12/24 hour setting
  byte increment = (currentSetMode == NONE && currentRunMode == SET_ALARM) ? 2 : 1;

  // Warning: This assumes the enum values are listed in order of procession!
  currentSetMode = (SetMode) ((currentSetMode + increment) % divisor);
}

/**
 * Toggle the alarm enable state.
 */
void toggleAlarm()
{
  alarmEnabled = !alarmEnabled;
  updateAlarmIndicator();
  Audio.singleBeep();
  saveAlarmToRam();
}

/**
 * Used for blinking the display on and off. Determines if the display should 
 * be on (true) or off (false) using a set interval BLINK_DELAY.
 */
boolean blinkShouldBeOn()
{
  static unsigned long lastBlinkTime = 0;
  static boolean blinkOn = true;

  if (millis() - lastBlinkTime >= BLINK_DELAY) 
  {
    if (skipNextBlink)
    {
      blinkOn = true;
      skipNextBlink = false;
    }
    else
    {
      blinkOn = !blinkOn;
    }

    lastBlinkTime = millis();
  }

  return blinkOn;
}

/**
 * Display the current time on the numitrons.
 */
void updateTime()
{
  if (displayDirty)
  {
    byte minute, hour;
    boolean ampm, twelveHourMode;

    fetchTime(&hour, &minute, &ampm, &twelveHourMode);

    if (Display.getEnabled())
    {
      Display.outputTime(hour, minute);
      digitalWrite(AMPM_PIN, ampm);
    }

    checkAlarm(hour, minute, ampm, twelveHourMode);

    displayDirty = false;
  }
}

/**
 * Checks to see if the alarm needs to be turned on
 */
void checkAlarm(byte currentHours, byte currentMinutes, boolean currentAmPm, boolean twelveHourMode)
{
  if (currentMinutes != alarmMinutes)
  {
    if (alarmRecentlySnuffed)
      alarmRecentlySnuffed = false;

    // Turn off the alarm once a minute has passed if no button was pressed
    if (currentRunMode == RUN_ALARM)
      changeRunMode(RUN);

    return;
  }
  
  if (alarmEnabled && 
      (currentRunMode == RUN || currentRunMode == RUN_BLANK) && 
      !alarmRecentlySnuffed &&
      currentHours == alarmHours && 
      currentMinutes == alarmMinutes &&
      ((currentAmPm == alarmAmPm && twelveHourMode == true) || twelveHourMode == false))
  {
    // Turn on the alarm
#if DEBUG
Serial.println("Turning on alarm");
#endif
    changeRunMode(RUN_ALARM);
  }
}

/**
 * Fetches the current time from the DS1307 RTC.
 */
boolean fetchTime(byte* hour, byte* minute, boolean* ampm, boolean* twelveHourMode)
{
  byte second, dayOfWeek, dayOfMonth, month, year;
  DS1307RTC.getDateTime(&second, minute, hour, &dayOfWeek, &dayOfMonth, 
      &month, &year, (bool*)twelveHourMode, (bool*)ampm);
  
  return true;
}

/**
 * Alarm settings preservation scheme:
 *
 * Byte 0 = Hours
 * Byte 1 = Minutes
 * Byte 2 = AM/PM
 * Byte 3 = Enabled?
 */
void saveAlarmToRam()
{
  DS1307RTC.ramBuffer[0] = alarmHours;
  DS1307RTC.ramBuffer[1] = alarmMinutes;
  DS1307RTC.ramBuffer[2] = alarmAmPm;
  DS1307RTC.ramBuffer[3] = alarmEnabled;
  DS1307RTC.saveRamData(4);
}

void getAlarmFromRam()
{
  DS1307RTC.getRamData(4);
  alarmHours = (byte) DS1307RTC.ramBuffer[0];
  alarmMinutes = (byte) DS1307RTC.ramBuffer[1];
  alarmAmPm = (boolean) DS1307RTC.ramBuffer[2];
  alarmEnabled = (boolean) DS1307RTC.ramBuffer[3];
  updateAlarmIndicator();
}

void processDualButtonPress()
{
  boolean longPress = timeSetButtonPressedLong() && alarmSetButtonPressedLong();

  if ((alarmSetButtonDebouncer.read() && timeSetButtonDebouncer.read()) || longPress)
  {
#if DEBUG
Serial.print(longPress ? "Long" : "Short");
Serial.println(" dual button press");
#endif
    timeSetButtonPressTime = 0;
    alarmSetButtonPressTime = 0;

    // Only use run mode for now
    if (currentRunMode == RUN)
    {
      changeRunMode(RUN_BLANK);
    }
    else if (currentRunMode == RUN_BLANK)
    {
      changeRunMode(RUN);
    }
  }
}

void processTimeButtonPress()
{
  boolean longPress = timeSetButtonPressedLong();

  if (timeSetButtonDebouncer.read() || longPress) 
  {
#if DEBUG
Serial.print(longPress ? "Long" : "Short");
Serial.println(" time button press");
#endif
  
    timeSetButtonPressTime = 0;
    timeButtonHandlerMap[currentRunMode](longPress);
  }
}

void processAlarmButtonPress()
{
  boolean longPress = alarmSetButtonPressedLong();

  if (alarmSetButtonDebouncer.read() || longPress)
  {
#if DEBUG
Serial.print(longPress ? "Long" : "Short");
Serial.println(" alarm button press");
#endif
  
    alarmSetButtonPressTime = 0;
    alarmButtonHandlerMap[currentRunMode](longPress);
  }
}

inline boolean alarmSetButtonPressedLong()
{
  alarmSetButtonDebouncer.update();
  return (!alarmSetButtonDebouncer.read() && (millis() - alarmSetButtonPressTime >= LONG_PRESS));
}

inline boolean timeSetButtonPressedLong()
{
  timeSetButtonDebouncer.update();
  return (!timeSetButtonDebouncer.read() && (millis() - timeSetButtonPressTime >= LONG_PRESS));
}

/**
 * Blanks the entire display, both numitrons and all LEDs.
 */
void disableEntireDisplay()
{
  Display.setEnabled(false);
  LEDs.setEnabled(false);
  digitalWrite(AMPM_PIN, LOW);
  digitalWrite(ALRM_PIN, LOW);
}

/**
 * Unblanks the entire display, both numitrons and all LEDs.
 */
void enableEntireDisplay()
{
  enableDisplayWithoutLEDs();
  LEDs.setEnabled(true);
}

void enableDisplayWithoutLEDs()
{
  Display.setEnabled(true);
  updateAlarmIndicator();
  updateAmPmIndicator();
}

void updateAmPmIndicator()
{
  digitalWrite(AMPM_PIN, timeSetAmPm);
}

void updateAlarmIndicator()
{
  digitalWrite(ALRM_PIN, alarmEnabled);
}

/**
 * This interrupt will be called every time the DS1307 square wave pin changes 
 * or a button is pressed. For the RTC, at 1Hz this means this will be called 
 * twice per second (high to low, low to high).
 */
ISR (PCINT2_vect)
{
  // Instead of digitalRead, we'll read the port directly for Arduino digital 
  // pin 2, 4 and 5 (all of which reside in PORTD)
  // This keeps the execution time of the interrupt a bit shorter
  
  // Check for RTC square wave low
  // Here, we look for when pin 4 (4th bit in PIND) is pulled low (value == 0), 
  // meaning 1 second has passed
  if ((PIND & 0x10) == 0) 
    displayDirty = true;
  
  // Check for time button press (pulled low) on pin 5
  if (timeSetButtonDebouncer.update() && !timeSetButtonDebouncer.read())
    timeSetButtonPressTime = millis();

  // Check for alarm button press (pulled low) on pin 2
  if (alarmSetButtonDebouncer.update() && !alarmSetButtonDebouncer.read())
    alarmSetButtonPressTime = millis();
}
