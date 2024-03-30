#!/usr/bin/env bash

TARGET=
MOUNT_DIR=

read -p "virtio-9p target: " TARGET
read -p "mount directory: " MOUNT_DIR

echo "mounting $TARGET to $MOUNT_DIR"
sudo mkdir -p "$MOUNT_DIR"
sudo mount -t 9p -o trans=virtio "$TARGET" "$MOUNT_DIR" -oversion=9p2000.L
