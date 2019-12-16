#!/bin/bash

echo
echo "Read the README.md file in the Wuneu Radio repo to understand what hardware should work."
echo
echo "This script will modify system files on this Pi Zero, and then disable all network and login features"
echo "to provide a fast boot time. You will have to copy music onto the sd card using an sd card reader on"
echo "a computer."
echo
echo "In short: this will permanently modify Raspian on this card."
echo
echo "Only use this script on a freshly made Raspbian Buster Lite card on your Pi Zero!"
echo

model=$(cat /proc/device-tree/model)
echo "This model is $model"

if [[ "$model" == "Raspberry Pi Zero W Rev"* ]] ; then
    echo
    echo "This is a Pi Zero W."
    echo "The assumption is you want to use the wifi. Networking features will not be disabled by the script so you can"
    echo "SSH in via your desired static IP."
    echo
    # echo
    # echo "Enter your wifi country code: (e.g. SE)"
    # read -p "$wificounty"
    # echo
    # echo "Enter your wifi SSID:)"
    # read -p "$wifissid"
    # echo
    # set +o history
    # echo "Enter your wifi pass:"
    # read -p "$wifipass"
    # set -o history
    # echo
    echo "Enter the desired static IP address: (e.g. 192.168.1.248)"
    read ip
    echo
    echo "Enter the network gateway: (e.g. 192.168.1.1)"
    read gateway
    echo
elif [[ "$model" != "Raspberry Pi Zero Rev"* ]] ; then
    echo "You are not running this script on a Pi Zero. Exiting."
    exit 2
fi

echo
echo "Type OK to continue:"

read confirmation </dev/tty
if [[ $confirmation != "ok" ]] && [[ $confirmation != "OK" ]] ; then
    echo "You did not type OK. Exiting script."
    exit 2
fi

echo "Starting script."


if [[ "$model" == "Raspberry Pi Zero W Rev"* ]] ; then

#     sudo bash -c "cat > /etc/wpa_supplicant/wpa_supplicant.conf" << EOT
# country=$wificountry
# update_config=1
# ctrl_interface=/var/run/wpa_supplicant

# network={
#   scan_ssid=1
#   ssid="$wifissid"
#   psk="$wifipass"
# }
# EOT

#####

    sudo bash -c "cat > /etc/dhcpcd.conf" << EOT
# A sample configuration for dhcpcd.
# See dhcpcd.conf(5) for details.

# Allow users of this group to interact with dhcpcd via the control socket.
#controlgroup wheel

# Inform the DHCP server of our hostname for DDNS.
hostname

# Use the hardware address of the interface for the Client ID.
clientid
# or
# Use the same DUID + IAID as set in DHCPv6 for DHCPv4 ClientID as per RFC4361.
# Some non-RFC compliant DHCP servers do not reply with this set.
# In this case, comment out duid and enable clientid above.
#duid

# Persist interface configuration when dhcpcd exits.
persistent

# Rapid commit support.
# Safe to enable by default because it requires the equivalent option set
# on the server to actually work.
option rapid_commit

# A list of options to request from the DHCP server.
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
# Respect the network MTU. This is applied to DHCP routes.
option interface_mtu

# Most distributions have NTP support.
#option ntp_servers

# A ServerID is required by RFC2131.
require dhcp_server_identifier

# Generate SLAAC address using the Hardware Address of the interface
#slaac hwaddr
# OR generate Stable Private IPv6 Addresses based from the DUID
slaac private

interface wlan0
EOT
    sudo echo "static ip_address=$ip" >> /etc/dhcpcd.conf
    sudo echo "static routers=$gateway" >> /etc/dhcpcd.conf
    sudo echo "static domain_name_servers=$gateway" >> /etc/dhcpcd.conf

    sudo systemctl enable ssh
    sudo systemctl daemon-reload
    sudo systemctl restart dhcpcd
    sudo wpa_cli -i wlan0 reconfigure
    sudo systemctl restart networking
fi

while :
do
    ping -c4 google.com > /dev/null
    if [ $? != 0 ] ; then
        echo "Cannot reach the internet. Retrying in 5 seconds."
    else
        break
    fi
    sleep 5
done

#####

# Specify a Swedish mirror as the default seems to not resolve

sudo bash -c "cat > /etc/apt/sources.list" << EOT
deb http://ftp.acc.umu.se/mirror/raspbian/raspbian/ buster main contrib non-free rpi
EOT

#####

sudo apt-get update
sudo apt-get upgrade -y
sudo apt autoremove -y
sudo apt install -y \
    autoconf \
    autoconf-archive \
    automake \
    build-essential \
    ffmpeg \
    git \
    libtool \
    mplayer \
    pkg-config \
    pulseaudio \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    raspberrypi-kernel-headers \
    swig3.0 \
    vim \
    wget

#####

echo "Installing youtube-dl"
sudo curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl
sudo chmod a+rx /usr/local/bin/youtube-dl

#####

git clone https://github.com/josephfh/wuneu-radio.git /home/pi/wuneu-radio

cp -r /home/pi/wuneu-radio/example-music /home/pi/music

/home/pi/wuneu-radio/generate-playlists-basic.sh

#####

echo
echo "Downloading some example FM static noise from https://www.youtube.com/watch?v=qcDxVQLoQyk"
echo "Please make sure you respect the copyright of this video if you do not replace it with"
echo "your own static sound."

youtube-dl -f 140 https://www.youtube.com/watch?v=qcDxVQLoQyk -o /home/pi/wuneu-radio/sounds/static.m4a


mkdir -p /home/pi/ambient-tracks

echo
echo "Downloading some example ambient noise from https://www.youtube.com/watch?v=t6_LYn4_JA4"
echo "Please make sure you respect the copyright of this video if you do not replace it with"
echo "your own ambient tracks."

youtube-dl -f 140 https://www.youtube.com/watch?v=t6_LYn4_JA4 -o /home/pi/ambient-tracks/bird-song.m4a

echo
echo "Downloading some example ambient noise from https://www.youtube.com/watch?v=bhWJF9FlBqM"
echo "Please make sure you respect the copyright of this video if you do not replace it with"
echo "your own ambient tracks."

youtube-dl -f 140 https://www.youtube.com/watch?v=bhWJF9FlBqM -o /home/pi/ambient-tracks/forest-rain.m4a

echo
echo "Downloading some example ambient noise from https://www.youtube.com/watch?v=ElU8g7xi6ws"
echo "Please make sure you respect the copyright of this video if you do not replace it with"
echo "your own ambient tracks."

youtube-dl -f 140 https://www.youtube.com/watch?v=ElU8g7xi6ws -o /home/pi/ambient-tracks/city-noise.m4a

#####

build_dir=`mktemp -d /tmp/libgpiod.XXXX`
echo "Cloning libgpiod repository to $build_dir"
echo

while true; do
   if ! git clone git://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git /home/pi/libgpiod-build
   then
      echo "Failed to clone gpiod repo. Reattempting in 5 seconds."
      sleep 5
   else
      echo "Successful clone of repo"
      break
   fi
done

cd /home/pi/libgpiod-build

# Revert the build due to a bug preventing build circa 12 Dev 2019

git reset --hard 07507f3a177129fa36935223914c3a4398faa26e

echo "Building libgpiod"
echo

chmod +x /home/pi/libgpiod-build/autogen.sh

include_path=`python3 -c "from sysconfig import get_paths; print(get_paths()['include'])"`

export PYTHON_VERSION=3
./autogen.sh --enable-tools=yes --prefix=/usr/local/ --enable-bindings-python CFLAGS="-I/$include_path" \
   && make \
   && sudo make install \
   && sudo ldconfig

# This is not the right way to do this:
sudo cp bindings/python/.libs/gpiod.so /usr/local/lib/python3.?/dist-packages/
sudo cp bindings/python/.libs/gpiod.la /usr/local/lib/python3.?/dist-packages/
sudo cp bindings/python/.libs/gpiod.a /usr/local/lib/python3.?/dist-packages/

#####

mkdir -p /home/pi/.mplayer

echo "lirc=no" >> /home/pi/.mplayer/config

sudo timedatectl set-timezone Europe/Stockholm

sudo locale-gen en_GB.UTF-8

####

sudo bash -c "cat > /etc/default/locale" << EOT
LC_CTYPE="en_GB.UTF-8"
LC_ALL="en_GB.UTF-8"
LANG="en_GB.UTF-8"
EOT

#####

sudo bash -c "cat >> /etc/pulse/default.pa" << EOT
set-default-sink alsa_output.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_DAC-00.analog-stereo
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1
EOT

#####

sudo bash -c "cat > /etc/systemd/system/pulseaudio.service" << EOT
[Unit]
Description=PulseAudio system server

[Service]
Type=forking
ExecStart=/usr/bin/pulseaudio --daemonize --system --realtime --log-target=journal
ExecStop=/usr/bin/pulseaudio -k
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT

#####

sudo bash -c "cat > /etc/systemd/system/boot-sound.service" << EOT
[Unit]
Description=Boot Sound
Requires=pulseaudio.service sys-devices-platform-soc-20980000.usb-usb1-1\x2d1-1\x2d1:1.0-sound-card1.device
After=pulseaudio.service sys-devices-platform-soc-20980000.usb-usb1-1\x2d1-1\x2d1:1.0-sound-card1.device

[Service]
ExecStart=/usr/bin/aplay /home/pi/wuneu-radio/sounds/wuneu-radio-intro-single-note.wav &
WorkingDirectory=/home/pi/wuneu-radio
User=pi

[Install]
WantedBy=multi-user.target
EOT

#####

sudo bash -c "cat > /etc/systemd/system/wuneu-radio.service" << EOT
[Unit]
Description=Wuneu Radio
Requires=pulseaudio.service sys-devices-platform-soc-20980000.usb-usb1-1\x2d1-1\x2d1:1.0-sound-card1.device
After=pulseaudio.service sys-devices-platform-soc-20980000.usb-usb1-1\x2d1-1\x2d1:1.0-sound-card1.device

[Service]
ExecStart=/usr/bin/python3 /home/pi/wuneu-radio/wuneu-radio.py
WorkingDirectory=/home/pi/wuneu-radio
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOT

#####

sudo bash -c "cat > /etc/systemd/system/wuneu-radio-autostart.service" << EOT
[Unit]
Description=autostart
After=local-fs.target

[Service]
ExecStart=/home/pi/autostart.sh

[Install]
WantedBy=multi-user.target
EOT

#####

cat <<EOF > /home/pi/autostart.sh
#!/bin/bash
sudo chmod 777 /tmp
EOF

#####

chmod +x /home/pi/autostart.sh

sudo systemctl --system enable pulseaudio.service
sudo systemctl --system start pulseaudio.service

sudo systemctl enable wuneu-radio-autostart.service
sudo systemctl start wuneu-radio-autostart.service

sudo systemctl enable boot-sound.service
sudo systemctl start boot-sound.service

sudo systemctl enable wuneu-radio.service
sudo systemctl start wuneu-radio.service

#####

sudo bash -c "cat > /etc/asound.conf" << EOT
pcm.pulse {
    type pulse
}
ctl.pulse {
    type pulse
}
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
EOT

#####

sudo adduser root audio
sudo adduser root pulse-access
sudo adduser pi pulse-access

#####

sudo bash -c "cat > /usr/share/alsa/alsa.conf" << EOT
#
#  ALSA library configuration file
#

# pre-load the configuration files

@hooks [
    {
        func load
        files [
            "/etc/alsa/conf.d"
            "/etc/asound.conf"
            "~/.asoundrc"
        ]
        errors false
    }
]

# load card-specific configuration files (on request)

cards.@hooks [
    {
        func load
        files [
            {
                @func concat
                strings [
                    { @func datadir }
                    "/cards/aliases.conf"
                ]
            }
        ]
    }
    {
        func load_for_all_cards
        files [
            {
                @func concat
                strings [
                    { @func datadir }
                    "/cards/"
                    { @func private_string }
                    ".conf"
                ]
            }
        ]
        errors false
    }
]

#
# defaults
#

# show all name hints also for definitions without hint {} section
defaults.namehint.showall on
# show just basic name hints
defaults.namehint.basic on
# show extended name hints
defaults.namehint.extended on
#
defaults.ctl.card 1
defaults.pcm.card 1
defaults.pcm.device 0
defaults.pcm.subdevice -1
defaults.pcm.nonblock 1
defaults.pcm.compat 0
defaults.pcm.minperiodtime 5000        # in us
defaults.pcm.ipc_key 5678293
defaults.pcm.ipc_gid audio
defaults.pcm.ipc_perm 0660
defaults.pcm.dmix.max_periods 0
defaults.pcm.dmix.rate 48000
defaults.pcm.dmix.format "unchanged"
defaults.pcm.dmix.card defaults.pcm.card
defaults.pcm.dmix.device defaults.pcm.device
defaults.pcm.dsnoop.card defaults.pcm.card
defaults.pcm.dsnoop.device defaults.pcm.device
defaults.pcm.front.card defaults.pcm.card
defaults.pcm.front.device defaults.pcm.device
defaults.pcm.rear.card defaults.pcm.card
defaults.pcm.rear.device defaults.pcm.device
defaults.pcm.center_lfe.card defaults.pcm.card
defaults.pcm.center_lfe.device defaults.pcm.device
defaults.pcm.side.card defaults.pcm.card
defaults.pcm.side.device defaults.pcm.device
defaults.pcm.surround21.card defaults.pcm.card
defaults.pcm.surround21.device defaults.pcm.device
defaults.pcm.surround40.card defaults.pcm.card
defaults.pcm.surround40.device defaults.pcm.device
defaults.pcm.surround41.card defaults.pcm.card
defaults.pcm.surround41.device defaults.pcm.device
defaults.pcm.surround50.card defaults.pcm.card
defaults.pcm.surround50.device defaults.pcm.device
defaults.pcm.surround51.card defaults.pcm.card
defaults.pcm.surround51.device defaults.pcm.device
defaults.pcm.surround71.card defaults.pcm.card
defaults.pcm.surround71.device defaults.pcm.device
defaults.pcm.iec958.card defaults.pcm.card
defaults.pcm.iec958.device defaults.pcm.device
defaults.pcm.modem.card defaults.pcm.card
defaults.pcm.modem.device defaults.pcm.device
# truncate files via file or tee PCM
defaults.pcm.file_format    "raw"
defaults.pcm.file_truncate    true
defaults.rawmidi.card 0
defaults.rawmidi.device 0
defaults.rawmidi.subdevice -1
defaults.hwdep.card 0
defaults.hwdep.device 0
defaults.timer.class 2
defaults.timer.sclass 0
defaults.timer.card 0
defaults.timer.device 0
defaults.timer.subdevice 0

#
#  PCM interface
#

# redirect to load-on-demand extended pcm definitions
pcm.cards cards.pcm

pcm.default cards.pcm.default
pcm.sysdefault cards.pcm.default
pcm.front cards.pcm.front
pcm.rear cards.pcm.rear
pcm.center_lfe cards.pcm.center_lfe
pcm.side cards.pcm.side
pcm.surround21 cards.pcm.surround21
pcm.surround40 cards.pcm.surround40
pcm.surround41 cards.pcm.surround41
pcm.surround50 cards.pcm.surround50
pcm.surround51 cards.pcm.surround51
pcm.surround71 cards.pcm.surround71
pcm.iec958 cards.pcm.iec958
pcm.spdif iec958
pcm.hdmi cards.pcm.hdmi
pcm.dmix cards.pcm.dmix
pcm.dsnoop cards.pcm.dsnoop
pcm.modem cards.pcm.modem
pcm.phoneline cards.pcm.phoneline

pcm.hw {
    @args [ CARD DEV SUBDEV ]
    @args.CARD {
        type string
        default {
            @func getenv
            vars [
                ALSA_PCM_CARD
                ALSA_CARD
            ]
            default {
                @func refer
                name defaults.pcm.card
            }
        }
    }
    @args.DEV {
        type integer
        default {
            @func igetenv
            vars [
                ALSA_PCM_DEVICE
            ]
            default {
                @func refer
                name defaults.pcm.device
            }
        }
    }
    @args.SUBDEV {
        type integer
        default {
            @func refer
            name defaults.pcm.subdevice
        }
    }
    type hw
    card \$CARD
    device \$DEV
    subdevice \$SUBDEV
    hint {
        show {
            @func refer
            name defaults.namehint.extended
        }
        description "Direct hardware device without any conversions"
    }
}

pcm.plughw {
    @args [ CARD DEV SUBDEV ]
    @args.CARD {
        type string
        default {
            @func getenv
            vars [
                ALSA_PCM_CARD
                ALSA_CARD
            ]
            default {
                @func refer
                name defaults.pcm.card
            }
        }
    }
    @args.DEV {
        type integer
        default {
            @func igetenv
            vars [
                ALSA_PCM_DEVICE
            ]
            default {
                @func refer
                name defaults.pcm.device
            }
        }
    }
    @args.SUBDEV {
        type integer
        default {
            @func refer
            name defaults.pcm.subdevice
        }
    }
    type plug
    slave.pcm {
        type hw
        card \$CARD
        device \$DEV
        subdevice \$SUBDEV
    }
    hint {
        show {
            @func refer
            name defaults.namehint.extended
        }
        description "Hardware device with all software conversions"
    }
}

pcm.plug {
    @args [ SLAVE ]
    @args.SLAVE {
        type string
    }
    type plug
    slave.pcm \$SLAVE
}

pcm.shm {
    @args [ SOCKET PCM ]
    @args.SOCKET {
        type string
    }
    @args.PCM {
        type string
    }
    type shm
    server \$SOCKET
    pcm \$PCM
}

pcm.tee {
    @args [ SLAVE FILE FORMAT ]
    @args.SLAVE {
        type string
    }
    @args.FILE {
        type string
    }
    @args.FORMAT {
        type string
        default {
            @func refer
            name defaults.pcm.file_format
        }
    }
    type file
    slave.pcm \$SLAVE
    file \$FILE
    format \$FORMAT
    truncate {
        @func refer
        name defaults.pcm.file_truncate
    }
}

pcm.file {
    @args [ FILE FORMAT ]
    @args.FILE {
        type string
    }
    @args.FORMAT {
        type string
        default {
            @func refer
            name defaults.pcm.file_format
        }
    }
    type file
    slave.pcm null
    file \$FILE
    format \$FORMAT
    truncate {
        @func refer
        name defaults.pcm.file_truncate
    }
}

pcm.null {
    type null
    hint {
        show {
            @func refer
            name defaults.namehint.basic
        }
        description "Discard all samples (playback) or generate zero samples (capture)"
    }
}

#
#  Control interface
#

ctl.sysdefault {
    type hw
    card {
        @func getenv
        vars [
            ALSA_CTL_CARD
            ALSA_CARD
        ]
        default {
            @func refer
            name defaults.ctl.card
        }
    }
    hint.description "Default control device"
}
ctl.default ctl.sysdefault

ctl.hw {
    @args [ CARD ]
    @args.CARD {
        type string
        default {
            @func getenv
            vars [
                ALSA_CTL_CARD
                ALSA_CARD
            ]
            default {
                @func refer
                name defaults.ctl.card
            }
        }
    }
    type hw
    card \$CARD
    hint.description "Direct control device"
}

ctl.shm {
    @args [ SOCKET CTL ]
    @args.SOCKET {
        type string
    }
    @args.CTL {
        type string
    }
    type shm
    server \$SOCKET
    ctl \$CTL
}

#
#  RawMidi interface
#

rawmidi.default {
    type hw
    card {
        @func getenv
        vars [
            ALSA_RAWMIDI_CARD
            ALSA_CARD
        ]
        default {
            @func refer
            name defaults.rawmidi.card
        }
    }
    device {
        @func igetenv
        vars [
            ALSA_RAWMIDI_DEVICE
        ]
        default {
            @func refer
            name defaults.rawmidi.device
        }
    }
    hint.description "Default raw MIDI device"
}

rawmidi.hw {
    @args [ CARD DEV SUBDEV ]
    @args.CARD {
        type string
        default {
            @func getenv
            vars [
                ALSA_RAWMIDI_CARD
                ALSA_CARD
            ]
            default {
                @func refer
                name defaults.rawmidi.card
            }
        }
    }
    @args.DEV {
        type integer
        default {
            @func igetenv
            vars [
                ALSA_RAWMIDI_DEVICE
            ]
            default {
                @func refer
                name defaults.rawmidi.device
            }
        }
    }
    @args.SUBDEV {
        type integer
        default -1
    }
    type hw
    card \$CARD
    device \$DEV
    subdevice \$SUBDEV
    hint {
        description "Direct rawmidi driver device"
        device \$DEV
    }
}

rawmidi.virtual {
    @args [ MERGE ]
    @args.MERGE {
        type string
        default 1
    }
    type virtual
    merge \$MERGE
}

#
#  Sequencer interface
#

seq.default {
    type hw
    hint.description "Default sequencer device"
}

seq.hw {
    type hw
}

#
#  HwDep interface
#

hwdep.default {
    type hw
    card {
        @func getenv
        vars [
            ALSA_HWDEP_CARD
            ALSA_CARD
        ]
        default {
            @func refer
            name defaults.hwdep.card
        }
    }
    device {
        @func igetenv
        vars [
            ALSA_HWDEP_DEVICE
        ]
        default {
            @func refer
            name defaults.hwdep.device
        }
    }
    hint.description "Default hardware dependent device"
}

hwdep.hw {
    @args [ CARD DEV ]
    @args.CARD {
        type string
        default {
            @func getenv
            vars [
                ALSA_HWDEP_CARD
                ALSA_CARD
            ]
            default {
                @func refer
                name defaults.hwdep.card
            }
        }
    }
    @args.DEV {
        type integer
        default {
            @func igetenv
            vars [
                ALSA_HWDEP_DEVICE
            ]
            default {
                @func refer
                name defaults.hwdep.device
            }
        }
    }
    type hw
    card \$CARD
    device \$DEV
    hint {
        description "Direct hardware dependent device"
        device \$DEV
    }
}

#
#  Timer interface
#

timer_query.default {
    type hw
}

timer_query.hw {
    type hw
}

timer.default {
    type hw
    class {
        @func refer
        name defaults.timer.class
    }
    sclass {
        @func refer
        name defaults.timer.sclass
    }
    card {
        @func refer
        name defaults.timer.card
    }
    device {
        @func refer
        name defaults.timer.device
    }
    subdevice {
        @func refer
        name defaults.timer.subdevice
    }
    hint.description "Default timer device"
}

timer.hw {
    @args [ CLASS SCLASS CARD DEV SUBDEV ]
    @args.CLASS {
        type integer
        default {
            @func refer
            name defaults.timer.class
        }
    }
    @args.SCLASS {
        type integer
        default {
            @func refer
            name defaults.timer.sclass
        }
    }
    @args.CARD {
        type string
        default {
            @func refer
            name defaults.timer.card
        }
    }
    @args.DEV {
        type integer
        default {
            @func refer
            name defaults.timer.device
        }
    }
    @args.SUBDEV {
        type integer
        default {
            @func refer
            name defaults.timer.subdevice
        }
    }
    type hw
    class \$CLASS
    sclass \$SCLASS
    card \$CARD
    device \$DEV
    subdevice \$SUBDEV
    hint {
        description "Direct timer device"
        device \$DEV
    }
}
EOT

#####

sudo bash -c "cat > /var/lib/alsa/asound.state" << EOT
state.ALSA {
    control.1 {
        iface MIXER
        name 'PCM Playback Volume'
        value -2000
        comment {
            access 'read write'
            type INTEGER
            count 1
            range '-10239 - 400'
            dbmin -9999999
            dbmax 400
            dbvalue.0 -2000
        }
    }
    control.2 {
        iface MIXER
        name 'PCM Playback Switch'
        value true
        comment {
            access 'read write'
            type BOOLEAN
            count 1
        }
    }
    control.3 {
        iface MIXER
        name 'PCM Playback Route'
        value 0
        comment {
            access 'read write'
            type INTEGER
            count 1
            range '0 - 3'
        }
    }
    control.4 {
        iface PCM
        name 'IEC958 Playback Default'
        value '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
        comment {
            access 'read write'
            type IEC958
            count 1
        }
    }
    control.5 {
        iface PCM
        name 'IEC958 Playback Con Mask'
        value '0200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
        comment {
            access read
            type IEC958
            count 1
        }
    }
}
state.DAC {
    control.1 {
        iface PCM
        name 'Playback Channel Map'
        value.0 0
        value.1 0
        comment {
            access read
            type INTEGER
            count 2
            range '0 - 36'
        }
    }
    control.2 {
        iface MIXER
        name 'PCM Playback Switch'
        value true
        comment {
            access 'read write'
            type BOOLEAN
            count 1
        }
    }
    control.3 {
        iface MIXER
        name 'PCM Playback Volume'
        value.0 64
        value.1 64
        comment {
            access 'read write'
            type INTEGER
            count 2
            range '0 - 64'
            dbmin -6400
            dbmax 0
            dbvalue.0 0
            dbvalue.1 0
        }
    }
    control.4 {
        iface CARD
        name 'Keep Interface'
        value false
        comment {
            access 'read write'
            type BOOLEAN
            count 1
        }
    }
}
EOT

#####

sudo bash -c "cat >> /boot/config.txt" << EOT
avoid_safe_mode=1
boot_delay=0
disable_camera_led=1
disable_splash=1
dtparam=act_led_activelow=on
dtparam=act_led_trigger=none
dtparam=audio=off
dtparam=watchdog=off
gpu_mem=32
EOT

#####

sudo bash -c "cat > /boot/cmdline.txt" << EOT
root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait fastboot noswap ro quiet dwc_otg.speed=1 dwc_otg.lpm_enable=0 raid=noautodetect audit=0 plymouth.enable=0
EOT

#####

sudo mkdir -p /var/spool
sudo mkdir -p /var/spool/cron
sudo bash -c "echo \"@reboot /usr/bin/tvservice -o & >> /dev/null 2>&1\" | tee -a /var/spool/cron/root"

#####

sudo bash -c "cat > /etc/fstab" << EOT
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ext4    defaults,noatime  0       1
tmpfs        /tmp            tmpfs   defaults,rw,noatime,nosuid,nodev,noexec,mode=1777         0       0
tmpfs        /var/log        tmpfs   nosuid,nodev,noatime         0       0
tmpfs        /var/tmp        tmpfs   nosuid,nodev,noatime         0       0
EOT

#####

sudo rm -rf /var/lib/dhcp /var/lib/dhcpcd5 /var/spool /etc/resolv.conf
sudo ln -s /tmp /var/lib/dhcp
sudo ln -s /tmp /var/lib/dhcpcd5
sudo ln -s /tmp /var/spool
sudo touch /tmp/dhcpcd.resolv.conf
sudo ln -s /tmp/dhcpcd.resolv.conf /etc/resolv.conf

sudo rm /var/lib/systemd/random-seed
sudo ln -s /tmp/random-seed /var/lib/systemd/random-seed

#####

sudo bash -c "cat > /lib/systemd/system/systemd-random-seed.service" << EOT
#  SPDX-License-Identifier: LGPL-2.1+
#
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

[Unit]
Description=Load/Save Random Seed
Documentation=man:systemd-random-seed.service(8) man:random(4)
DefaultDependencies=no
RequiresMountsFor=/var/lib/systemd/random-seed
Conflicts=shutdown.target
After=systemd-remount-fs.service
Before=sysinit.target shutdown.target
ConditionVirtualization=!container

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/echo "" >/tmp/random-seed
ExecStart=/lib/systemd/systemd-random-seed load
ExecStop=/lib/systemd/systemd-random-seed save
TimeoutSec=30s

EOT

#####

sudo bash -c "cat > /etc/bash.bashrc" << EOT
# System-wide .bashrc file for interactive bash(1) shells.
[ -z "$\PS1" ] && return
shopt -s checkwinsize
if [ -z "\${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=\$(cat /etc/debian_chroot)
fi
if ! [ -n "\${SUDO_USER}" -a -n "\${SUDO_PS1}" ]; then
  PS1='\${debian_chroot:+(\$debian_chroot)}\u@\h:\w\\$ '
fi
if [ -x /usr/lib/command-not-found -o -x /usr/share/command-not-found/command-not-found ]; then
    function command_not_found_handle {
            # check because c-n-f could've been removed in the meantime
                if [ -x /usr/lib/command-not-found ]; then
           /usr/lib/command-not-found -- "\$1"
                   return \$?
                elif [ -x /usr/share/command-not-found/command-not-found ]; then
           /usr/share/command-not-found/command-not-found -- "\$1"
                   return \$?
        else
           printf "%s: command not found\n" "\$1" >&2
           return 127
        fi
    }
fi
set_bash_prompt() {
    fs_mode=\$(mount | sed -n -e "s/^\/dev\/.* on \/ .*(\(r[w|o]\).*/\1/p")
    PS1='\[\033[01;32m\]\u@\h\${fs_mode:+(\$fs_mode)}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\$ '
}
alias ro='sudo mount -o remount,ro / ; sudo mount -o remount,ro /boot'
alias rw='sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot'
PROMPT_COMMAND=set_bash_prompt
EOT

#####

sudo bash -c "cat > /etc/bash.bash_logout" << EOT
mount -o remount,ro /
mount -o remount,ro /boot
EOT

###

sudo systemctl mask apt-daily.service
sudo systemctl mask avahi-daemon.service
sudo systemctl mask dphys-swapfile.service
sudo systemctl mask serial-getty@ttyAMA0.service
sudo systemctl mask systemd-journal-flush.service
sudo systemctl mask systemd-journald.service
sudo systemctl mask triggerhappy.service

sudo apt-get -y remove --purge busybox-syslogd
sudo apt-get -y remove --purge busybox

if [[ "$model" == "Raspberry Pi Zero Rev"* ]] ; then
    sudo apt remove -y --purge dhcpcd5
    sudo apt remove -y --purge ifupdown
    sudo apt remove -y --purge isc-dhcp-client isc-dhcp-common
    sudo systemctl mask console-setup.service
    sudo systemctl mask dhcpcd.service
    sudo systemctl mask hciuart.service
    sudo systemctl mask keyboard-setup.service
    sudo systemctl mask networking.service
    sudo systemctl mask ntp.service
    sudo systemctl mask raspi-config.service
    sudo systemctl mask rpi-eeprom-update
    sudo systemctl mask ssh.service
    sudo systemctl mask systemd-timesyncd.service
    sudo systemctl mask wifi-country.service
else
    iplast=`echo $ip | cut -d . -f 4`
    sudo hostname wuneu-radio-$iplast
    passwd
    sudo passwd
    echo
    echo "From your computer run:"
    echo "ssh-copy-id pi@$ip"
    echo
    echo "This will copy your public SSH key to the Pi. You can then ssh in with"
    echo "ssh pi@$ip"
    echo
fi

#####

echo "Setup complete. This Pi will shut down in 30 seconds."

sleep 30

sudo shutdown 0
