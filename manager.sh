#!/system/bin/sh
#
# This file is part of The BiTGApps Project

# Remove Magisk Scripts
rm -rf /data/adb/post-fs-data.d/service.sh
rm -rf /data/adb/service.d/modprobe.sh
rm -rf /data/adb/service.d/module.sh
rm -rf /data/adb/service.d/runtime.sh
# Magisk Current Base Folder
MIRROR="$(magisk --path)/.magisk/mirror"
# Mount actual partitions
mount -o remount,rw,errors=continue / > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
mount -o remount,rw,errors=continue /system > /dev/null 2>&1
mount -o remount,rw,errors=continue /product > /dev/null 2>&1
mount -o remount,rw,errors=continue /system_ext > /dev/null 2>&1
# Mount mirror partitions
mount -o remount,rw,errors=continue $MIRROR/system_root 2>/dev/null
mount -o remount,rw,errors=continue $MIRROR/system 2>/dev/null
mount -o remount,rw,errors=continue $MIRROR/product 2>/dev/null
mount -o remount,rw,errors=continue $MIRROR/system_ext 2>/dev/null
# Set installation layout
SYSTEM="$MIRROR/system"
# Current Base Folder
test -d "$MIRROR" || SYSTEM='/system'
# Remove Google Mobile Services
rm -rf $SYSTEM/app/AppleNLPBackend
rm -rf $SYSTEM/app/DejaVuNLPBackend
rm -rf $SYSTEM/app/FossDroid
rm -rf $SYSTEM/app/LocalGSMNLPBackend
rm -rf $SYSTEM/app/LocalWiFiNLPBackend
rm -rf $SYSTEM/app/MozillaUnifiedNLPBackend
rm -rf $SYSTEM/app/NominatimNLPBackend
rm -rf $SYSTEM/priv-app/DroidGuard
rm -rf $SYSTEM/priv-app/Extension
rm -rf $SYSTEM/priv-app/MicroGGMSCore
rm -rf $SYSTEM/priv-app/MicroGGSFProxy
rm -rf $SYSTEM/priv-app/Phonesky
rm -rf $SYSTEM/etc/default-permissions/default-permissions.xml
rm -rf $SYSTEM/etc/permissions/com.google.android.maps.xml
rm -rf $SYSTEM/etc/permissions/privapp-permissions-microg.xml
rm -rf $SYSTEM/etc/sysconfig/microg.xml
rm -rf $SYSTEM/etc/security/fsverity/gms_fsverity_cert.der
rm -rf $SYSTEM/etc/security/fsverity/play_store_fsi_cert.der
rm -rf $SYSTEM/framework/com.google.android.maps.jar
rm -rf $SYSTEM/product/overlay/PlayStoreOverlay.apk
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
# Purge runtime permissions
rm -rf $(find /data -iname "runtime-permissions.xml" 2>/dev/null)
# Remove MicroG Module
rm -rf /data/adb/modules/MicroG
