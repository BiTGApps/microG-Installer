# This file is part of The BiTGApps Project

# Handle installation of MicroG Package
ZIPNAME="$(basename "$ZIPFILE" ".zip" | tr '[:upper:]' '[:lower:]')"

# GITHUB RAW URL
MODULE_URL='https://raw.githubusercontent.com'

# Module JSON URL
MODULE_JSN='BiTGApps/Patched-Module/master/all/module.json'

# Required for System installation
IS_MAGISK_MODULES="false"
if [ -d "/data/adb/modules" ]; then
  IS_MAGISK_MODULES="true"
fi

# Magisk Current Base Folder
MIRROR="$(magisk --path)/.magisk/mirror"

# Remove Magisk Scripts
rm -rf /data/adb/post-fs-data.d/service.sh
rm -rf /data/adb/service.d/modprobe.sh
rm -rf /data/adb/service.d/module.sh
rm -rf /data/adb/service.d/runtime.sh

# Installation base is Bootmode script
if [[ "$(getprop "sys.bootmode")" = "1" ]]; then
  # System is writable
  if ! touch $SYSTEM/.rw >/dev/null 2>&1; then
    echo "! Read-only file system"
    exit 1
  fi
fi

# Allow mounting, when installation base is Magisk
if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
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
  # Backup installation layout
  SYSTEM_AS_SYSTEM="$SYSTEM"
  # System is writable
  if ! touch $SYSTEM/.rw >/dev/null 2>&1; then
    echo "! Read-only file system"
    exit 1
  fi
  install -d $SYSTEM/etc/module
fi

# Product is a dedicated partition
if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
  if grep -q " $(readlink -f /product) " /proc/mounts; then
    ln -sf /product /system
  fi
fi

# Detect whether in boot mode
[ -z $BOOTMODE ] && ps | grep zygote | grep -qv grep && BOOTMODE="true"
[ -z $BOOTMODE ] && ps -A 2>/dev/null | grep zygote | grep -qv grep && BOOTMODE="true"
[ -z $BOOTMODE ] && BOOTMODE="false"

# Strip leading directories
if [ "$BOOTMODE" = "false" ]; then
  DEST="-f5-"
else
  DEST="-f6-"
fi

# Extract utility script
if [ "$BOOTMODE" = "false" ]; then
  unzip -oq "$ZIPFILE" "util_functions.sh" -d "$TMP"
fi
# Allow unpack, when installation base is Magisk
if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
  $(unzip -oq "$ZIPFILE" "util_functions.sh" -d "$TMP")
fi
chmod +x "$TMP/util_functions.sh"

# Load utility functions
. $TMP/util_functions.sh

# Extract uninstaller script
if [ "$BOOTMODE" = "false" ]; then
  unzip -oq "$ZIPFILE" "manager.sh" -d "$TMP"
fi
# Allow unpack, when installation base is Magisk
if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
  $(unzip -oq "$ZIPFILE" "manager.sh" -d "$TMP")
fi
chmod +x "$TMP/manager.sh"

ui_print() {
  if [ "$BOOTMODE" = "true" ]; then
    echo "$1"
  fi
  if [ "$BOOTMODE" = "false" ]; then
    echo -n -e "ui_print $1\n" >> /proc/self/fd/$OUTFD
    echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD
  fi
}

print_title "MicroG $version Installer"

recovery_actions() {
  if [ "$BOOTMODE" = "false" ]; then
    OLD_LD_LIB=$LD_LIBRARY_PATH
    OLD_LD_PRE=$LD_PRELOAD
    OLD_LD_CFG=$LD_CONFIG_FILE
    unset LD_LIBRARY_PATH
    unset LD_PRELOAD
    unset LD_CONFIG_FILE
  fi
}

recovery_cleanup() {
  if [ "$BOOTMODE" = "false" ]; then
    [ -z $OLD_LD_LIB ] || export LD_LIBRARY_PATH=$OLD_LD_LIB
    [ -z $OLD_LD_PRE ] || export LD_PRELOAD=$OLD_LD_PRE
    [ -z $OLD_LD_CFG ] || export LD_CONFIG_FILE=$OLD_LD_CFG
  fi
}

build_defaults() {
  # Compressed Packages
  ZIP_FILE="$TMP/zip"
  # Extracted Packages
  mkdir $TMP/unzip
  # Initial link
  UNZIP_DIR="$TMP/unzip"
  # Create links
  TMP_SYS="$UNZIP_DIR/tmp_sys"
  TMP_PRIV="$UNZIP_DIR/tmp_priv"
  TMP_PRIV_SETUP="$UNZIP_DIR/tmp_priv_setup"
  TMP_FRAMEWORK="$UNZIP_DIR/tmp_framework"
  TMP_SYSCONFIG="$UNZIP_DIR/tmp_config"
  TMP_DEFAULT="$UNZIP_DIR/tmp_default"
  TMP_PERMISSION="$UNZIP_DIR/tmp_perm"
  TMP_PREFERRED="$UNZIP_DIR/tmp_pref"
  TMP_OVERLAY="$UNZIP_DIR/tmp_overlay"
}

on_partition_check() {
  system_as_root=`getprop ro.build.system_root_image`
  slot_suffix=`getprop ro.boot.slot_suffix`
  AB_OTA_UPDATER=`getprop ro.build.ab_update`
  dynamic_partitions=`getprop ro.boot.dynamic_partitions`
}

ab_partition() {
  device_abpartition="false"
  if [ ! -z "$slot_suffix" ]; then
    device_abpartition="true"
  fi
  if [ "$AB_OTA_UPDATER" = "true" ]; then
    device_abpartition="true"
  fi
}

system_as_root() {
  SYSTEM_ROOT="false"
  if [ "$system_as_root" = "true" ]; then
    SYSTEM_ROOT="true"
  fi
}

super_partition() {
  SUPER_PARTITION="false"
  if [ "$dynamic_partitions" = "true" ]; then
    SUPER_PARTITION="true"
  fi
}

is_mounted() {
  grep -q " $(readlink -f $1) " /proc/mounts 2>/dev/null
  return $?
}

grep_cmdline() {
  local REGEX="s/^$1=//p"
  { echo $(cat /proc/cmdline)$(sed -e 's/[^"]//g' -e 's/""//g' /proc/cmdline) | xargs -n 1; \
    sed -e 's/ = /=/g' -e 's/, /,/g' -e 's/"//g' /proc/bootconfig; \
  } 2>/dev/null | sed -n "$REGEX"
}

setup_mountpoint() {
  test -L $1 && mv -f $1 ${1}_link
  if [ ! -d $1 ]; then
    rm -f $1
    mkdir $1
  fi
}

mount_apex() {
  if "$BOOTMODE"; then
    return 255
  fi
  test -d "$SYSTEM/apex" || return 255
  ui_print "- Mounting /apex"
  local apex dest loop minorx num
  setup_mountpoint /apex
  test -e /dev/block/loop1 && minorx=$(ls -l /dev/block/loop1 | awk '{ print $6 }') || minorx="1"
  num="0"
  for apex in $SYSTEM/apex/*; do
    dest=/apex/$(basename $apex | sed -E -e 's;\.apex$|\.capex$;;')
    test "$dest" = /apex/com.android.runtime.release && dest=/apex/com.android.runtime
    mkdir -p $dest
    case $apex in
      *.apex|*.capex)
        # Handle CAPEX APKs
        unzip -oq $apex original_apex -d /apex
        if [ -f "/apex/original_apex" ]; then
          apex="/apex/original_apex"
        fi
        # Handle APEX APKs
        unzip -oq $apex apex_payload.img -d /apex
        mv -f /apex/apex_payload.img $dest.img
        mount -t ext4 -o ro,noatime $dest.img $dest 2>/dev/null
        if [ $? != 0 ]; then
          while [ $num -lt 64 ]; do
            loop=/dev/block/loop$num
            (mknod $loop b 7 $((num * minorx))
            losetup $loop $dest.img) 2>/dev/null
            num=$((num + 1))
            losetup $loop | grep -q $dest.img && break
          done
          mount -t ext4 -o ro,loop,noatime $loop $dest 2>/dev/null
          if [ $? != 0 ]; then
            losetup -d $loop 2>/dev/null
          fi
        fi
      ;;
      *) mount -o bind $apex $dest;;
    esac
  done
  export ANDROID_RUNTIME_ROOT="/apex/com.android.runtime"
  export ANDROID_TZDATA_ROOT="/apex/com.android.tzdata"
  export ANDROID_ART_ROOT="/apex/com.android.art"
  export ANDROID_I18N_ROOT="/apex/com.android.i18n"
  local APEXJARS=$(find /apex -name '*.jar' | sort | tr '\n' ':')
  local FWK=$SYSTEM/framework
  export BOOTCLASSPATH="${APEXJARS}\
  $FWK/framework.jar:\
  $FWK/framework-graphics.jar:\
  $FWK/ext.jar:\
  $FWK/telephony-common.jar:\
  $FWK/voip-common.jar:\
  $FWK/ims-common.jar:\
  $FWK/framework-atb-backward-compatibility.jar:\
  $FWK/android.test.base.jar"
}

umount_apex() {
  if "$BOOTMODE"; then
    return 255
  fi
  test -d /apex || return 255
  local dest loop
  for dest in $(find /apex -type d -mindepth 1 -maxdepth 1); do
    if [ -f $dest.img ]; then
      loop=$(mount | grep $dest | cut -d" " -f1)
    fi
    (umount -l $dest
    losetup -d $loop) 2>/dev/null
  done
  rm -rf /apex 2>/dev/null
  unset ANDROID_RUNTIME_ROOT
  unset ANDROID_TZDATA_ROOT
  unset ANDROID_ART_ROOT
  unset ANDROID_I18N_ROOT
  unset BOOTCLASSPATH
}

umount_all() {
  if [ "$BOOTMODE" = "false" ]; then
    umount -l /system > /dev/null 2>&1
    umount -l /system_root > /dev/null 2>&1
    umount -l /product > /dev/null 2>&1
    umount -l /system_ext > /dev/null 2>&1
  fi
}

mount_all() {
  if "$BOOTMODE"; then
    return 255
  fi
  $SYSTEM_ROOT && ui_print "- Device is system-as-root"
  $SUPER_PARTITION && ui_print "- Super partition detected"
  # Check A/B slot
  [ "$slot" ] || slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
  [ "$slot" ] || slot=`grep_cmdline androidboot.slot_suffix`
  [ "$slot" ] || slot=`grep_cmdline androidboot.slot`
  [ "$slot" ] && ui_print "- Current boot slot: $slot"
  mount -o bind /dev/urandom /dev/random
  if ! is_mounted /cache; then
    mount /cache > /dev/null 2>&1
  fi
  if ! is_mounted /data; then
    mount /data > /dev/null 2>&1
    if [ -z "$(ls -A /sdcard)" ]; then
      mount -o bind /data/media/0 /sdcard
    fi
  fi
  mount -o ro -t auto /product > /dev/null 2>&1
  mount -o ro -t auto /system_ext > /dev/null 2>&1
  [ "$ANDROID_ROOT" ] || ANDROID_ROOT="/system"
  setup_mountpoint $ANDROID_ROOT
  if ! is_mounted $ANDROID_ROOT; then
    mount -o ro -t auto $ANDROID_ROOT > /dev/null 2>&1
  fi
  # Mount bind operation
  case $ANDROID_ROOT in
    /system_root) setup_mountpoint /system;;
    /system)
      if ! is_mounted /system && ! is_mounted /system_root; then
        setup_mountpoint /system_root
        mount -o ro -t auto /system_root
      elif [ -f "/system/system/build.prop" ]; then
        setup_mountpoint /system_root
        mount --move /system /system_root
        mount -o bind /system_root/system /system
      fi
      if [ $? != 0 ]; then
        umount -l /system > /dev/null 2>&1
      fi
    ;;
  esac
  case $ANDROID_ROOT in
    /system)
      if ! is_mounted $ANDROID_ROOT && [ -e /dev/block/mapper/system$slot ]; then
        mount -o ro -t auto /dev/block/mapper/system$slot /system_root > /dev/null 2>&1
        mount -o ro -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
        mount -o ro -t auto /dev/block/mapper/system_ext$slot /system_ext > /dev/null 2>&1
      fi
      if ! is_mounted $ANDROID_ROOT && [ -e /dev/block/bootdevice/by-name/system$slot ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot /system_root > /dev/null 2>&1
        mount -o ro -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
        mount -o ro -t auto /dev/block/bootdevice/by-name/system_ext$slot /system_ext > /dev/null 2>&1
      fi
    ;;
  esac
  # Mount bind operation
  if is_mounted /system_root; then
    if [ -f "/system_root/build.prop" ]; then
      mount -o bind /system_root /system
    else
      mount -o bind /system_root/system /system
    fi
  fi
  for block in system product system_ext; do
    for slot in "" _a _b; do
      blockdev --setrw /dev/block/mapper/$block$slot > /dev/null 2>&1
    done
  done
  mount -o remount,rw -t auto / > /dev/null 2>&1
  ui_print "- Mounting /system"
  if [ "$(grep -wo '/system' /proc/mounts)" ]; then
    mount -o remount,rw -t auto /system > /dev/null 2>&1
    is_mounted /system || on_abort "! Cannot mount /system"
  fi
  if [ "$(grep -wo '/system_root' /proc/mounts)" ]; then
    mount -o remount,rw -t auto /system_root > /dev/null 2>&1
    is_mounted /system_root || on_abort "! Cannot mount /system_root"
  fi
  ui_print "- Mounting /product"
  mount -o remount,rw -t auto /product > /dev/null 2>&1
  ui_print "- Mounting /system_ext"
  mount -o remount,rw -t auto /system_ext > /dev/null 2>&1
  # Set installation layout
  SYSTEM="/system"
  # Backup installation layout
  SYSTEM_AS_SYSTEM="$SYSTEM"
  # System is writable
  if ! touch $SYSTEM/.rw >/dev/null 2>&1; then
    on_abort "! Read-only file system"
  fi
  # Product is a dedicated partition
  if is_mounted /product; then
    ln -sf /product /system
  fi
  install -d $SYSTEM/etc/module
}

unmount_all() {
  if [ "$BOOTMODE" = "false" ]; then
    ui_print "- Unmounting partitions"
    umount -l /system > /dev/null 2>&1
    umount -l /system_root > /dev/null 2>&1
    umount -l /product > /dev/null 2>&1
    umount -l /system_ext > /dev/null 2>&1
    umount -l /dev/random > /dev/null 2>&1
  fi
}

f_cleanup() { (find .$TMP -mindepth 1 -maxdepth 1 -type f -not -name 'recovery.log' -not -name 'busybox-arm' -exec rm -rf '{}' \;); }

d_cleanup() { (find .$TMP -mindepth 1 -maxdepth 1 -type d -exec rm -rf '{}' \;); }

on_abort() {
  ui_print "$*"
  $BOOTMODE && exit 1
  umount_apex
  unmount_all
  recovery_cleanup
  f_cleanup 2>/dev/null
  d_cleanup 2>/dev/null
  ui_print "! Installation failed"
  ui_print " "
  true
  sync
  exit 1
}

on_installed() {
  umount_apex
  unmount_all
  recovery_cleanup
  f_cleanup 2>/dev/null
  d_cleanup 2>/dev/null
  ui_print "- Installation complete"
  ui_print " "
  true
  sync
  exit "$?"
}

sideload_config() {
  if [ "$BOOTMODE" = "false" ]; then
    unzip -oq "$ZIPFILE" "bitgapps-config.prop" -d "$TMP"
  fi
  # Allow unpack, when installation base is Magisk
  if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
    $(unzip -oq "$ZIPFILE" "bitgapps-config.prop" -d "$TMP")
  fi
}

get_bitgapps_config() {
  for d in /sdcard /sdcard1 /external_sd /usb_otg /usbstorage /data/media/0 /tmp /dev/tmp; do
    for f in $(find $d -iname "bitgapps-config.prop" 2>/dev/null); do
      if [ -f "$f" ]; then
        BITGAPPS_CONFIG="$f"
      fi
    done
  done
}

profile() {
  SYSTEM_PROPFILE="$SYSTEM/build.prop"
  BITGAPPS_PROPFILE="$BITGAPPS_CONFIG"
}

get_file_prop() { grep -m1 "^$2=" "$1" | cut -d= -f2; }

get_prop() {
  for f in $BITGAPPS_PROPFILE; do
    if [ -e "$f" ]; then
      prop="$(get_file_prop "$f" "$1")"
      if [ -n "$prop" ]; then
        break
      fi
    fi
  done
  if [ -z "$prop" ]; then
    getprop "$1" | cut -c1-
  else
    printf "$prop"
  fi
}

on_systemless_check() {
  supported_module_config="false"
  if [ -f "$BITGAPPS_CONFIG" ]; then
    supported_module_config="$(get_prop "ro.config.systemless")"
    # Re-write missing configuration
    if [ -z "$supported_module_config" ]; then
      supported_module_config="false"
    fi
    # Override unsupported configuration
    supported_module_config="false"
  fi
}

on_setup_check() {
  supported_setup_config="false"
  if [ -f "$BITGAPPS_CONFIG" ]; then
    supported_setup_config="$(get_prop "ro.config.setupwizard")"
    # Re-write missing configuration
    if [ -z "$supported_setup_config" ]; then
      supported_setup_config="false"
    fi
  fi
}

RTP_cleanup() {
  RTP="$(find /data -type f -iname "runtime-permissions.xml")"
  if [ -e "$RTP" ]; then
    if ! grep -qwo 'com.android.vending' $RTP; then
      rm -rf "$RTP"
    fi
  fi
}

mk_component() {
  for d in \
    $UNZIP_DIR/tmp_sys \
    $UNZIP_DIR/tmp_priv \
    $UNZIP_DIR/tmp_priv_setup \
    $UNZIP_DIR/tmp_framework \
    $UNZIP_DIR/tmp_config \
    $UNZIP_DIR/tmp_default \
    $UNZIP_DIR/tmp_perm \
    $UNZIP_DIR/tmp_pref \
    $UNZIP_DIR/tmp_overlay; do
    install -d "$d"
    chmod -R 0755 $TMP
  done
}

make_module_layout() {
  for d in \
    $SYSTEM_SYSTEM \
    $SYSTEM_APP \
    $SYSTEM_PRIV_APP \
    $SYSTEM_ETC \
    $SYSTEM_ETC_CONFIG \
    $SYSTEM_ETC_DEFAULT \
    $SYSTEM_ETC_PERM \
    $SYSTEM_ETC_PREF \
    $SYSTEM_FRAMEWORK \
    $SYSTEM_OVERLAY; do
    install -d "$d"
    chmod -R 0755 "$d"
    chcon -h u:object_r:system_file:s0 "$d"
  done
}

system_layout() {
  if [ "$supported_module_config" = "false" ]; then
    SYSTEM_ADDOND="$SYSTEM/addon.d"
    SYSTEM_APP="$SYSTEM/app"
    SYSTEM_PRIV_APP="$SYSTEM/priv-app"
    SYSTEM_ETC_CONFIG="$SYSTEM/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/framework"
    SYSTEM_OVERLAY="$SYSTEM/product/overlay"
  fi
}

system_module_layout() {
  if [ "$supported_module_config" = "true" ]; then
    SYSTEM_SYSTEM="$SYSTEM/system"
    SYSTEM_APP="$SYSTEM/system/app"
    SYSTEM_PRIV_APP="$SYSTEM/system/priv-app"
    SYSTEM_ETC="$SYSTEM/system/etc"
    SYSTEM_ETC_CONFIG="$SYSTEM/system/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/system/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/system/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/system/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/system/framework"
  fi
}

product_module_layout() {
  if [ "$supported_module_config" = "true" ]; then
    SYSTEM_SYSTEM="$SYSTEM/system/product"
    SYSTEM_APP="$SYSTEM/system/product/app"
    SYSTEM_PRIV_APP="$SYSTEM/system/product/priv-app"
    SYSTEM_OVERLAY="$SYSTEM/system/product/overlay"
  fi
}

system_ext_module_layout() {
  if [ "$supported_module_config" == "true" ]; then
    SYSTEM_SYSTEM="$SYSTEM/system/system_ext"
    SYSTEM_APP="$SYSTEM/system/system_ext/app"
    SYSTEM_PRIV_APP="$SYSTEM/system/system_ext/priv-app"
  fi
}

common_module_layout() {
  if [ "$supported_module_config" = "true" ]; then
    SYSTEM_SYSTEM="$SYSTEM/system"
    SYSTEM_APP="$SYSTEM/system/app"
    SYSTEM_PRIV_APP="$SYSTEM/system/priv-app"
    SYSTEM_ETC="$SYSTEM/system/etc"
    SYSTEM_ETC_CONFIG="$SYSTEM/system/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/system/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/system/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/system/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/system/framework"
    SYSTEM_OVERLAY="$SYSTEM/system/product/overlay"
  fi
}

pre_installed_v25() {
  rm -rf $SYSTEM_APP/*NLP*
  rm -rf $SYSTEM_APP/FossDroid
  rm -rf $SYSTEM_PRIV_APP/DroidGuard
  rm -rf $SYSTEM_PRIV_APP/Extension
  rm -rf $SYSTEM_PRIV_APP/MicroG*
  rm -rf $SYSTEM_PRIV_APP/Phonesky
  rm -rf $SYSTEM_ETC_CONFIG/microg.xml
  rm -rf $SYSTEM_ETC_DEFAULT/default-permissions.xml
  rm -rf $SYSTEM_ETC_PERM/privapp-permissions-microg.xml
  rm -rf $SYSTEM_OVERLAY/PlayStoreOverlay.apk
  rm -rf $SYSTEM_ADDOND/70-microg.sh
  rm -rf $SYSTEM/etc/module/module.prop
}

pkg_TMPSys() {
  file_list="$(find "$TMP_SYS/" -mindepth 1 -type f | cut -d/ ${DEST})"
  dir_list="$(find "$TMP_SYS/" -mindepth 1 -type d | cut -d/ ${DEST})"
  for file in $file_list; do
    install -D "$TMP_SYS/${file}" "$SYSTEM_APP/${file}"
    chmod 0644 "$SYSTEM_APP/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_APP/${dir}"
  done
}

pkg_TMPPriv() {
  file_list="$(find "$TMP_PRIV/" -mindepth 1 -type f | cut -d/ ${DEST})"
  dir_list="$(find "$TMP_PRIV/" -mindepth 1 -type d | cut -d/ ${DEST})"
  for file in $file_list; do
    install -D "$TMP_PRIV/${file}" "$SYSTEM_PRIV_APP/${file}"
    chmod 0644 "$SYSTEM_PRIV_APP/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_PRIV_APP/${dir}"
  done
}

pkg_TMPSetup() {
  file_list="$(find "$TMP_PRIV_SETUP/" -mindepth 1 -type f | cut -d/ ${DEST})"
  dir_list="$(find "$TMP_PRIV_SETUP/" -mindepth 1 -type d | cut -d/ ${DEST})"
  for file in $file_list; do
    install -D "$TMP_PRIV_SETUP/${file}" "$SYSTEM_PRIV_APP/${file}"
    chmod 0644 "$SYSTEM_PRIV_APP/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_PRIV_APP/${dir}"
  done
}

pkg_TMPFramework() {
  file_list="$(find "$TMP_FRAMEWORK/" -mindepth 1 -type f | cut -d/ ${DEST})"
  dir_list="$(find "$TMP_FRAMEWORK/" -mindepth 1 -type d | cut -d/ ${DEST})"
  for file in $file_list; do
    install -D "$TMP_FRAMEWORK/${file}" "$SYSTEM_FRAMEWORK/${file}"
    chmod 0644 "$SYSTEM_FRAMEWORK/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_FRAMEWORK/${dir}"
  done
}

pkg_TMPConfig() {
  file_list="$(find "$TMP_SYSCONFIG/" -mindepth 1 -type f | cut -d/ ${DEST})"
  dir_list="$(find "$TMP_SYSCONFIG/" -mindepth 1 -type d | cut -d/ ${DEST})"
  for file in $file_list; do
    install -D "$TMP_SYSCONFIG/${file}" "$SYSTEM_ETC_CONFIG/${file}"
    chmod 0644 "$SYSTEM_ETC_CONFIG/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_ETC_CONFIG/${dir}"
  done
}

pkg_TMPDefault() {
  file_list="$(find "$TMP_DEFAULT/" -mindepth 1 -type f | cut -d/ ${DEST})"
  dir_list="$(find "$TMP_DEFAULT/" -mindepth 1 -type d | cut -d/ ${DEST})"
  for file in $file_list; do
    install -D "$TMP_DEFAULT/${file}" "$SYSTEM_ETC_DEFAULT/${file}"
    chmod 0644 "$SYSTEM_ETC_DEFAULT/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_ETC_DEFAULT/${dir}"
  done
}

pkg_TMPPref() {
  file_list="$(find "$TMP_PREFERRED/" -mindepth 1 -type f | cut -d/ ${DEST})"
  dir_list="$(find "$TMP_PREFERRED/" -mindepth 1 -type d | cut -d/ ${DEST})"
  for file in $file_list; do
    install -D "$TMP_PREFERRED/${file}" "$SYSTEM_ETC_PREF/${file}"
    chmod 0644 "$SYSTEM_ETC_PREF/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_ETC_PREF/${dir}"
  done
}

pkg_TMPPerm() {
  file_list="$(find "$TMP_PERMISSION/" -mindepth 1 -type f | cut -d/ ${DEST})"
  dir_list="$(find "$TMP_PERMISSION/" -mindepth 1 -type d | cut -d/ ${DEST})"
  for file in $file_list; do
    install -D "$TMP_PERMISSION/${file}" "$SYSTEM_ETC_PERM/${file}"
    chmod 0644 "$SYSTEM_ETC_PERM/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_ETC_PERM/${dir}"
  done
}

pkg_TMPOverlay() {
  file_list="$(find "$TMP_OVERLAY/" -mindepth 1 -type f | cut -d/ ${DEST})"
  dir_list="$(find "$TMP_OVERLAY/" -mindepth 1 -type d | cut -d/ ${DEST})"
  for file in $file_list; do
    install -D "$TMP_OVERLAY/${file}" "$SYSTEM_OVERLAY/${file}"
    chmod 0644 "$SYSTEM_OVERLAY/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_OVERLAY/${dir}"
  done
}

is_uninstaller() {
  if [ "$ZIPNAME" = "uninstall" ]; then
    ui_print "- Uninstalling MicroG"
    source $TMP/manager.sh
    # End installation
    on_installed
  fi
}

sdk_v25_install() {
  ui_print "- Installing MicroG"
  ZIP="zip/core/DroidGuard.tar.xz
       zip/core/Extension.tar.xz
       zip/core/MicroGGMSCore.tar.xz
       zip/core/MicroGGSFProxy.tar.xz
       zip/core/Phonesky.tar.xz
       zip/sys/AppleNLPBackend.tar.xz
       zip/sys/DejaVuNLPBackend.tar.xz
       zip/sys/FossDroid.tar.xz
       zip/sys/LocalGSMNLPBackend.tar.xz
       zip/sys/LocalWiFiNLPBackend.tar.xz
       zip/sys/MozillaUnifiedNLPBackend.tar.xz
       zip/sys/NominatimNLPBackend.tar.xz
       zip/Sysconfig.tar.xz
       zip/Default.tar.xz
       zip/Permissions.tar.xz
       zip/overlay/PlayStoreOverlay.tar.xz"
  if [ "$BOOTMODE" = "false" ]; then
    for f in $ZIP; do unzip -oq "$ZIPFILE" "$f" -d "$TMP"; done
  fi
  # Allow unpack, when installation base is Magisk
  if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
    for f in $ZIP; do $(unzip -oq "$ZIPFILE" "$f" -d "$TMP"); done
  fi
  tar -xf $ZIP_FILE/sys/AppleNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/DejaVuNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/FossDroid.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/LocalGSMNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/LocalWiFiNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/MozillaUnifiedNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/NominatimNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/core/DroidGuard.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/Extension.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/MicroGGMSCore.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/MicroGGSFProxy.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/Phonesky.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/Sysconfig.tar.xz -C $TMP_SYSCONFIG
  tar -xf $ZIP_FILE/Default.tar.xz -C $TMP_DEFAULT
  tar -xf $ZIP_FILE/Permissions.tar.xz -C $TMP_PERMISSION
  tar -xf $ZIP_FILE/overlay/PlayStoreOverlay.tar.xz -C $TMP_OVERLAY 2>/dev/null
  pkg_TMPSys
  pkg_TMPPriv
  pkg_TMPConfig
  pkg_TMPDefault
  pkg_TMPPerm
  pkg_TMPOverlay
}

maps_config() {
  ZIP="zip/framework/MapsPermissions.tar.xz"
  if [ "$BOOTMODE" = "false" ]; then
    for f in $ZIP; do unzip -oq "$ZIPFILE" "$f" -d "$TMP"; done
  fi
  # Allow unpack, when installation base is Magisk
  if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
    for f in $ZIP; do $(unzip -oq "$ZIPFILE" "$f" -d "$TMP"); done
  fi
  tar -xf $ZIP_FILE/framework/MapsPermissions.tar.xz -C $TMP_PERMISSION
  pkg_TMPPerm
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM/com.google.android.maps.xml"
}

maps_framework() {
  ZIP="zip/framework/MapsFramework.tar.xz"
  if [ "$BOOTMODE" = "false" ]; then
    for f in $ZIP; do unzip -oq "$ZIPFILE" "$f" -d "$TMP"; done
  fi
  # Allow unpack, when installation base is Magisk
  if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
    for f in $ZIP; do $(unzip -oq "$ZIPFILE" "$f" -d "$TMP"); done
  fi
  tar -xf $ZIP_FILE/framework/MapsFramework.tar.xz -C $TMP_FRAMEWORK
  pkg_TMPFramework
  chcon -h u:object_r:system_file:s0 "$SYSTEM_FRAMEWORK/com.google.android.maps.jar"
}

backup_script() {
  if [ -d "$SYSTEM_ADDOND" ] && [ "$supported_module_config" = "false" ]; then
    ui_print "- Installing OTA survival script"
    ADDOND="70-microg.sh"
    if [ "$BOOTMODE" = "false" ]; then
      unzip -oq "$ZIPFILE" "$ADDOND" -d "$TMP"
    fi
    # Allow unpack, when installation base is Magisk
    if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
      $(unzip -oq "$ZIPFILE" "$ADDOND" -d "$TMP")
    fi
    # Install OTA survival script
    rm -rf $SYSTEM_ADDOND/$ADDOND
    cp -f $TMP/$ADDOND $SYSTEM_ADDOND/$ADDOND
    chmod 0755 $SYSTEM_ADDOND/$ADDOND
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ADDOND/$ADDOND"
  fi
}

fsverity_cert() {
  FSVERITY="$SYSTEM/etc/security/fsverity"
  test -d "$FSVERITY" || return 255
  if [ "$BOOTMODE" = "false" ]; then
    unzip -oq "$ZIPFILE" "zip/Certificate.tar.xz" -d "$TMP"
  fi
  # Allow unpack, when installation base is Magisk
  if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
    $(unzip -oq "$ZIPFILE" "zip/Certificate.tar.xz" -d "$TMP")
  fi
  # Integrity Signing Certificate
  tar -xf $ZIP_FILE/Certificate.tar.xz -C "$FSVERITY"
  chmod 0644 $FSVERITY/gms_fsverity_cert.der
  chmod 0644 $FSVERITY/play_store_fsi_cert.der
  ch_con system "$FSVERITY/gms_fsverity_cert.der"
  ch_con system "$FSVERITY/play_store_fsi_cert.der"
}

get_flags() {
  DATA="false"
  DATA_DE="false"
  if grep ' /data ' /proc/mounts | grep -vq 'tmpfs'; then
    # Data is writable
    touch /data/.rw && rm /data/.rw && DATA="true"
    # Data is decrypted
    if $DATA && [ -d "/data/system" ]; then
      touch /data/system/.rw && rm /data/system/.rw && DATA_DE="true"
    fi
  fi
  if [ -z $KEEPFORCEENCRYPT ]; then
    # No data access means unable to decrypt in recovery
    if { ! $DATA && ! $DATA_DE; }; then
      KEEPFORCEENCRYPT="true"
    else
      KEEPFORCEENCRYPT="false"
    fi
  fi
  if [ "$KEEPFORCEENCRYPT" = "true" ]; then
    on_abort "! Encrypted data partition"
  fi
}

is_encrypted_data() {
  case $supported_module_config in
    "true" )
      ui_print "- Systemless installation"
      get_flags
      ;;
    "false" )
      return 0
      ;;
  esac
}

require_new_magisk() {
  if [ "$supported_module_config" = "true" ]; then
    if [ ! -f "/data/adb/magisk/util_functions.sh" ]; then
      on_abort "! Please install Magisk v20.4+"
    fi
    # Do not source utility functions
    if [ -f "/data/adb/magisk/util_functions.sh" ]; then
      UF="/data/adb/magisk/util_functions.sh"
      grep -w 'MAGISK_VER_CODE' $UF >> $TMP/VER_CODE
      chmod 0755 $TMP/VER_CODE && . $TMP/VER_CODE
      if [ "$MAGISK_VER_CODE" -lt "20400" ]; then
        on_abort "! Please install Magisk v20.4+"
      fi
    fi
    # Magisk Require Additional Setup
    if [ ! -d "/data/adb/modules" ]; then
      on_abort "! Please install Magisk v20.4+"
    fi
  fi
}

is_magic_mount() {
  # Set config defaults
  CONFIG="/data/adb/modules/MicroG/config"
  IS_SL="$(grep -wos 'MODULE' $CONFIG)"
  # Do not proceed without config
  test -f "$CONFIG" || return 255
  [ "$IS_SL" ] && IS_SL="true"
  [ -n "$IS_SL" ] || return 255
  # Handle essential components
  $supported_module_config && return 255
  if [ "$IS_SL" = "true" ]; then
    on_abort "! Systemlessly Installed"
  fi
}

is_bitgapps_module() {
  # Set config defaults
  CONFIG="/data/adb/modules/BiTGApps/config"
  IS_BITGAPPS="$(grep -wos 'BITGAPPS' $CONFIG)"
  # Do not proceed without config
  test -f "$CONFIG" || return 255
  [ "$IS_BITGAPPS" ] && IS_BITGAPPS="true"
  [ -n "$IS_BITGAPPS" ] || return 255
  # Do not proceed with SetupWizard installed
  IS_WIZARD="$(grep -wos 'WIZARD' $CONFIG)"
  [ "$IS_WIZARD" ] && IS_WIZARD="true"
  if [ -n "$IS_WIZARD" ]; then
    on_abort "! SetupWizard Installed"
  fi
  # Override systemless installation
  rm -rf /data/adb/modules/BiTGApps
  # Override system based installation
  for i in FaceLock* GoogleC*; do
    rm -rf $SYSTEM_APP/$i 2>/dev/null
  done
  for i in Config* *Gms* GoogleL* GoogleS* Phonesky; do
    rm -rf $SYSTEM_PRIV_APP/$i 2>/dev/null
  done
  rm -rf $SYSTEM_ETC_CONFIG/google*.xml
  rm -rf $SYSTEM_ETC_DEFAULT/default-permissions.xml
  rm -rf $SYSTEM_ETC_DEFAULT/gapps-permissions.xml
  rm -rf $SYSTEM_ETC_PERM/*google.xml
  rm -rf $SYSTEM_FRAMEWORK/*google*
  rm -rf $SYSTEM_OVERLAY/PlayStoreOverlay.apk
  # Purge OTA survival script
  rm -rf $SYSTEM_ADDOND/70-bitgapps.sh
  # Remove application data
  rm -rf /data/app/com.android.vending*
  rm -rf /data/app/com.google.android*
  rm -rf /data/app/*/com.android.vending*
  rm -rf /data/app/*/com.google.android*
  rm -rf /data/data/com.android.vending*
  rm -rf /data/data/com.google.android*
  # Purge runtime permissions
  rm -rf $(find /data -type f -iname "runtime-permissions.xml")
}

set_bitgapps_module() {
  # Required for System installation
  $IS_MAGISK_MODULES || return 255
  # Cannot Handle Magic Mount
  is_magic_mount
  # Override previous module
  is_bitgapps_module
  # Always override previous installation
  rm -rf /data/adb/modules/MicroG
  mkdir /data/adb/modules/MicroG
  chmod 0755 /data/adb/modules/MicroG
}

set_module_layout() {
  if [ "$supported_module_config" = "true" ]; then
    SYSTEM="/data/adb/modules/MicroG"
    # Override update information
    rm -rf $SYSTEM/module.prop
    # Dump config information
    echo "MICROG" >> $SYSTEM/config
    echo "MODULE" >> $SYSTEM/config
  fi
  if [ "$supported_module_config" = "false" ]; then
    MODULE="/data/adb/modules/MicroG"
    # Override update information
    rm -rf $MODULE/module.prop
    # Required for System installation
    $IS_MAGISK_MODULES || return 255
    # Dump config information
    echo "MICROG" >> $MODULE/config
    echo "SYSTEM" >> $MODULE/config
  fi
}

fix_gms_hide() {
  if [ "$supported_module_config" = "true" ]; then
    for i in MicroGGMSCore; do
      rm -rf $SYSTEM_AS_SYSTEM/priv-app/$i
      cp -fR $SYSTEM_SYSTEM/priv-app/$i $SYSTEM_AS_SYSTEM/priv-app/$i
    done
  fi
}

fix_module_perm() {
  if [ "$supported_module_config" = "true" ]; then
    for i in $SYSTEM_APP $SYSTEM_PRIV_APP; do
      (chmod 0755 $i/*) 2>/dev/null
      (chmod 0644 $i/*/.replace) 2>/dev/null
    done
    chmod 0644 $SYSTEM_ETC_DEFAULT/* 2>/dev/null
    chmod 0644 $SYSTEM_ETC_PERM/* 2>/dev/null
    chmod 0644 $SYSTEM_ETC_PREF/* 2>/dev/null
    chmod 0644 $SYSTEM_ETC_CONFIG/* 2>/dev/null
  fi
}

module_info() {
  if [ "$supported_module_config" = "true" ]; then
    echo -e "id=MicroG-Android" >> $SYSTEM/module.prop
    echo -e "name=MicroG for Android" >> $SYSTEM/module.prop
    echo -e "version=$version" >> $SYSTEM/module.prop
    echo -e "versionCode=$versionCode" >> $SYSTEM/module.prop
    echo -e "author=TheHitMan7" >> $SYSTEM/module.prop
    echo -e "description=Custom MicroG Apps Project" >> $SYSTEM/module.prop
    echo -e "updateJson=${MODULE_URL}/${MODULE_JSN}" >> $SYSTEM/module.prop
    # Set permission
    chmod 0644 $SYSTEM/module.prop
  fi
}

system_info() {
  local IS_MAGISK_MODULES="true" && local MODULE="$SYSTEM/etc/module"
  if [ "$supported_module_config" = "false" ] && $IS_MAGISK_MODULES; then
    echo -e "id=MicroG-Android" >> $MODULE/module.prop
    echo -e "name=MicroG for Android" >> $MODULE/module.prop
    echo -e "version=$version" >> $MODULE/module.prop
    echo -e "versionCode=$versionCode" >> $MODULE/module.prop
    echo -e "author=TheHitMan7" >> $MODULE/module.prop
    echo -e "description=Custom MicroG Apps Project" >> $MODULE/module.prop
    echo -e "updateJson=${MODULE_URL}/${MODULE_JSN}" >> $MODULE/module.prop
    # Set permission
    chmod 0644 $MODULE/module.prop
  fi
}

permissions() {
  if [ -d "/data/adb/service.d" ]; then
    if [ "$BOOTMODE" == "false" ]; then
      unzip -oq "$ZIPFILE" "runtime.sh" -d "$TMP"
    fi
    # Allow unpack, when installation base is Magisk
    if [[ "$(getprop "sys.bootmode")" == "2" ]]; then
      $(unzip -oq "$ZIPFILE" "runtime.sh" -d "$TMP")
    fi
    # Install runtime permissions
    rm -rf /data/adb/service.d/runtime.sh
    cp -f $TMP/runtime.sh /data/adb/service.d/runtime.sh
    chmod 0755 /data/adb/service.d/runtime.sh
    chcon -h u:object_r:adb_data_file:s0 "/data/adb/service.d/runtime.sh"
    # Update file GROUP
    chown -h root:shell /data/adb/service.d/runtime.sh
  fi
}

module_probe() {
  if [ "$supported_module_config" = "true" ] && [ -d "/data/adb/service.d" ]; then
    if [ "$BOOTMODE" = "false" ]; then
      unzip -oq "$ZIPFILE" "module.sh" -d "$TMP"
    fi
    # Allow unpack, when installation base is Magisk
    if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
      $(unzip -oq "$ZIPFILE" "module.sh" -d "$TMP")
    fi
    # Install module service
    rm -rf /data/adb/service.d/module.sh
    cp -f $TMP/module.sh /data/adb/service.d/module.sh
    chmod 0755 /data/adb/service.d/module.sh
    chcon -h u:object_r:adb_data_file:s0 "/data/adb/service.d/module.sh"
    # Update file GROUP
    chown -h root:shell /data/adb/service.d/module.sh
  fi
}

module_service() {
  if [ "$supported_module_config" = "true" ] && [ -d "/data/adb/post-fs-data.d" ]; then
    if [ "$BOOTMODE" = "false" ]; then
      unzip -oq "$ZIPFILE" "service.sh" -d "$TMP"
    fi
    # Allow unpack, when installation base is Magisk
    if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
      $(unzip -oq "$ZIPFILE" "service.sh" -d "$TMP")
    fi
    # Install module service
    rm -rf /data/adb/post-fs-data.d/service.sh
    cp -f $TMP/service.sh /data/adb/post-fs-data.d/service.sh
    chmod 0755 /data/adb/post-fs-data.d/service.sh
    chcon -h u:object_r:adb_data_file:s0 "/data/adb/post-fs-data.d/service.sh"
    # Update file GROUP
    chown -h root:shell /data/adb/post-fs-data.d/service.sh
  fi
}

module_cleanup() {
  local MODULEROOT="/data/adb/modules/MicroG"
  if [ -d "/data/adb/modules/MicroG" ]; then
    if [ "$BOOTMODE" = "false" ]; then
      unzip -oq "$ZIPFILE" "uninstall.sh" -d "$TMP"
    fi
    # Allow unpack, when installation base is Magisk
    if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
      $(unzip -oq "$ZIPFILE" "uninstall.sh" -d "$TMP")
    fi
    # Module uninstall script
    rm -rf $MODULEROOT/uninstall.sh
    cp -f $TMP/uninstall.sh $MODULEROOT/uninstall.sh
    chmod 0755 $MODULEROOT/uninstall.sh
    chcon -h u:object_r:system_file:s0 "$MODULEROOT/uninstall.sh"
  fi
}

pre_install() {
  umount_all
  recovery_actions
  on_partition_check
  ab_partition
  system_as_root
  super_partition
  mount_all
  mount_apex
  sideload_config
  get_bitgapps_config
  profile
  RTP_cleanup
  on_systemless_check
}

df_partition() {
  # Get the available space left on the device
  size=`df -k /system | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
  # Disk space in human readable format (k=1024)
  ds_hr=`df -h /system | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
  # Common target
  CAPACITY="$CAPACITY"
  # Print partition type
  partition="System"
}

df_checker() {
  if [ "$ZIPNAME" = "uninstall" ]; then
    return 255
  fi
  if [ "$size" -gt "$CAPACITY" ]; then
    ui_print "- ${partition} Space: $ds_hr"
  else
    ui_print "! Insufficient partition size"
    on_abort "! Current space: $ds_hr"
  fi
}

post_install() {
  df_partition
  df_checker
  build_defaults
  mk_component
  system_layout
  ${is_encrypted_data}
  ${is_uninstaller}
  ${require_new_magisk}
  ${set_bitgapps_module}
  ${set_module_layout}
  ${system_module_layout}
  ${make_module_layout}
  ${product_module_layout}
  ${make_module_layout}
  ${system_ext_module_layout}
  ${make_module_layout}
  ${common_module_layout}
  pre_installed_v25
  sdk_v25_install
  fsverity_cert
  backup_script
  ${fix_gms_hide}
  ${fix_module_perm}
  maps_config
  maps_framework
  ${module_info}
  system_info
  permissions
  ${module_probe}
  ${module_service}
  ${module_cleanup}
  on_installed
}

# Begin installation
{
  pre_install
  post_install
}
# End installation

# End method
