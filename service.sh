#!/system/bin/sh
#
# This file is part of The BiTGApps Project

# Set default module
MODULE="/data/adb/modules/MicroG"

# Mount system partition
mount -o remount,rw,errors=continue / 2>/dev/null
mount -o remount,rw,errors=continue /dev/root 2>/dev/null
mount -o remount,rw,errors=continue /dev/block/dm-0 2>/dev/null
mount -o remount,rw,errors=continue /system 2>/dev/null

# Enable GooglePlayServices APK
for i in MicroGGMSCore; do
  if [ -f "/system/priv-app/$i/$i.dpk" ]; then
    mv -f /system/priv-app/$i/$i.dpk /system/priv-app/$i/$i.apk
  fi
  # Restore after OTA upgrade
  if [ ! -d "/system/priv-app/$i" ]; then
    cp -fR $MODULE/system/priv-app/$i /system/priv-app/$i
  fi
done
