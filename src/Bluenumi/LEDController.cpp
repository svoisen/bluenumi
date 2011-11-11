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

#include "LEDController.h"

LEDController::LEDController()
{
  mapHandlers();
}

void LEDController::begin()
{
  enabled = true;
  currentType = ROLLING_BREATHE;
  
  pinMode(SECONDS0_PIN, OUTPUT);
  pinMode(SECONDS1_PIN, OUTPUT);
  pinMode(SECONDS2_PIN, OUTPUT);
  pinMode(SECONDS3_PIN, OUTPUT);
}

void LEDController::update()
{
  if (!enabled)
    return;

  CALL_MEMBER_FN(this, patternHandlerMap[currentType])();
}

void LEDController::setEnabled(bool value)
{
  enabled = value;
  setLEDStates(value, value, value, value);
}

void LEDController::setLEDStates(bool led0, bool led1, bool led2, bool led3)
{
  digitalWrite(SECONDS0_PIN, led0);
  digitalWrite(SECONDS1_PIN, led1);
  digitalWrite(SECONDS2_PIN, led2);
  digitalWrite(SECONDS3_PIN, led3);
}

void LEDController::mapHandlers()
{
  patternHandlerMap[BREATHE] = &LEDController::breatheHandler;
  patternHandlerMap[ROLLING_BREATHE] = &LEDController::rollingBreatheHandler;
}

void LEDController::breatheHandler()
{
  float val = calculateBreatheVal(PI/2.0, 0.0);
  analogWrite(SECONDS0_PIN, val);
  analogWrite(SECONDS1_PIN, val);
  analogWrite(SECONDS2_PIN, val);
  analogWrite(SECONDS3_PIN, val);
}

void LEDController::rollingBreatheHandler()
{
  float freqAdj = PI/2.0;
  analogWrite(SECONDS3_PIN, calculateBreatheVal(freqAdj, 0.0));
  analogWrite(SECONDS2_PIN, calculateBreatheVal(freqAdj, PI/4.0));
  analogWrite(SECONDS1_PIN, calculateBreatheVal(freqAdj, PI/2.0)); 
  analogWrite(SECONDS0_PIN, calculateBreatheVal(freqAdj, 3*PI/4.0));
}

float LEDController::calculateBreatheVal(float frequencyAdjust, float offset)
{
  return (exp(sin(millis()/1000.0*frequencyAdjust + offset)) - 0.36787944)*108.0;
}

LEDController LEDs = LEDController();
