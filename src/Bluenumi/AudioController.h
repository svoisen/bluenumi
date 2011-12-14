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

#ifndef AUDIOCONTROLLER_H_
#define AUDIOCONTROLLER_H_

#include <Arduino.h>
#include <inttypes.h>
#include "Melody.h"

#define PIEZO_PIN 8

class AudioController
{
  public:
    AudioController();
    void singleBeep();
    void doubleBeep();
    void playMelody(Melody*);
    void playMelodyBackwards(Melody*);

  private:
    inline void playNote(uint16_t, uint16_t);
    inline void disableDisplays();
    inline void enableDisplays();
    void outputTone(int, int);
};

extern AudioController Audio;

#endif // AUDIOCONTROLLER_H_
