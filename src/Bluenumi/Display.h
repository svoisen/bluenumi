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

#ifndef DISPLAY_H_
#define DISPLAY_H_

#include "WProgram.h"
#include "WConstants.h"
#include <inttypes.h>

#define DATA_PIN 13
#define LATCH_PIN 12
#define CLK_PIN 6
#define OE_PIN 7

class SegmentDisplay
{
  public:
    SegmentDisplay();
    void begin();
    void outputTime(uint8_t, uint8_t);
    void outputDigits(uint8_t, uint8_t, uint8_t, uint8_t);
    void outputBytes(uint8_t, uint8_t, uint8_t, uint8_t);
    void setEnabled(bool);

  private:
    static uint8_t bcdMap[10];
};

extern SegmentDisplay Display;

#endif // DISPLAY_H_
