# Weather Node
## Components used :

| Name | Features | Note | 
| :--- | :--- | :--- |
|18650 | 3.7v 2200mah battery | -
|TP4056 | type-c with protection | BMS for single cell 
|ESP32 C3 Mini* | Compact, lightweight | **(ESP8266 is being **used for testing** until it arrives)
|BME280* | All in one(tem humidity, pressure) | **(DHT11 is being used until it also arrives)
|RTC (DS3231) | Accurate, no time drift(temp controlled crystal),used for deep sleep | ALWAYS STORE TIME IN INDIAN FORMAT AND TIME
|16x2 LCD | Robust, easy to debug | **(Being used to test until **OLED 0.96** inch arrives)

## Goals:	
- Should have minimum one **month** battery life 
- Should utilize **Temperature, Humidity and Pressure** for **accurate weather prediction**
- Utilize RTC for **deep sleep**(**25ua to 50ua** current draw, ) and time keeping 
- Utilize **flash button** for input
- All **weather prediction** must be done **in the cloud**. Try **traditional** methods first and then **ML**
- **Local web dashboard** on the network it is connected to or if none in its **own hotspot**
- Local dashboard shall **not** contain any **external libs** of which requires internet(if necessary **add the lib to local fs** in esp) 

## Current Workstate 
- **ESP8266 implementation** - _Done_
- **Cloud setup** - _Done_ 
- **Cloud prediction** - _Done_ (in different folder)
- **Stable Migration** to ESP32-C3 - _Done_
- **Finishing Touch** to the interface - _Ongoing_
- **Documentation and cleaning** of code, meanwhile **explanation** of project in a document file - _Ongoing_
- **Write** the explanation physically in a **tri-fold chart** and make it pretty - _Awaiting_
- Optionals - _Awaiting_
- Prep for **explaining** to people in **simple terms** - _Awaiting_


## Optionals
_Only after the above features are implemented_
- Act a relay of internet if connected to internet available network 
- SD card module which has normal SPI modified to use two wires only for logging debug info and weather info
