/*******************************************************************************
 * Copyright (C) 2011 Sean Voisen <http://sean.voisen.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 ******************************************************************************/

#include "Display.h"

uint8_t SegmentDisplay::bcdMap[10] = {
  0b01111011, // 0
  0b01100000, // 1
  0b01010111, // 2
  0b01110110, // 3
  0b01101100, // 4
  0b00111110, // 5
  0b00111111, // 6 (curly)
  0b01110000, // 7
  0b01111111, // 8
  0b01111110, // 9 (curly)
};

SegmentDisplay::SegmentDisplay()
{
}

void SegmentDisplay::begin()
{
  pinMode(DATA_PIN, OUTPUT);
  pinMode(LATCH_PIN, OUTPUT);
  pinMode(CLK_PIN, OUTPUT);
  pinMode(OE_PIN, OUTPUT);

  setEnabled(true);
}

void SegmentDisplay::outputTime(uint8_t hours, uint8_t minutes)
{
  outputDigits(hours/10, hours%10, minutes/10, minutes%10);
}

void SegmentDisplay::outputDigits(
    uint8_t first, 
    uint8_t second, 
    uint8_t third,
    uint8_t fourth)
{
  outputBytes(
      first == 0xFF ? 0 : bcdMap[first], 
      second == 0xFF ? 0 : bcdMap[second], 
      third == 0xFF ? 0 : bcdMap[third], 
      fourth == 0xFF ? 0 : bcdMap[fourth]
  );
}

void SegmentDisplay::outputBytes(
    uint8_t first,
    uint8_t second,
    uint8_t third,
    uint8_t fourth)
{
  digitalWrite(LATCH_PIN, LOW);
  shift(first);
  shift(second);
  shift(third);
  shift(fourth);
  digitalWrite(LATCH_PIN, HIGH);
}

void SegmentDisplay::setEnabled(bool enabled)
{
  digitalWrite(OE_PIN, enabled ? LOW : HIGH);
}

uint8_t SegmentDisplay::mapBcd(uint8_t input)
{
  return bcdMap[input];
}

void SegmentDisplay::shift(uint8_t val)
{
  shiftOut(DATA_PIN, CLK_PIN, MSBFIRST, val);
}

SegmentDisplay Display = SegmentDisplay();
