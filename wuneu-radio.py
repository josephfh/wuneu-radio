#!/usr/bin/env python3
import datetime, gpiod, random, re, secrets, sys, time, threading, os

debug_mode=False

ambient_track_index=None
ambient_tracks=None
button_press_cooloff=False
current_stream_pos_timestamp=datetime.datetime.utcnow()
current_stream_pos="0"
current_stream='mplayer_stream_a'
gpio_ccw_offset=5
gpio_light_switch_offset=16
gpio_offsets=[5, 6, 13, 16]
gpio_swith_offset=13
last_change_timestamp=datetime.datetime.utcnow()
lights_on=True
minimum_change_time=2.5
minimum_rotate_count_for_seeking=5
minimum_seek_time=2.5
mplayer_verbosity='-quiet'
now_playing_log = '/tmp/wuneu-radio-now-playing.txt'
rotate_count=0
seek_start_timestamp=datetime.datetime.utcnow()
seeking_allowed=True
seeking=False
song_count=0
sounds='mplayer_sounds'
startup_audio_duration=17
startup_audio_file="/home/pi/wuneu-radio/sounds/wuneu-radio-intro.m4a"
static_file="/home/pi/wuneu-radio/sounds/static.m4a" # 1 hour of FM static audio
static_volume_mod="-3"

def allow_seeking():
    global seeking_allowed
    seeking_allowed=True

def ambient_playlist():
    global ambient_track_index
    global ambient_tracks
    if not ambient_tracks:
        ambient_tracks=os.listdir('/home/pi/ambient-tracks/')
        random.shuffle(ambient_tracks)
    if ambient_tracks and len(ambient_tracks) > 0:
        if ambient_track_index == None:
            ambient_track_index=secrets.randbelow(len(ambient_tracks) + 1)
        ambient_track_index=ambient_track_index + 1
        if ambient_track_index > len(ambient_tracks)-1:
            ambient_track_index=0
        with open('/tmp/ambient.m3u','w') as out:
            track='/home/pi/ambient-tracks/' + ambient_tracks[ambient_track_index]
            out.write((track + "\n")*160)

def ambient_sounds():
    if ambient_tracks :
        os.system('echo "loadlist /tmp/ambient.m3u" > /tmp/' + sounds)
        silence(current_stream)
        silence(upcoming_stream())
        restore_volume(sounds)
        os.system('echo "" > ' + now_playing_log)

def button_press_cooloff_stop():
    global button_press_cooloff
    button_press_cooloff=False

def get_mplayer_file_playing(stream):
    for line in reversed(list(open('/tmp/' + stream + '.log'))):
        if 'Playing ' in line.rstrip():
            words=re.split(" ", line.rstrip())
            if (words[1]):
                return words[1].strip(".")
    return None

def get_mplayer_position(stream):
    for line in reversed(list(open('/tmp/' + stream + '.log'))):
        if  'Position: ' in line.rstrip():
            percent=re.sub("[^0-9]", "", line.rstrip())
            if (int(percent)):
                return int(percent)
    return None

def get_mplayer_response(command, response_identifier, stream):
    os.system('echo "' + command + '" > /tmp/' + stream)
    time.sleep(.5)
    for line in reversed(list(open('/tmp/' + stream + '.log'))):
        if response_identifier in line.rstrip():
            if (line.rstrip().partition('=')[2]):
                return line.rstrip().partition('=')[2]
    return None

def get_switch_position(offset):
    with gpiod.Chip('gpiochip0') as chip:
        lines=chip.get_lines([offset])
        lines.request(consumer=sys.argv[0], type=gpiod.LINE_REQ_DIR_IN)
        vals = lines.get_values()
        if vals[0]:
            return vals[0]
        return None

def handle_user_event(event):
    global button_press_cooloff
    global last_change_timestamp
    global lights_on
    global rotate_count
    global seek_start_timestamp
    global seeking
    if (lights_on == True) and (event.source.offset() == gpio_light_switch_offset) and (event.type == gpiod.LineEvent.RISING_EDGE):
        lights_on=False
        ambient_sounds()
    elif (lights_on == False) and (event.source.offset() == gpio_light_switch_offset) and (event.type == gpiod.LineEvent.FALLING_EDGE):
        lights_on=True
        static_load()
        restore_volume(current_stream)
        log_current_playing()
        ambient_playlist()
    elif (lights_on == True) and (event.source.offset() == gpio_ccw_offset) and (event.type == gpiod.LineEvent.RISING_EDGE):
        rotate_count=rotate_count+1
        if (seeking_allowed == True):
            if (seeking == False) and (rotate_count > 1):
                seeking=True
                restore_volume_partially(sounds)
                seek_start_timestamp=datetime.datetime.utcnow()
                quiet(current_stream)
                threading.Timer(.5, silence, [current_stream]).start()
            elif (rotate_count > minimum_rotate_count_for_seeking) and \
                last_change_timestamp < datetime.datetime.utcnow() + datetime.timedelta(seconds=-minimum_change_time) and \
                    seek_start_timestamp < datetime.datetime.utcnow() + datetime.timedelta(seconds=-minimum_seek_time):
                chance=secrets.randbelow(3)
                if (chance < 2) :
                    seeking=False
                    prevent_seeking()
                    silence(current_stream)
                    toggle_streams()
                    silence(sounds)
                    threading.Timer(2, reset_rotate_count).start()
                    threading.Timer(2, allow_seeking).start()
                    last_change_timestamp=datetime.datetime.utcnow()
        else:
            rotate_count=0
    elif (lights_on == True) and (event.source.offset() == gpio_swith_offset):
        press_switch()
    elif (lights_on == False) and (button_press_cooloff == False) and (event.source.offset() == gpio_swith_offset):
        button_press_cooloff=True
        silence(sounds)
        ambient_playlist()
        ambient_sounds()
        threading.Timer(1, button_press_cooloff_stop).start()

def upcoming_stream():
    global current_stream
    if current_stream == 'mplayer_stream_b':
        return 'mplayer_stream_a'
    else:
        return 'mplayer_stream_b'

def init_stream(stream, target, random_pos=False, silent=False):
    os.system("mplayer -vo null -ao alsa " + target + " -slave -idle -input file=/tmp/" + \
        stream + " " + mplayer_verbosity + "  > /tmp/" + stream + ".log &")
    if (silent == True):
        time.sleep(.5)
        os.system('echo "af_switch volume=-99" > /tmp/' + stream)
    if (random_pos == True):
        time.sleep(.5)
        skip_to_random_track_position(stream)
    print(stream + ' initialised with ' + target)

def log_current_playing():
    current_playing=get_mplayer_file_playing(current_stream)
    if (current_playing):
        with open(now_playing_log,'w') as out:
            out.write(current_playing)

def mute(stream):
    if (debug_mode == True):
        print('muting ' + stream)
    os.system('echo "mute 1" > /tmp/' +  stream)

def press_switch():
    print('Tracking knob pressed')

def prevent_seeking():
    global seeking_allowed
    seeking_allowed=False

def quiet(stream):
    os.system('echo "af_switch volume=-5" > /tmp/' +  stream)

def quiet_all():
    os.system('echo "af_switch volume=-15" > /tmp/mplayer_stream_a')
    os.system('echo "af_switch volume=-15" > /tmp/mplayer_stream_b')

def random_playlist(stream, prepend_silence=False):
    if song_count == 0 :
        return '/home/pi/wuneu-radio/example-playlists/0.m3u'
    else:
        list='/home/pi/playlists/' + str(secrets.randbelow(song_count)) + '.m3u'
        if ( prepend_silence == True ):
            list_with_silence_padding='/tmp/' + stream + '.m3u'
            with open(list_with_silence_padding,'w') as out:
                out.write("/home/pi/wuneu-radio/sounds/silence.wav")
            os.system('cat ' +  list + ' >> ' + list_with_silence_padding)
            return list_with_silence_padding
        else:
            return list

def reset_rotate_count():
    global rotate_count
    rotate_count=0

def restore_volume(stream):
    os.system('echo "af_switch volume=0" > /tmp/' + stream)

def restore_volume_partially(stream):
    os.system('echo "af_switch volume=' + static_volume_mod + '" > /tmp/' + stream)

def run_every_2_minutes():
    threading.Timer(120.0, run_every_2_minutes).start()
    if (debug_mode == True):
        print('running: run_every_2_minutes')
    skip_to_random_track_position(upcoming_stream())

def run_every_28_minutes():
    threading.Timer(1680.0, run_every_28_minutes).start()
    if (debug_mode == True):
        print('running: run_every_28_minutes')
    sounds_playing=get_mplayer_file_playing(sounds)
    if (sounds_playing):
        if (sounds_playing == static_file):
            skip_to_start_of_track(sounds)

def run_every_58_minutes():
    threading.Timer(3480.0, run_every_58_minutes).start()
    if (debug_mode == True):
        print('running: run_every_58_minutes')
    os.system('echo "$(tail -30 /tmp/mplayer_stream_a.log)" > /tmp/mplayer_stream_a.log')
    os.system('echo "$(tail -30 /tmp/mplayer_stream_b.log)" > /tmp/mplayer_stream_b.log')
    os.system('echo "$(tail -30 /tmp/mplayer_sounds.log)" > /tmp/mplayer_sounds.log')

def run_every_2_seconds():
    threading.Timer(2.0, run_every_2_seconds).start()
    silence(upcoming_stream())
    if (lights_on == True):
        if (seeking == False):
            silence(sounds)
    else:
        silence(current_stream)
        silence(upcoming_stream())

def run_every_30_seconds():
    global current_stream_pos
    global current_stream_pos_timestamp
    threading.Timer(30.0, run_every_30_seconds).start()
    pos = get_mplayer_position(current_stream)
    if (pos):
        current_stream_pos=pos
        current_stream_pos_timestamp=datetime.datetime.utcnow()
        if (lights_on == False) and ( pos > 90 ):
            if (debug_mode == True):
                print('Current stream to close to the end. Returning to random position.')
            skip_to_random_track_position(current_stream)
    if (current_stream_pos_timestamp < datetime.datetime.utcnow() + datetime.timedelta(seconds=-120)):
        print('Error: active stream time postion has not been updated in 2 minutes. Restarting.')
        quit()

def run_every_day():
    threading.Timer(86400.0, run_every_day).start()
    if (lights_on == True):
        static_load()

def startup():
    global lights_on
    global song_count

    os.system('/usr/bin/aplay /home/pi/wuneu-radio/sounds/wuneu-radio-intro-single-note.wav')
    time.sleep(1)

    startup_playlist()

    try:
        with open('/home/pi/playlists/song-count.txt', 'r') as file:
            song_count=int(file.read().replace('\n', ''))
    except IOError:
        print("song-count.txt not accessible. Please see README.md for how to upload music and generate playlists.")
        song_count=0

    system_uptime=float(os.popen('cat /proc/uptime | cut -d" " -f2').readline().rstrip())

    # Clean up from previous runs
    os.system('killall mplayer 2> /dev/null')
    os.system('rm /tmp/mplayer_sounds 2> /dev/null')
    os.system('rm /tmp/mplayer_stream_a 2> /dev/null')
    os.system('rm /tmp/mplayer_stream_b 2> /dev/null')
    os.system('rm /tmp/mplayer_sounds.log 2> /dev/null')
    os.system('rm /tmp/mplayer_stream_a.log 2> /dev/null')
    os.system('rm /tmp/mplayer_stream_b.log 2> /dev/null')
    os.system('mkfifo /tmp/mplayer_sounds')
    os.system('mkfifo /tmp/mplayer_stream_a')
    os.system('mkfifo /tmp/mplayer_stream_b')

    # Initiate mplayer slave processes
    target="-playlist /tmp/startup.m3u"
    init_stream(sounds, target)

    target="-playlist " + random_playlist('mplayer_stream_a')
    threading.Timer(2, init_stream, ['mplayer_stream_a', target, True, True]).start()

    target="-playlist " + random_playlist('mplayer_stream_b')
    threading.Timer(4, init_stream, ['mplayer_stream_b', target, True, True]).start()


    static_playlist()
    # Startup audio while playlist processes settle
    while True:
        file='/tmp/mplayer_sounds.log'
        if os.path.isfile(file):
            with open(file) as log_file:
                if 'Starting playback...' in log_file.read():
                    break
        time.sleep(1)
    if (debug_mode == False) or (system_uptime < 150):
        time.sleep(startup_audio_duration + 1.5)
    else:
        print('Skipping startup audio.')

    while True:
        file='/tmp/mplayer_stream_a.log'
        if os.path.isfile(file):
            with open(file) as log_file:
                if 'Playing ' in log_file.read():
                    break
        time.sleep(1)
    toggle_streams()
    static_load()
    ambient_playlist()
    for _ in range(0, 4):
        time.sleep(.1)
        lights=get_switch_position(gpio_light_switch_offset)
        if lights:
            if lights == 1:
                print('Lights are off')
                lights_on=False
                ambient_sounds()
            else:
                print('Lights are on')
            break

def startup_playlist():
    with open('/tmp/startup.m3u','w') as out:
        out.write(startup_audio_file + "\n")
        out.write(static_file + "\n")

def static_load():
    os.system('echo "loadlist /tmp/static.m3u" > /tmp/' + sounds)

def static_playlist():
    with open('/tmp/static.m3u','w') as out:
        out.write((static_file + "\n")*25)

def set_current_stream(stream):
    if (debug_mode == True):
        print('setting current stream to ' + stream)
    global current_stream
    current_stream=stream

def silence(stream):
    os.system('echo "af_switch volume=-99" > /tmp/' +  stream)

def skip_to_start_of_track(stream):
    if (debug_mode == True):
        print('skipping to start of track for ' + stream)
    os.system("echo 'seek 0 1' > /tmp/" + stream)

def skip_to_random_track_position(stream):
    if (debug_mode == True):
        print('skipping track pos for ' + stream)
    flip=secrets.randbelow(5)
    if (flip == 0):
        track_pos=secrets.randbelow(5)
    elif (flip == 1) or (flip == 2):
        track_pos=secrets.randbelow(54)
    else:
        track_pos=secrets.randbelow(89)
    os.system("echo 'seek " + str(track_pos) + " 1' > /tmp/" + stream)

def toggle_streams():
    set_current_stream(upcoming_stream())
    if (debug_mode == True):
        print('changing stream to ' + current_stream)
    silence(upcoming_stream())
    time.sleep(.3)
    restore_volume(current_stream)
    time.sleep(.3)
    os.system('echo "loadlist ' + random_playlist(upcoming_stream(), True) + '" > /tmp/' + upcoming_stream())
    # skip_to_random_track_position(upcoming_stream())
    threading.Timer(4, skip_to_random_track_position, [upcoming_stream()]).start()
    log_current_playing()

def unmute(stream):
    if (debug_mode == True):
        print('unmuting ' + stream)
    os.system('echo "mute 0" > /tmp/' +  stream)


def main():
    startup()
    run_every_2_minutes()
    run_every_2_seconds()
    run_every_30_seconds()
    run_every_58_minutes()
    run_every_28_minutes()
    run_every_day()

    with gpiod.Chip('gpiochip0') as chip:
        lines=chip.get_lines(gpio_offsets)
        lines.request(consumer=sys.argv[0], type=gpiod.LINE_REQ_EV_BOTH_EDGES)
        try:
            while True:
                ev_lines=lines.event_wait(sec=1)
                if ev_lines:
                    for line in ev_lines:
                        event=line.event_read()
                        handle_user_event(event)
        except KeyboardInterrupt:
            sys.exit(130)

if __name__=="__main__":
    main()
