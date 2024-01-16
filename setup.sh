#!/bin/sh
# Forked from https://github.com/pij-se/hifiberry-dac_plus_adc_pro-online_radio/setup.sh
#
# This script assumes you are using a Raspberry Pi 4 with HiFiBerry's DAC+ ADC Pro on
# Raspbian 11 (Bullseye). It will not work on other versions of Hifiberry's hardware
# without updating the device tree overlay in /boot/config.txt.
#
# A shell script to set up your Raspberry 4 with HiFiBerry's DAC+ ADC Pro, Icecast2,
# and Darkice, to create an online radio for streaming audio on your local
# network (for example from a turntable to Sonos).
#
# Copyright (c) 2023 Johan Palm <johan@pij.se>
# All rights reserved.
# Published under the GNU General Public License v3.0.

# Determine the platform to find the path to libmp3lame for Darkice.
case $(uname -m) in *"arm"*) lame=/usr/lib/arm-linux-gnueabihf/ ;; *) ;; esac
case $(uname -m) in *"x86"*) lame=/usr/lib/x86_64-linux-gnu ;; *) ;; esac
case $(uname -m) in *"aarch64"*) lame=/usr/lib/aarch64-linux-gnu ;; *) ;; esac
if [ "$lame" = "" ]; then echo "unable to detect platform, exiting..."; exit 1; fi

# detect linux kernel version and align it with version 5.15
# there are a lot of issues with newer and older versions of the linux kernel
# so we need to make sure we are using 5.15 to avoid these issues
# see https://github.com/raspberrypi/linux/issues/5709 for more info

#get current kernel version
current_version=$(uname -r | cut -d'-' -f1)

#set desired kernel version
desired_version="5.15.*"

echo "Current kernel version is $current_version and desired kernel version is $desired_version"

# Check if the current version starts with the desired pattern
if [ "${current_version%"${current_version#"$desired_version"}"}" == "$desired_version" ]; then
    echo "Current kernel version ($current_version) matches the pattern $desired_version."
else
    echo "Current kernel version ($current_version) does not match the pattern $desired_version."
    echo "Installing kernel version 5.15..."
    # download linux kernel 5.15 from hash
    sudo apt-get install rpi-update -y
    sudo rpi-update 921f5efeaed8a27980e5a6cfa2d2dee43410d60d
fi

# lock kernel version to 5.15
sudo apt-mark hold libraspberrypi-bin libraspberrypi-dev libraspberrypi-doc libraspberrypi0
sudo apt-mark hold raspberrypi-bootloader raspberrypi-kernel raspberrypi-kernel-headers

# Update the package list and upgrade packages.
echo "checking for package updates..."
sudo apt update
echo "upgrading packages..."
sudo apt upgrade -y

# Install and set up Icecast2.
echo "installing icecast2..."
sudo apt install icecast2 -y
sudo useradd icecast -g audio
sudo mkdir -p /var/icecast
sudo chown -R icecast /var/icecast
sudo chown -R icecast /var/log/icecast2
wget https://raw.githubusercontent.com/bgannon2/hifiberry-dac_plus_adc_pro-online_radio/main/icecast.xml
sudo mv /etc/icecast2/icecast.xml /etc/icecast2/icecast.xml.bak
sudo mv ./icecast.xml /etc/icecast2/icecast.xml
wget https://raw.githubusercontent.com/bgannon2/hifiberry-dac_plus_adc_pro-online_radio/main/icecast2.service
sudo mv ./icecast2.service /lib/systemd/system/icecast2.service
sudo systemctl enable icecast2

# Download, configure, and install Darkice.
echo "installing pre-requisites..."
sudo apt install libasound2-dev -y
sudo apt install libvorbis-dev -y
sudo apt install libmp3lame-dev -y
sudo apt install automake -y
sudo apt install autoconf -y
sudo apt install m4 -y
sudo apt install perl -y
sudo apt install libtool -y
sudo apt install pkg-config -y
sudo apt install build-essential -y
sudo apt install git -y

# Download, configure, and install Darkice.
echo "installing darkice..."
# Make darkice directory for final installation location
echo "making darkice directory..."
mkdir -p ./darkice
echo "downloading darkice-1.4..."
wget https://github.com/rafael2k/darkice/releases/download/v1.4/darkice-1.4.tar.gz
tar -xvkf darkice-1.4.tar.gz
cd darkice-1.4/
mv ./* ../darkice/
cd ..
# get darkice 1.5 patch that addresses gcc errors
echo "making darkice-1.5 directory..."
mkdir -p ./darkice-1.5
cd darkice-1.5/
echo "downloading darkice-1.5 patch..."
wget https://github.com/titixbrest/darkice/releases/download/1.5/darkice-1.5.tar.gz
tar -xvkf darkice-1.5.tar.gz
mv ./* ../darkice/
cd ../darkice
echo "configuring darkice..."
./configure --with-alsa --with-vorbis --with-lame-prefix=$lame
echo "installing darkice..."
sudo make install
sudo make clean
cd ..
echo "cleaning up darkice..."
rm -rf ./darkice-1.4
rm -f ./darkice-1.4.tar.gz
rm -rf ./darkice-1.5
echo "moving configs..."
wget https://raw.githubusercontent.com/pij-se/hifiberry-dac_plus_adc_pro-online_radio/main/darkice.cfg
sudo mv ./darkice.cfg /etc/darkice.cfg
wget https://raw.githubusercontent.com/pij-se/hifiberry-dac_plus_adc_pro-online_radio/main/darkice.service
sudo mv ./darkice.service /lib/systemd/system/darkice.service
sudo systemctl enable darkice

# Edit /boot/config.txt to disable on-board audio and enable HiFiBerry audio.
# Ignore failure message, this is expected but the file still gets moved.
echo "Manually edit /boot/config.txt to disable on-board audio and enable HiFiBerry audio"
wget https://raw.githubusercontent.com/bgannon2/hifiberry-dac_plus_adc_pro-online_radio/main/boot-config.txt
sudo mv ./boot-config.txt /boot/config.txt

# Reboot
echo "rebooting..."
sudo reboot
