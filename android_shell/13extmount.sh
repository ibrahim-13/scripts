#!/system/bin/sh

if [ ! -d /data/sd-ext2 ]
then
    mkdir /data/sd-ext2
fi

mount -t ext4 -o rw /dev/block/vold/179:2 /data/sdext2

mount -t ext4 -o rw /dev/block/mmcblk0p2 /data/sdext2

