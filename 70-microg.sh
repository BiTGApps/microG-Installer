#!/sbin/sh
#
# This file is part of The BiTGApps Project

# ADDOND_VERSION=3

if [ -z "$backuptool_ab" ]; then
  SYS="$S"
  TMP=/tmp
else
  SYS="/postinstall/system"
  TMP="/postinstall/tmp"
fi

. /tmp/backuptool.functions

list_files() {
cat <<EOF
app/AppleNLPBackend/AppleNLPBackend.apk
app/DejaVuNLPBackend/DejaVuNLPBackend.apk
app/FossDroid/FossDroid.apk
app/LocalGSMNLPBackend/LocalGSMNLPBackend.apk
app/LocalWiFiNLPBackend/LocalWiFiNLPBackend.apk
app/MozillaUnifiedNLPBackend/MozillaUnifiedNLPBackend.apk
app/NominatimNLPBackend/NominatimNLPBackend.apk
priv-app/DroidGuard/DroidGuard.apk
priv-app/Extension/Extension.apk
priv-app/MicroGGMSCore/MicroGGMSCore.apk
priv-app/MicroGGSFProxy/MicroGGSFProxy.apk
priv-app/Phonesky/Phonesky.apk
etc/default-permissions/default-permissions.xml
etc/permissions/com.google.android.maps.xml
etc/permissions/privapp-permissions-microg.xml
etc/sysconfig/microg.xml
etc/security/fsverity/gms_fsverity_cert.der
etc/security/fsverity/play_store_fsi_cert.der
framework/com.google.android.maps.jar
product/overlay/PlayStoreOverlay.apk
EOF
}

case "$1" in
  backup)
    list_files | while read FILE DUMMY; do
      backup_file $S/"$FILE"
    done
  ;;
  restore)
    list_files | while read FILE REPLACEMENT; do
      R=""
      [ -n "$REPLACEMENT" ] && R="$S/$REPLACEMENT"
      [ -f "$C/$S/$FILE" ] && restore_file $S/"$FILE" "$R"
    done
    for i in $(list_files); do
      chown root:root "$SYS/$i" 2>/dev/null
      chmod 644 "$SYS/$i" 2>/dev/null
      chmod 755 "$(dirname "$SYS/$i")" 2>/dev/null
    done
  ;;
esac
