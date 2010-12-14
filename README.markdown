shsu
====

This is a direct import of bootable/recovery from the AOSP master. A minimal
patch adds a new option `install shsu` which installs the included standard
su as `shsu` (shsu stands for *shell-only* su which means it only works over adb
shell).

The new option `install shsu` is executed every time before reboot. The action
is implemented by setting a property `shsu.install=1`. This change is picked
up by `init` which executes the action specified in `init.rc` using builtins
only:

    # copy su to /system/xbin/shsu using builtins only
    on property:shsu.install=1
        mount yaffs2 mtd@system /system
        mount yaffs2 mtd@system /system rw remount
        mkdir /system/xbin

        copy /sbin/su /system/xbin/shsu
        chown root shell /system/xbin/shsu
        chmod 4750 /system/xbin/shsu

        setprop shsu.installed 1
        write /sbin/shsu.installed 1

        # also, recovery overwrite precautions
        copy /system/etc/install-recovery.sh /system/etc/install-recovery.sh.not
        write /system/etc/install-recovery.sh "exit #"


One of the effects of this action is also disabling the automated patching of
the recovery partition. You can later apply the recovery patch manually by
executing (in su shell):
    sh /etc/install-recovery.sh.not
...although you might have to edit the script to remove the `exit` if you called
`install shsu` more than once.

fix-recovery.sh
---------------

A simple script `tools/fix-recovery.sh` automates the process of retrieving the
current recovery image, replacing the recovery binary, installing the
`shsu.install` hook, and reflashing the image. It also installs busybox if
available in your `out` directory and "unsecures" properties to enable adb.

This script depends on [unbootimg](https://github.com/szym/unbootimg)

Usage:

    ./fix-recovery.sh (all|pull|fix|flash) [recovery-image-name]

You will need to build the following from the Android repo beforehand:

    make su flash_image recovery adbd unpack.sh repack.sh mkbootimg unbootimg
