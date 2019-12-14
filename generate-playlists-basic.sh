#!/bin/bash

rm -rf ~/playlists/* 2> /dev/null

MUSIC_DIR=/home/pi/music/*
songindex=0

echo "Creating basic playlists. Once you've uploaded music you may want to use a script which groups music be date or genre."

echo "Scanning music"
echo "" > /tmp/playlists.txt
for d in $MUSIC_DIR ; do
    if [ -d "$d" ] ; then
        basename=`basename "$d"`
        for f in $d/*.m4a ; do
            if [ -f "$f" ] ; then
                echo "$f" >> /tmp/playlists.txt
            fi
        done
    fi
done

files=`cat /tmp/playlists.txt`
for line in $files; do
    fbasename=`basename "$line"`
    echo "> $songindex. $fbasename <"
    echo "$file" > "/home/pi/playlists/$songindex.m3u"
    cat /tmp/playlists.txt | shuf >> "/home/pi/playlists/$songindex.m3u"
    ((songindex++))
done

echo "$songindex -> /home/pi/playlists/song-count.txt"
echo $songindex > "/home/pi/playlists/song-count.txt"

echo "Playlists generated"
