#!/system/bin/sh
#
# This file is part of The BiTGApps Project

# Set default module
MODULE="/data/adb/modules/MicroG"
# Magisk Current Base Folder
MIRROR="$(magisk --path)/.magisk/mirror"
# Mount actual partition
mount -o remount,rw,errors=continue / > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
mount -o remount,rw,errors=continue /system > /dev/null 2>&1
# Mount mirror partition
mount -o remount,rw,errors=continue $MIRROR/system_root 2>/dev/null
mount -o remount,rw,errors=continue $MIRROR/system 2>/dev/null
# Set installation layout
SYSTEM="$MIRROR/system"
# Enable GooglePlayServices APK
for i in MicroGGMSCore; do
  if [ -f "$SYSTEM/priv-app/$i/$i.dpk" ]; then
    mv -f $SYSTEM/priv-app/$i/$i.dpk $SYSTEM/priv-app/$i/$i.apk
  fi
  # Restore after OTA upgrade
  if [ ! -d "$SYSTEM/priv-app/$i" ]; then
    cp -fR $MODULE/system/priv-app/$i $SYSTEM/priv-app/$i
  fi
done
# Check module status
test -f "$MODULE/disable" || exit 1
# Purge runtime permissions
rm -rf $(find /data -type f -iname "runtime-permissions.xml")
