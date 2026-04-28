# VirtFS

> https://docs.getutm.app/guest-support/linux/

After making sure your Linux installation supports 9pfs, you can automatically mount the share by adding the following entry to your `/etc/fstab`:

```sh
# Shared Folder
share /mnt/shared 9p trans=virtio,version=9p2000.L,rw,_netdev,nofail,auto 0 0
```

*Note*: `share` is the name UTM uses for the VirtIO device and you should not change it. You can replace `/mnt/shared` with a different folder if you like.

After updating `/etc/fstab` you need to create an empty folder for the mount:

```sh
sudo mkdir /mnt/shared
```

You can apply the changes to `/etc/fstab` with the following commands (this will automatically happen on reboot as well):

```sh
systemctl daemon-reload
systemctl restart network-fs.target # use remote-fs.target if not found
systemctl list-units --type=mount
```

A systemd `.mount` unit for `/mnt/shared` should now be displayed in the list, and you can access the contents of your shared folder.

## Fixing permission errors

You may notice that accessing the mount point fails with “access denied” unless you’re the root user. This is because by default the directory inherits the UID/GID from macOS/iOS which has a different numbering scheme.

To fix this we are going to use [bindfs](https://bindfs.org/) to create a mount in the user’s home directory that we can access normally. You have to first install `bindfs` with your system’s package manager.

The first step is to get the UID and GID used by the host:

```sh
$ ls -na /mnt/shared
total 8
drwxr-xr-x 4 502 20  128 Feb 22 15:52 .
drwxr-xr-x 3   0  0 4096 Feb 22 14:50 ..
-rw-r--r-- 1 502 20   13 Feb 22 15:52 shared-file.txt
```

In this case the UID for the host is `502` and the GID is `20`. You have to do the same for the guest user (usually UID `1000` and GID `1000`). Additionally, create an empty folder for the `bindfs` mount in the home directory:

```sh
mkdir /home/user/shared
```

*Note*: In this example the username is `user`, you might have to adjust this to match your configuration.

Now add another entry to `/etc/fstab`:

```sh
# bindfs mount to remap UID/GID
/mnt/utm /home/user/utm fuse.bindfs map=502/1000:@20/@1000,x-systemd.requires=/mnt/utm,_netdev,nofail,auto 0 0
```

An alternative solution is to recursively change the permissions of the files in your shared folder:

```sh
$ sudo chown -R $USER /mnt/utm
```

Note: This will not change the permissions on your host system, but it will add a custom `user.virtfs` file attributes to every file to store the guest ownership. It is not recommended to do this if you want to share your host’s home folder for instance.