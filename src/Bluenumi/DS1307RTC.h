/*******************************************************************************
 * Copyright (C) 2008 Maurice Ribble <http://www.glacialwanderer.com>
 *
 * Modified by Sean Voisen <http://sean.voisen.org>
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

#ifndef DS1307RTC_H_
#define DS1307RTC_H_

#include "Wire.h"
#include <inttypes.h>

#define DS1307_I2C_ADDRESS 0x68

class DS1307
{
  public:
    enum ControlRegister
    {
      CR_1HZ_LOW = 0x10,
      CR_1HZ_HIGH = 0x90,
      CR_4KHZ_LOW = 0x11,
      CR_4KHZ_HIGH = 0x91,
      CR_8KHZ_LOW = 0x12,
      CR_8KHZ_HIGH = 0x92,
      CR_32KHZ_LOW = 0x13,
      CR_32KHZ_HIGH = 0x93,
      CR_DISABLE_LOW = 0x00,
      CR_DISABLE_HIGH = 0x80
    };
    
    DS1307();
    void begin();
    void setDateTime(uint8_t, uint8_t, uint8_t, uint8_t, uint8_t, uint8_t, uint8_t, bool, bool, bool, uint8_t);
    void getDateTime(uint8_t*, uint8_t*, uint8_t*, uint8_t*, uint8_t*, uint8_t*, uint8_t*, bool*, bool*);
    bool isRunning();
    
  private:
    uint8_t decToBcd(uint8_t);
    uint8_t bcdToDec(uint8_t);
};

extern DS1307 DS1307RTC;

#endif // DS1307RTC_H_
