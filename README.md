# Wuneu Radio

*NOTE: This is still being tested and I'm still writing the install script. Don't exepect this to work.*

## Quick start

1. Install Rasbian buster lite to a micro SD card
2. Insert this card into your Pi Zero
3. Attach an ethernet cable and USB keyboard to the Pi with your network/USB to Micro USB hub
4. Attach the Pi to a monitor or TV with a Micro HDMI to HDMI cable
5. Plug in the Pi with a Pi Micro USB power adapter
6. Wait for the Pi to boot
7. Log in with the default Raspbian details (user: pi. password: raspberry)
8. Add ```over_voltage=2``` as a new line to /boot/config.txt to underclock the Pi
    - Use nano to edit this file ```sudo nano /boot/config.txt```
9. Download the setup script
    ```curl https://raw.githubusercontent.com/josephfh/wuneu-radio/master/setup-pi.sh --output setup-pi.sh```
10. Make the setup script executable
    ```chmod +x ./setup-pi.sh```
11. Run the setup script
    ```./setup-pi.sh```

## What this is

A python script to mimic a FM radio on your Raspberry Pi Zero.

Each simulated radio station is played from a collection of long AAC / mp3 files place at _/home/pi/music/YEAR_,
where _YEAR_ is the year the audio comes from.

Included are some shell scripts to create and update the .m3u playlists

### _generate-playlists.sh_
Generates a playlist for each the audio files. Subsequent files are placed in a pseudo-random order after each track,
favouring the year and category of the audio.

This is incredibly slow on a pi zero, and I haven't got around to optimising the ordering. For that reason there's a
few more options...

### _generate-playlists-quick.sh_
Generates a playlist for each the audio files. Subsequent files are placed after with no intelligent sorting. Prepare
yourself for sudden trash hardcore angst after a calming hour of ambient space jazz.

### _generate-playlists-file.sh_
Generates a _playlists.txt_ file, listing all of your music with their years. You can clone this repo to your fastest
computer and copy the _playlists.txt_ file over, then run _generate_playlists.sh_. It's far more tolerable than
attempting it on your brave little Pi Zero.

## Hardware

I can't tell you how to do it here but this will give you a glimpse into what my final setup is:

* Pi Zero
* KY040 rotary encoder - for the tuning knob
* USB stick soundcard (5V USB Powered PCM2704)
* Low power mono amp board - (5V PAM8403)
* 5v USB power adapter (1A is probably enough)
* USB to USB micro adapter, for the soundcard

You'll need to power the PAM8403 from the same 5V power supply as your pi, and solder wires from the right OR left headphone
socket on the USB soundcard to the matching channel on the (mono) PAM8403.

The GPIO pins are declared in the top of _wuneu-radio.py_. These ARE NOT the Pi pin numbers, rather the GPIO pin numbers.
You'll have to Google it.

Be careful with the electrics, especially when wiring up the GPIO pins: don't accidently fry your Pi, or yourself.

You'll probably want to use a combined USB/ethernet micro USB hub to SSH in and set things up.

Detects a user pressing and turning a KY040 rotary encoder wired to the Pi's GPIO using libgpiod.

## Requirements

* A micro SD card large enough and all or your hours of audio
* The latest Rasbian Buster Lite installed

## 1 hour of FM static audio

If you can't record your own, you'll have to find some on the internet. For example you could
grab the audio from a YouTube video such as https://www.youtube.com/watch?v=qcDxVQLoQyk using
[youtube-dl](https://ytdl-org.github.io/youtube-dl/index.html)

```youtube-dl -f 140 https://www.youtube.com/watch?v=qcDxVQLoQyk```

... once you have ensured you are respecting copyright.

Place the file in the _sounds_ folder and rename to _static.m4a_

## Startup audio

Initiating the three mplayer processes on a Pi Zero takes exactly _one handful_ of seconds. After a the 1 minute silent wait for
Rasbian to load, pulseaudio to start etc, you can reward your patient radio listener with a startup track. I've included
one in this project that you will either find amusing or a little too creepy. You can replace it with your own, and update
the duration (in seconds) at the top of _wuneu-radio.py_

## Tips

If you're frankensteining this into an old mono radio (just the one speaker) convert your audio to mono and get more from your
SD card's storage.

I have used _ffmpeg_ and _ffmpeg-normalize_. Checkout _example-scripts/convert-music-folders.sh.example_ if you want to automate
your own transcoding.
