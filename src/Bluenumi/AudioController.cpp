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

AudioController::AudioController()
{
}

void AudioController::singleBeep()
{
  playNote(NOTE_D6, DUR_ET);
}

void AudioController::doubleBeep()
{
}

void AudioController::playMelody(Melody *melody)
{

}

/*void AudioController::playMelodyBackwards(Melody *melody)
{
  //for (int i = 0; i < melody->notes
}*/

inline void AudioController::playNote(uint16_t note, uint16_t duration)
{
  tone(PIEZO_PIN, note);
  delay(duration);
  noTone(PIEZO_PIN);
}

AudioController Audio = AudioController();
