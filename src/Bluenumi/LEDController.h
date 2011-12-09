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

#ifndef LEDCONTROLLER_H_
#define LEDCONTROLLER_H_

#include <Arduino.h>
#include <inttypes.h>
#include <math.h>

#define SECONDS0_PIN 9 // LED under 10s hour
#define SECONDS1_PIN 10 // LED under 1s hour
#define SECONDS2_PIN 11 // LED under 10s minute
#define SECONDS3_PIN 3 // LED under 1s minute

#define CALL_MEMBER_FN(object, ptrToMember) ((object)->*(ptrToMember))

class LEDController
{
  public:
    typedef void (LEDController::*PatternHandler)();
    enum PatternType
    {
      BREATHE,
      ROLLING_BREATHE
    };

    LEDController();
    void begin();
    void update();
    void pause();
    void resume();
    void setType(enum PatternType);
    void setEnabled(bool);
    void setLEDStates(bool, bool, bool, bool);

  private:
    void mapHandlers();
    enum PatternType currentType;
    bool enabled;
    bool paused;
    PatternHandler patternHandlerMap[2];
    void breatheHandler();
    void rollingBreatheHandler();
    float calculateBreatheVal(float, float);
};

extern LEDController LEDs;

#endif // LEDCONTROLLER_H_
