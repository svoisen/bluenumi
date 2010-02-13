#ifndef DS1307RTC_h
#define DS1307RTC_h

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
    void setDateTime( uint8_t, uint8_t, uint8_t, uint8_t, uint8_t, uint8_t, uint8_t, bool, bool, bool, uint8_t );
    void getDateTime( uint8_t*, uint8_t*, uint8_t*, uint8_t*, uint8_t*, uint8_t*, uint8_t*, bool*, bool* );
    bool isRunning();
    
  private:
    uint8_t decToBcd( uint8_t );
    uint8_t bcdToDec( uint8_t );
};

extern DS1307 DS1307RTC;

#endif
