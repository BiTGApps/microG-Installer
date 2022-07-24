#!/bin/bash
#
# This file is part of The BiTGApps Project

# Structure
mkdir -p "META-INF/com/google/android"
mkdir -p "zip"
mkdir -p "zip/core"
mkdir -p "zip/sys"
mkdir -p "zip/framework"
mkdir -p "zip/overlay"

# Packages
cp -f sources/microG-sources/app/AppleNLPBackend.tar.xz zip/sys
cp -f sources/microG-sources/app/DejaVuNLPBackend.tar.xz zip/sys
cp -f sources/microG-sources/app/FossDroid.tar.xz zip/sys
cp -f sources/microG-sources/app/LocalGSMNLPBackend.tar.xz zip/sys
cp -f sources/microG-sources/app/LocalWiFiNLPBackend.tar.xz zip/sys
cp -f sources/microG-sources/app/MozillaUnifiedNLPBackend.tar.xz zip/sys
cp -f sources/microG-sources/app/NominatimNLPBackend.tar.xz zip/sys
cp -f sources/microG-sources/priv-app/DroidGuard.tar.xz zip/core
cp -f sources/microG-sources/priv-app/Extension.tar.xz zip/core
cp -f sources/microG-sources/priv-app/MicroGGMSCore.tar.xz zip/core
cp -f sources/microG-sources/priv-app/MicroGGSFProxy.tar.xz zip/core
cp -f sources/microG-sources/priv-app/Phonesky.tar.xz zip/core
cp -f sources/microG-sources/framework/MapsFramework.tar.xz zip/framework
cp -f sources/microG-sources/framework/MapsPermissions.tar.xz zip/framework
cp -f sources/microG-sources/overlay/PlayStoreOverlay.tar.xz zip/overlay
cp -f sources/microG-sources/etc/Default.tar.xz zip
cp -f sources/microG-sources/etc/Permissions.tar.xz zip
cp -f sources/microG-sources/etc/Sysconfig.tar.xz zip

# Scripts
cp -f update-binary.sh META-INF/com/google/android/update-binary
cp -f updater-script.sh META-INF/com/google/android/updater-script

# License
rm -rf LICENSE && mv -f LICENSE.microG LICENSE

# Cleanup
rm -rf README.md sources update-binary.sh updater-script.sh
