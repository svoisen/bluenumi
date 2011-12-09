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

#ifndef DISPLAY_H_
#define DISPLAY_H_

#include <Arduino.h>
#include <inttypes.h>

#define DATA_PIN 13
#define LATCH_PIN 12
#define CLK_PIN 6
#define OE_PIN 7

class SegmentDisplay
{
  public:
    enum CharCode
    {
      A = 0b01111101,
      P = 0b01011101,
      H = 0b01101101,
      R = 0b00000101
    };
    
    SegmentDisplay();
    void begin();
    void outputTime(uint8_t, uint8_t);
    void outputDigits(uint8_t, uint8_t, uint8_t, uint8_t);
    void outputBytes(uint8_t, uint8_t, uint8_t, uint8_t);
    void setEnabled(bool);
    uint8_t mapBcd(uint8_t);

  private:
    static uint8_t bcdMap[10];
    void shift(uint8_t);
};

extern SegmentDisplay Display;

#endif // DISPLAY_H_
