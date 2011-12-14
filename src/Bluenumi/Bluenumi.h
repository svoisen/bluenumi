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

#ifndef BLUENUMI_H_
#define BLUENUMI_H_

#include <Arduino.h>

#define NUM_RUN_MODES 5
#define NUM_SET_MODES 7

enum RunMode 
{
  RUN = 0,
  RUN_BLANK,
  RUN_ALARM,
  SET_TIME,
  SET_ALARM
}; 

enum SetMode
{
  NONE = 0,
  HR_12_24,
  HR_TENS,
  HR_ONES,
  MIN_TENS,
  MIN_ONES,
  AMPM
};

typedef void (*ModeHandler)();
typedef void (*CycleHandler)();
typedef void (*ButtonHandler)(boolean);

#endif
