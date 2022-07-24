#!/system/bin/sh
#
# This file is part of The BiTGApps Project

# Remove MicroG Module
rm -rf /data/adb/modules/MicroG
# Remove Magisk Scripts
rm -rf /data/adb/post-fs-data.d/service.sh
rm -rf /data/adb/service.d/modprobe.sh
rm -rf /data/adb/service.d/runtime.sh
# Mount partitions
mount -o remount,rw,errors=continue / > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
mount -o remount,rw,errors=continue /system > /dev/null 2>&1
mount -o remount,rw,errors=continue /product > /dev/null 2>&1
# Remove Google Mobile Services
rm -rf /system/app/AppleNLPBackend
rm -rf /system/app/DejaVuNLPBackend
rm -rf /system/app/FossDroid
rm -rf /system/app/LocalGSMNLPBackend
rm -rf /system/app/LocalWiFiNLPBackend
rm -rf /system/app/MozillaUnifiedNLPBackend
rm -rf /system/app/NominatimNLPBackend
rm -rf /system/priv-app/DroidGuard
rm -rf /system/priv-app/Extension
rm -rf /system/priv-app/MicroGGMSCore
rm -rf /system/priv-app/MicroGGSFProxy
rm -rf /system/priv-app/Phonesky
rm -rf /system/etc/default-permissions/default-permissions.xml
rm -rf /system/etc/permissions/com.google.android.maps.xml
rm -rf /system/etc/permissions/privapp-permissions-microg.xml
rm -rf /system/etc/sysconfig/microg.xml
rm -rf /system/framework/com.google.android.maps.jar
rm -rf /system/product/overlay/PlayStoreOverlay.apk
# Remove application data
rm -rf /data/app/com.android.vending*
rm -rf /data/app/com.google.android*
rm -rf /data/app/*/com.android.vending*
rm -rf /data/app/*/com.google.android*
rm -rf /data/data/com.android.vending*
rm -rf /data/data/com.google.android*
