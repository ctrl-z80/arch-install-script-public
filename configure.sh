#!/bin/bash

function askYesNo {
	QUESTION=$1
	DEFAULT=$2
	if [ "$DEFAULT" = true ]; then
		OPTIONS="[Y/n]"
		DEFAULT="y"
	else
		OPTIONS="[y/N]"
		default="n"
	fi
	read -p "$QUESTION $OPTIONS " -n 1 -s -r INPUT
	INPUT=${INPUT:-${DEFAULT}}
	echo ${INPUT}
	if [[ "$INPUT" =~ ^[yY]$ ]]; then
		ANSWER=true
	else
		ANSWER=false
	fi

}

device=$1
echo $device


echo This script can automatically configure the timezone and locale using the IP based geolocation api: https://ipapi.co
askYesNo "Would you like to use this service" true

if [ "$ANSWER" = true ]; then
	echo Configuring timezone...
	zone=$(curl -s https://ipapi.co/timezone)
	loca=$(curl -s https://ipapi.co/languages | awk -F',' '{print $1}')
	loca=$(echo $loca | sed 's/-/_/g')
	loca=$loca.UTF-8
	echo $loca
	ln -sf /usr/share/zoneinfo/$zone /etc/localtime
	sed -i "s/#$loca/$loca/" /etc/locale.gen
	locale-gen
	touch /etc/locale.conf
	echo LANG=$loca > /etc/locale.conf
	
	
else
	echo timezone and locale will not be configured. You may have to configure these this manually later.
fi

echo configuring hardware clock...
hwclock --systohc

read -p "Enter a hostname for this device: " HOSN
echo $HOSN > /etc/hostname

echo Creating a new user
read -p "Enter a username: " USRNM

useradd -m $USRNM

echo Type a password for the new user 
passwd $USRNM

usermod -a -G wheel,audio,video,storage $USRNM


echo Configuring sudo...
pacman -S sudo

# Give wheel group full sudo rights
cp /etc/sudoers /etc/sudoers_backup.bkp
sed -i 's/# %wheel ALL=(AL.*) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

FLAGA=0
FLAGB=0

if [ visudo -c -f /etc/sudoers | grep -q OK ]; then
	FLAGA=1
fi

if [ cmp -s /etc/sudoers /etc/sudoers_backup.bkp -eq 1 ]; then
	FLAGB=1
fi

if [[ "$FLAGA" == 1 && "$FLAGB" == 1 ]]; then
	echo sudo has been configured correctly
else
	echo WARNING: failed to configure sudo, you will need to configure sudo correctly before rebooting	
fi


echo installing GRUB...
pacman -S grub efibootmgr dosfstools iwd networkmanager


mkdir /boot/EFI
mount $device*1 /boot/EFI
echo $(ls /boot/EFI)

grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
grub-mkconfig -o /boot/grub/grub.cfg


