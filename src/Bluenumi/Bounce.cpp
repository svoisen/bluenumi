/*******************************************************************************
 * Copyright (C) Thomas O Fredericks
 * Rebounce and duration functions contributed by Eric Lowry
 * Write function contributed by Jim Schimpf
 * risingEdge and fallingEdge contributed by Tom Harkaway
 *
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

#include "Bounce.h"

Bounce::Bounce(uint8_t pin, unsigned long interval_millis)
{
	interval(interval_millis);
	previous_millis = millis();
	state = digitalRead(pin);
  this->pin = pin;
}

void Bounce::write(int new_state)
{
  this->state = new_state;
  digitalWrite(pin,state);
}

void Bounce::interval(unsigned long interval_millis)
{
  this->interval_millis = interval_millis;
  this->rebounce_millis = 0;
}

void Bounce::rebounce(unsigned long interval)
{
  this->rebounce_millis = interval;
}

int Bounce::update()
{
	if (debounce()) 
  {
    rebounce(0);
    return stateChanged = 1;
  }

  // We need to rebounce, so simulate a state change
	if (rebounce_millis && (millis() - previous_millis >= rebounce_millis)) 
  {
    previous_millis = millis();
    rebounce(0);
    return stateChanged = 1;
	}

	return stateChanged = 0;
}

unsigned long Bounce::duration()
{
  return millis() - previous_millis;
}

int Bounce::read()
{
	return (int)state;
}

// Protected: debounces the pin
int Bounce::debounce() 
{
	uint8_t newState = digitalRead(pin);
	if (state != newState) 
  {
    if (millis() - previous_millis >= interval_millis) 
    {
      previous_millis = millis();
      state = newState;
      return 1;
    }
  }
  
  return 0;
}

// The risingEdge method is true for one scan after the de-bounced input goes from off-to-on.
bool Bounce::risingEdge() { return stateChanged && state; }

// The fallingEdge  method it true for one scan after the de-bounced input goes from on-to-off. 
bool Bounce::fallingEdge() { return stateChanged && !state; }
