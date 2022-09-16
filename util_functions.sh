# This file is part of The BiTGApps Project

# Define Current Version
version="v1.2"
versionCode="12"

# Define Installation Size
CAPACITY="100000"

print_title() {
  local LEN ONE TWO BAR
  ONE=$(echo -n $1 | wc -c)
  TWO=$(echo -n $2 | wc -c)
  LEN=$TWO
  [ $ONE -gt $TWO ] && LEN=$ONE
  LEN=$((LEN + 2))
  BAR=$(printf "%${LEN}s" | tr ' ' '*')
  ui_print "$BAR"
  ui_print " $1 "
  [ "$2" ] && ui_print " $2 "
  ui_print "$BAR"
}

# Handle Magisk Magic Mount
list_files() {
cat <<EOF
system/app/FaceLock
system/app/GoogleCalendarSyncAdapter
system/app/GoogleContactsSyncAdapter
system/priv-app/ConfigUpdater
system/priv-app/GmsCoreSetupPrebuilt
system/priv-app/GoogleLoginService
system/priv-app/GoogleServicesFramework
system/priv-app/Phonesky
system/priv-app/PrebuiltGmsCore
system/etc/default-permissions/default-permissions.xml
system/etc/default-permissions/setup-permissions.xml
system/etc/permissions/com.google.android.dialer.support.xml
system/etc/permissions/com.google.android.maps.xml
system/etc/permissions/privapp-permissions-google.xml
system/etc/permissions/split-permissions-google.xml
system/etc/preferred-apps/google.xml
system/etc/sysconfig/google.xml
system/etc/sysconfig/google_build.xml
system/etc/sysconfig/google_exclusives_enable.xml
system/etc/sysconfig/google-hiddenapi-package-whitelist.xml
system/etc/sysconfig/google-rollback-package-whitelist.xml
system/etc/sysconfig/google-staged-installer-whitelist.xml
system/framework/com.google.android.dialer.support.jar
system/framework/com.google.android.maps.jar
system/product/overlay/PlayStoreOverlay.apk
EOF
}
