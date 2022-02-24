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
ping -c 3 archlinux.org &> /dev/null
internet_working=$?

if [ $internet_working -eq 0 ]; then
	echo Internet is configured correctly... ready to begin.
else
	echo Make sure your network is configured correctly in order to continue
	exit 1
fi

timedatectl set-ntp true
if timedatectl status | grep -q 'active'; then
	echo System clock has been updated
else
	echo Failed to sync the system clock
	exit 2
fi

if [[ -z $(lsblk -o TYPE | grep disk) ]]; then
	echo failed to find valid drives for installation
	exit 3
fi

echo Select the drive you would like to install Arch on:
lsblk -o KNAME,TYPE,SIZE,MODEL | grep disk | nl -s ") "

echo pick a line number: 
read drive_selection

# extract device from lsblk list
device=$(lsblk -o KNAME,TYPE | grep disk | sed "${drive_selection}q;d" | cut -d" " -f1)
device=/dev/$device

echo "selected device is $device"
askYesNo "Is this correct?" false
if [ "$ANSWER" = false ]; then
	exit 4
fi

printf "\n\n"
printf "#-----------------------------------------------------------------------------------------------------------------------------------------------#\n"
printf "# WARNING: This script is about to completely wipe ALL PARTITIONS on the selected drive and then format it with the following partition scheme:	#\n"
printf "#																		#\n"
printf "#	|  partition  |        size        |        type        |										#\n"
printf "#	|      1      |        500MB       |        EFI         |										#\n"
printf "#	|      2      |         4GB        |        SWAP        |										#\n"
printf "#	|      3      |   remaining space  |  Linux Filesystem  |										#\n"
printf "#																		#\n"
printf "# If you have other operating systems on this drive, they will be erased.									#\n"
printf "# DO NOT continue using this script if you need to partition the disk differently.								#\n"
printf "#-----------------------------------------------------------------------------------------------------------------------------------------------#\n"
printf "\n\n"


askYesNo "Would you like to continue" false

if [ "$ANSWER" = false ]; then
	exit 0
fi

sgdisk --zap-all $device
echo drive has been wiped

# create the partitions
sgdisk -n=1:0:+500M $device
sgdisk -n=2:0:+4G $device
sgdisk -n=3:0:-1 $device

echo partitions have been created

# set the partition types
sgdisk -t:1:ef00 $device
sgdisk -t:2:8200 $device
sgdisk -t:3:8300 $device

echo partition types have been set

mkfs.fat -F 32 $device*1
mkswap $device*2
mkfs.ext4 $device*3

echo paritions have been formatted


mount $device*3 /mnt
swapon $device*2


# enable parallel downloads in pacman
sed -i 's/#ParallelD/ParallelD/g' /etc/pacman.conf

echo Installing arch packages
read -p "press return to continue..."


pacstrap /mnt base linux linux-firmware

genfstab -U /mnt >> /mnt/etc/fstab


cp ./configure.sh /mnt/configure.sh
arch-chroot /mnt ./configure.sh $device




umount -l /mnt

echo Installation has finished, you can now reboot into Arch Linux
askYesNo "Would you like to reboot now" true
if [ "$ANSWER" = true ]; then
	reboot now
fi





