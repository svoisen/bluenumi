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

#include "Pattern.h"

PatternGenerator::PatternGenerator()
{
  mapHandlers();
}

void PatternGenerator::begin()
{
  enabled = true;
  currentType = BREATHE;
  
  pinMode(SECONDS0_PIN, OUTPUT);
  pinMode(SECONDS1_PIN, OUTPUT);
  pinMode(SECONDS2_PIN, OUTPUT);
  pinMode(SECONDS3_PIN, OUTPUT);
}

void PatternGenerator::update()
{
  if (!enabled)
    return;

  CALL_MEMBER_FN(this, patternHandlerMap[currentType])();
}

void PatternGenerator::setEnabled(bool value)
{
  if (enabled == value)
    return;

  enabled = value;

  if (!enabled)
  {
    digitalWrite(SECONDS0_PIN, LOW);
    digitalWrite(SECONDS1_PIN, LOW);
    digitalWrite(SECONDS2_PIN, LOW);
    digitalWrite(SECONDS3_PIN, LOW);
  }
}

void PatternGenerator::mapHandlers()
{
  patternHandlerMap[BREATHE] = &PatternGenerator::breatheHandler;
}

void PatternGenerator::breatheHandler()
{
  float val = (exp(sin(millis()/2000.0*PI)) - 0.36787944)*108.0;
  analogWrite(SECONDS0_PIN, val);
  analogWrite(SECONDS1_PIN, val);
  analogWrite(SECONDS2_PIN, val);
  analogWrite(SECONDS3_PIN, val);
}

PatternGenerator Pattern = PatternGenerator();
