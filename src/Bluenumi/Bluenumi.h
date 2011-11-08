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
 
#ifndef BLUENUMI_h
#define BLUENUMI_h

#include "WProgram.h"

#define NUM_RUN_MODES 4
#define NUM_SET_MODES 6

enum RunMode 
{
  RUN = 0,
  RUN_BLANK,
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
