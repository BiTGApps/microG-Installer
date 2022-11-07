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
# Check module status
test -f "$MODULE/disable" || exit 1
# Remove application data
rm -rf /data/app/com.android.vending*
rm -rf /data/app/com.google.android*
rm -rf /data/app/*/com.android.vending*
rm -rf /data/app/*/com.google.android*
rm -rf /data/data/com.android.vending*
rm -rf /data/data/com.google.android*
# Remove microG data
rm -rf /data/app/*fdroid*
rm -rf /data/app/*microg.nlp*
rm -rf /data/app/*fitchfamily*
rm -rf /data/app/*/*fdroid*
rm -rf /data/app/*/*fitchfamily*
rm -rf /data/app/*/*microg.nlp*
rm -rf /data/data/*fdroid*
rm -rf /data/data/*microg.nlp*
rm -rf /data/data/*fitchfamily*
# Disable GooglePlayServices APK
for i in MicroGGMSCore; do
  mv -f $SYSTEM/priv-app/$i/$i.apk $SYSTEM/priv-app/$i/$i.dpk
done
