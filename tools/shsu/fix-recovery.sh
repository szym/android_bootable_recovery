#!/bin/bash
set -e

cmd=$1
P=${2:-recovery.img}

OUT=$ANDROID_PRODUCT_OUT
FLASH_IMAGE=$OUT/system/bin/flash_image
SBIN=$P-ramdisk/sbin/
INIT=$P-ramdisk/init.rc
PROP=$P-ramdisk/default.prop

SU=shsu

case $cmd in
  pull)
    echo "Pulling image..."
    adb wait-for-device
    adb shell "$SU -c dd if=/dev/mtd/mtd3 of=/sdcard/$P"
    adb pull /sdcard/$P $P
    cp $P $P.bkp
    echo "Unpacking..."
    unpack.sh $P
  ;;
  fix)
    echo "Updating binaries..."
    cp $OUT/{system/{bin/recovery,xbin/su},root/sbin/adbd} $SBIN
    echo "Patching default.prop..."
    sed -f - -i.backup $PROP <<EOF
s/ro.secure=1/ro.secure=0/
s/ro.debuggable=0/ro.debuggable=1/
s/persist.service.adb.enable=0/persist.service.adb.enable=1/
EOF
    echo "Adding shsu to init.rc..."
    grep -q shsu $INIT || cat >> $INIT <<EOF

# copy su to /system/xbin/$SU using builtins only
on property:shsu.install=1
    mount yaffs2 mtd@system /system
    mount yaffs2 mtd@system /system rw remount
    mkdir /system/xbin

    copy /sbin/su /system/xbin/$SU
    chown root shell /system/xbin/$SU
    chmod 4750 /system/xbin/shsu

    setprop shsu.installed 1
    write /sbin/shsu.installed 1

    # also, recovery overwrite precautions
    copy /system/etc/install-recovery.sh /system/etc/install-recovery.sh.not
    write /system/etc/install-recovery.sh "exit #"
EOF
    if [ -e $OUT/system/xbin/busybox ]; then
      echo "Installing busybox..."
      cp $OUT/system/xbin/busybox $SBIN
      grep -q busybox $INIT || sed -i.backup $INIT -e '
/on boot/i\
    chmod 0755 /sbin/busybox\
    symlink /sbin/busybox /sbin/sh\
    mkdir /system/bin\
    symlink /sbin/busybox /system/bin/sh\
'
    fi
  ;;
  flash)
    echo "Repacking..."
    repack.sh $P
    echo "Pushing image..."
    adb wait-for-device
    adb push $FLASH_IMAGE /data/local/flash_image
    adb push $P /sdcard/$P.new
    echo "Flashing..."
    adb shell "$SU -c /data/local/flash_image recovery /sdcard/$P.new"
    adb shell sync
    echo "Rebooting..."
    adb reboot recovery
  ;;
  all)
    $0 pull $2
    $0 fix $2
    $0 flash $2
  ;;
  "")
    echo "Usage: $0 pull|fix|flash|all <image>"
  ;;
esac
