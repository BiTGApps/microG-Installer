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

# Check module status
test -f "$MODULE/disable" || exit 1

# Remove application data
rm -rf /data/app/com.android.vending*
rm -rf /data/app/com.google.android*
rm -rf /data/app/*/com.android.vending*
rm -rf /data/app/*/com.google.android*
rm -rf /data/data/com.android.vending*
rm -rf /data/data/com.google.android*

# Disable GooglePlayServices APK
for i in MicroGGMSCore; do
  mv -f /system/priv-app/$i/$i.apk /system/priv-app/$i/$i.dpk
done

# Purge runtime permissions
rm -rf $(find /data -iname "runtime-permissions.xml" 2>/dev/null)
