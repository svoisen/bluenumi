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

#include "AudioController.h"
#include "Display.h"
#include "LEDController.h"

AudioController::AudioController()
{
}

void AudioController::singleBeep()
{
  disableDisplays();
  playNote(NOTE_BEEP, DUR_ET);
  enableDisplays();
}

void AudioController::doubleBeep()
{
  disableDisplays();
  playNote(NOTE_BEEP, DUR_ET);
  delay(DUR_ET);
  playNote(NOTE_BEEP, DUR_ET);
  enableDisplays();
}

void AudioController::playMelody(Melody *melody)
{
  disableDisplays();

  for (int i = 0; i < melody->length; i++)
  {
    playNote(melody->notes[i], melody->durations[i]);
  }

  enableDisplays();
}

void AudioController::playMelodyBackwards(Melody *melody)
{
  disableDisplays();

  for (int i = melody->length - 1; i >= 0; i--)
  {
    playNote(melody->notes[i], melody->durations[i]);
  }

  enableDisplays();
}

inline void AudioController::playNote(uint16_t note, uint16_t duration)
{
  tone(PIEZO_PIN, note);
  delay(duration);
  noTone(PIEZO_PIN);
}

inline void AudioController::disableDisplays()
{
  Display.setEnabled(false);
  LEDs.setEnabled(false);
}

inline void AudioController::enableDisplays()
{
  Display.setEnabled(true);
  LEDs.setEnabled(true);
}

AudioController Audio = AudioController();
