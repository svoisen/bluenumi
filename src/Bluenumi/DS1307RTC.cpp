/*******************************************************************************
 * Copyright (C) 2008 Maurice Ribble <http://www.glacialwanderer.com>
 * Modifications Copyright (C) 2011 Sean Voisen <http://sean.voisen.org>
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

extern "C" {
  #include <inttypes.h>
}

#include "DS1307RTC.h"

DS1307::DS1307()
{
}

void DS1307::begin()
{
  Wire.begin();
}

void DS1307::setDateTime( 
  uint8_t second, 
  uint8_t minute, 
  uint8_t hour, 
  uint8_t dayOfWeek, 
  uint8_t dayOfMonth, 
  uint8_t month, 
  uint8_t year,
  bool twelveHourMode,
  bool ampm,
  bool startClock,
  uint8_t controlRegister) 
{
  Wire.beginTransmission(DS1307_I2C_ADDRESS);
  Wire.write((uint8_t) 0x00);
  Wire.write(decToBcd(second) | (startClock ? 0x00 : 0x80 )); // 0 to bit 7 starts the clock, 1 stops
  Wire.write(decToBcd(minute));

  if (twelveHourMode) 
  {
    Wire.write(decToBcd(hour) | ( ampm ? 0x60 : 0x40 ) );
  }
  else 
  {
    Wire.write( decToBcd( hour ) );
  }

  Wire.write( decToBcd( dayOfWeek ) );
  Wire.write( decToBcd( dayOfMonth ) );
  Wire.write( decToBcd( month ) );
  Wire.write( decToBcd( year ) );
  Wire.write( controlRegister );
  Wire.endTransmission();
}

bool DS1307::isRunning()
{
  setRegisterPointer(0x00);
  
  Wire.requestFrom(DS1307_I2C_ADDRESS, 1);
  
  if (Wire.read() & 0x80) 
    return false;
  
  return true;
}

void DS1307::saveRamData(uint8_t numBytes)
{
  numBytes = min(numBytes, RAM_SIZE);

  Wire.beginTransmission(DS1307_I2C_ADDRESS);
  Wire.write((uint8_t) 0x08);

  for (uint8_t i = 0; i < numBytes; i++)
  {
    Wire.write(ramBuffer[i]);
  }

  Wire.endTransmission();
}

void DS1307::getRamData(uint8_t numBytes)
{
  numBytes = min(numBytes, RAM_SIZE);

  setRegisterPointer(0x08);

  Wire.requestFrom(DS1307_I2C_ADDRESS, RAM_SIZE);

  for (uint8_t i = 0; i < numBytes; i++)
  {
    ramBuffer[i] = Wire.read();
  }
}

void DS1307::getDateTime( 
  uint8_t *second, 
  uint8_t *minute, 
  uint8_t *hour, 
  uint8_t *dayOfWeek, 
  uint8_t *dayOfMonth, 
  uint8_t *month, 
  uint8_t *year,
  bool *twelveHourMode,
  bool *ampm )
{
  setRegisterPointer(0x00);

  Wire.requestFrom(DS1307_I2C_ADDRESS, 7);

  *second     = bcdToDec(Wire.read() & 0x7f); // Mask out the CH bit
  *minute     = bcdToDec(Wire.read());
  *hour       = Wire.read();
  *dayOfWeek  = bcdToDec(Wire.read());
  *dayOfMonth = bcdToDec(Wire.read());
  *month      = bcdToDec(Wire.read());
  *year       = bcdToDec(Wire.read());
  *twelveHourMode = (*hour & 0x40) == 0 ? false : true;
  
  if (*twelveHourMode) 
  {
    *ampm = (*hour & 0x20) == 0 ? false : true;
    *hour = bcdToDec(*hour & 0x1f);
  }
  else 
  {
    *hour = bcdToDec(*hour & 0x3f);
    *ampm = *hour >= 12 ? true : false;
  }
}

void DS1307::setRegisterPointer(uint8_t val)
{
  Wire.beginTransmission(DS1307_I2C_ADDRESS);
  Wire.write(val);
  Wire.endTransmission();
}

uint8_t DS1307::decToBcd(uint8_t val)
{
  return ((val/10*16) + (val%10));
}

uint8_t DS1307::bcdToDec(uint8_t val)
{
  return ((val/16*10) + (val%16));
}

DS1307 DS1307RTC = DS1307();
