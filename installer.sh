# This file is part of The BiTGApps Project

# GITHUB RAW URL
MODULE_URL='https://raw.githubusercontent.com'

# Module JSON URL
MODULE_JSN='BiTGApps/BiTGApps-Module/master/all/module.json'

# Required for System installation
IS_MAGISK_MODULES="false" && [ -d "/data/adb/modules" ] && IS_MAGISK_MODULES="true"

# Allow mounting, when installation base is Magisk
if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
  # Mount partitions
  mount -o remount,rw,errors=continue / > /dev/null 2>&1
  mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
  mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
  mount -o remount,rw,errors=continue /system > /dev/null 2>&1
  mount -o remount,rw,errors=continue /product > /dev/null 2>&1
  mount -o remount,rw,errors=continue /system_ext > /dev/null 2>&1
  # Set installation layout
  SYSTEM="/system"
  # Backup installation layout
  SYSTEM_AS_SYSTEM="$SYSTEM"
  # System is writable
  if ! touch $SYSTEM/.rw >/dev/null 2>&1; then
    echo "! Read-only file system"
    exit 1
  fi
fi

# Product is a dedicated partition
case "$(getprop "sys.bootmode")" in
  "2" )
    if grep -q " $(readlink -f /product) " /proc/mounts; then
      ln -sf /product /system
    fi
    ;;
esac

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
  unzip -o "$ZIPFILE" "util_functions.sh" -d "$TMP" 2>/dev/null
fi
# Allow unpack, when installation base is Magisk
if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
  $(unzip -o "$ZIPFILE" "util_functions.sh" -d "$TMP" >/dev/null 2>&1)
fi
chmod +x "$TMP/util_functions.sh"

# Load utility functions
. $TMP/util_functions.sh

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
  # Create links
  UNZIP_DIR="$TMP/unzip"
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
  test -d "$SYSTEM/apex" || return 1
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
        unzip -qo $apex original_apex -d /apex
        if [ -f "/apex/original_apex" ]; then
          apex="/apex/original_apex"
        fi
        # Handle APEX APKs
        unzip -qo $apex apex_payload.img -d /apex
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
    umount -l /system_root > /dev/null 2>&1
    umount -l /system > /dev/null 2>&1
    umount -l /product > /dev/null 2>&1
    umount -l /system_ext > /dev/null 2>&1
  fi
}

mount_all() {
  if "$BOOTMODE"; then
    return 255
  fi
  mount -o bind /dev/urandom /dev/random
  [ "$ANDROID_ROOT" ] || ANDROID_ROOT="/system"
  setup_mountpoint $ANDROID_ROOT
  if ! is_mounted /data; then
    mount /data
    if [ -z "$(ls -A /sdcard)" ]; then
      mount -o bind /data/media/0 /sdcard
    fi
  fi
  $SYSTEM_ROOT && ui_print "- Device is system-as-root"
  $SUPER_PARTITION && ui_print "- Super partition detected"
  # Set recovery fstab
  [ -f "/etc/fstab" ] && cp -f '/etc/fstab' $TMP && fstab="/tmp/fstab"
  [ -f "/system/etc/fstab" ] && cp -f '/system/etc/fstab' $TMP && fstab="/tmp/fstab"
  # Check A/B slot
  [ "$slot" ] || slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
  [ "$slot" ] || slot=`grep_cmdline androidboot.slot_suffix`
  [ "$slot" ] || slot=`grep_cmdline androidboot.slot`
  [ "$slot" ] && ui_print "- Current boot slot: $slot"
  if [ "$SUPER_PARTITION" = "true" ] && [ "$device_abpartition" = "true" ]; then
    unset ANDROID_ROOT && ANDROID_ROOT="/system_root" && setup_mountpoint $ANDROID_ROOT
    for block in system product system_ext; do
      for slot in "" _a _b; do
        blockdev --setrw /dev/block/mapper/$block$slot > /dev/null 2>&1
      done
    done
    ui_print "- Mounting /system"
    mount -o ro -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
    mount -o rw,remount -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
    if ! is_mounted $ANDROID_ROOT; then
      if [ "$(grep -w -o '/system_root' $fstab)" ]; then
        BLOCK=`grep -v '#' $fstab | grep -E '/system_root' | grep -oE '/dev/block/dm-[0-9]' | head -n 1`
      fi
      if [ "$(grep -w -o '/system' $fstab)" ]; then
        BLOCK=`grep -v '#' $fstab | grep -E '/system' | grep -oE '/dev/block/dm-[0-9]' | head -n 1`
      fi
      mount -o ro -t auto $BLOCK $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto $BLOCK $ANDROID_ROOT > /dev/null 2>&1
    fi
    is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT"
    if [ "$(grep -w -o '/product' $fstab)" ]; then
      ui_print "- Mounting /product"
      mount -o ro -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
      if ! is_mounted /product; then
        BLOCK=`grep -v '#' $fstab | grep -E '/product' | grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        mount -o ro -t auto $BLOCK /product > /dev/null 2>&1
        mount -o rw,remount -t auto $BLOCK /product > /dev/null 2>&1
      fi
    fi
    if [ "$(grep -w -o '/system_ext' $fstab)" ]; then
      ui_print "- Mounting /system_ext"
      mount -o ro -t auto /dev/block/mapper/product$slot /system_ext > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/product$slot /system_ext > /dev/null 2>&1
      if ! is_mounted /system_ext; then
        BLOCK=`grep -v '#' $fstab | grep -E '/system_ext' | grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        mount -o ro -t auto $BLOCK /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto $BLOCK /system_ext > /dev/null 2>&1
      fi
    fi
  fi
  if [ "$SUPER_PARTITION" = "true" ] && [ "$device_abpartition" = "false" ]; then
    unset ANDROID_ROOT && ANDROID_ROOT="/system_root" && setup_mountpoint $ANDROID_ROOT
    for block in system product system_ext; do
      blockdev --setrw /dev/block/mapper/$block > /dev/null 2>&1
    done
    ui_print "- Mounting /system"
    mount -o ro -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
    mount -o rw,remount -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
    is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT"
    if [ "$(grep -w -o '/product' $fstab)" ]; then
      ui_print "- Mounting /product"
      mount -o ro -t auto /dev/block/mapper/product /product > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/product /product > /dev/null 2>&1
    fi
    if [ "$(grep -w -o '/system_ext' $fstab)" ]; then
      ui_print "- Mounting /system_ext"
      mount -o ro -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
    fi
  fi
  if [ "$SUPER_PARTITION" = "false" ] && [ "$device_abpartition" = "false" ]; then
    ui_print "- Mounting /system"
    mount -o ro -t auto $ANDROID_ROOT > /dev/null 2>&1
    mount -o rw,remount -t auto $ANDROID_ROOT > /dev/null 2>&1
    if ! is_mounted $ANDROID_ROOT; then
      if [ -e "/dev/block/by-name/system" ]; then
        BLOCK="/dev/block/by-name/system"
      elif [ -e "/dev/block/bootdevice/by-name/system" ]; then
        BLOCK="/dev/block/bootdevice/by-name/system"
      elif [ -e "/dev/block/platform/*/by-name/system" ]; then
        BLOCK="/dev/block/platform/*/by-name/system"
      else
        BLOCK="/dev/block/platform/*/*/by-name/system"
      fi
      # Do not proceed without system block
      [ -z "$BLOCK" ] && on_abort "! Cannot find system block"
      # Mount using block device
      mount $BLOCK $ANDROID_ROOT > /dev/null 2>&1
    fi
    is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT"
    if [ "$(grep -w -o '/product' $fstab)" ]; then
      ui_print "- Mounting /product"
      mount -o ro -t auto /product > /dev/null 2>&1
      mount -o rw,remount -t auto /product > /dev/null 2>&1
    fi
  fi
  if [ "$SUPER_PARTITION" = "false" ] && [ "$device_abpartition" = "true" ]; then
    ui_print "- Mounting /system"
    mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
    mount -o rw,remount -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
    is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT"
    if [ "$(grep -w -o '/product' $fstab)" ]; then
      ui_print "- Mounting /product"
      mount -o ro -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
    fi
  fi
  # Mount bind operation
  case $ANDROID_ROOT in
    /system_root) setup_mountpoint /system;;
    /system)
      if [ -f "/system/system/build.prop" ]; then
        setup_mountpoint /system_root
        mount --move /system /system_root
        mount -o bind /system_root/system /system
      fi
    ;;
  esac
  if is_mounted /system_root; then
    if [ -f "/system_root/build.prop" ]; then
      mount -o bind /system_root /system
    else
      mount -o bind /system_root/system /system
    fi
  fi
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
}

unmount_all() {
  if [ "$BOOTMODE" = "false" ]; then
    ui_print "- Unmounting partitions"
    umount_apex
    if [ "$(grep -w -o '/system_root' $fstab)" ]; then
      umount -l /system_root > /dev/null 2>&1
    fi
    if [ "$(grep -w -o '/system' $fstab)" ]; then
      umount -l /system > /dev/null 2>&1
    fi
    umount -l /system_root > /dev/null 2>&1
    umount -l /system > /dev/null 2>&1
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
  unmount_all
  recovery_cleanup
  f_cleanup
  d_cleanup
  ui_print "! Installation failed"
  ui_print " "
  true
  sync
  exit 1
}

on_installed() {
  unmount_all
  recovery_cleanup
  f_cleanup
  d_cleanup
  ui_print "- Installation complete"
  ui_print " "
  true
  sync
  exit "$?"
}

sideload_config() {
  if [ "$BOOTMODE" = "false" ]; then
    unzip -o "$ZIPFILE" "bitgapps-config.prop" -d "$TMP" 2>/dev/null
  fi
  # Allow unpack, when installation base is Magisk
  if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
    $(unzip -o "$ZIPFILE" "bitgapps-config.prop" -d "$TMP" >/dev/null 2>&1)
  fi
}

get_bitgapps_config() {
  for d in /sdcard /sdcard1 /external_sd /usb_otg /usbstorage /data/media/0 /tmp; do
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
  fi
}

on_setup_check() {
  supported_setup_config="false"
  if [ -f "$BITGAPPS_CONFIG" ]; then
    supported_setup_config="$(get_prop "ro.config.setupwizard")"
  fi
}

RTP_cleanup() {
  # Did this 6.0+ system already boot and generated runtime permissions
  if [ -e /data/system/users/0/runtime-permissions.xml ]; then
    # Check if permissions were granted to Google Playstore, this permissions should always be set in the file if GApps were installed before
    if ! grep -q "com.android.vending" /data/system/users/*/runtime-permissions.xml; then
      # Purge the runtime permissions to prevent issues if flashing GApps for the first time on a dirty install
      rm -rf /data/system/users/*/runtime-permissions.xml
    fi
  fi
  # Did this 11.0+ system already boot and generated runtime permissions
  RTP="$(find /data -iname "runtime-permissions.xml" 2>/dev/null)"
  if [ -e "$RTP" ]; then
    # Check if permissions were granted to Google Playstore, this permissions should always be set in the file if GApps were installed before
    if ! grep -q "com.android.vending" $RTP; then
      # Purge the runtime permissions to prevent issues if flashing GApps for the first time on a dirty install
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
    D1="$SYSTEM/system"
    D2="$SYSTEM/system/app"
    D3="$SYSTEM/system/priv-app"
    D4="$SYSTEM/system/etc"
    D5="$SYSTEM/system/etc/sysconfig"
    D6="$SYSTEM/system/etc/default-permissions"
    D7="$SYSTEM/system/etc/permissions"
    D8="$SYSTEM/system/etc/preferred-apps"
    D9="$SYSTEM/system/framework"
    for d in $D1 $D2 $D3 $D4 $D5 $D6 $D7 $D8 $D9; do
      install -d "$d" && chmod 0755 "$d"
      chcon -h u:object_r:system_file:s0 "$d"
    done
  fi
}

product_module_layout() {
  if [ "$supported_module_config" = "true" ]; then
    SYSTEM_PRODUCT="$SYSTEM/system/product"
    SYSTEM_OVERLAY="$SYSTEM/system/product/overlay"
    for d in $SYSTEM_PRODUCT $SYSTEM_OVERLAY; do
      install -d "$d" && chmod 0755 "$d"
      chcon -h u:object_r:system_file:s0 "$d"
    done
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
  for i in AppleNLPBackend DejaVuNLPBackend FossDroid LocalGSMNLPBackend LocalWiFiNLPBackend MozillaUnifiedNLPBackend NominatimNLPBackend; do
    rm -rf $SYSTEM_APP/$i
  done
  for i in DroidGuard Extension MicroGGMSCore MicroGGSFProxy Phonesky; do
    rm -rf $SYSTEM_PRIV_APP/$i
  done
  for i in $SYSTEM_ETC_CONFIG/microg.xml $SYSTEM_ETC_DEFAULT/default-permissions.xml $SYSTEM_ETC_PERM/privapp-permissions-microg.xml; do
    rm -rf $i
  done
  rm -rf $SYSTEM_OVERLAY/PlayStoreOverlay
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
    for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  fi
  # Allow unpack, when installation base is Magisk
  if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
    for f in $ZIP; do $(unzip -o "$ZIPFILE" "$f" -d "$TMP" >/dev/null 2>&1); done
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
    for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  fi
  # Allow unpack, when installation base is Magisk
  if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
    for f in $ZIP; do $(unzip -o "$ZIPFILE" "$f" -d "$TMP" >/dev/null 2>&1); done
  fi
  tar -xf $ZIP_FILE/framework/MapsPermissions.tar.xz -C $TMP_PERMISSION
  pkg_TMPPerm
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM/com.google.android.maps.xml"
}

maps_framework() {
  ZIP="zip/framework/MapsFramework.tar.xz"
  if [ "$BOOTMODE" = "false" ]; then
    for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  fi
  # Allow unpack, when installation base is Magisk
  if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
    for f in $ZIP; do $(unzip -o "$ZIPFILE" "$f" -d "$TMP" >/dev/null 2>&1); done
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
      unzip -o "$ZIPFILE" "$ADDOND" -d "$TMP"
    fi
    # Allow unpack, when installation base is Magisk
    if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
      $(unzip -o "$ZIPFILE" "$ADDOND" -d "$TMP" >/dev/null 2>&1)
    fi
    # Install OTA survival script
    rm -rf $SYSTEM_ADDOND/$ADDOND
    cp -f $TMP/$ADDOND $SYSTEM_ADDOND/$ADDOND
    chmod 0755 $SYSTEM_ADDOND/$ADDOND
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ADDOND/$ADDOND"
  fi
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

set_bitgapps_module() {
  case $supported_module_config in
    "false" )
      # Required for System installation
      $IS_MAGISK_MODULES || return 255
      ;;
  esac
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
  fi
  if [ "$supported_module_config" = "false" ]; then
    MODULE="/data/adb/modules/MicroG"
    # Override update information
    rm -rf $MODULE/module.prop
  fi
}

fix_gms_hide() {
  if [ "$supported_module_config" = "true" ]; then
    mount -o remount,rw,errors=continue $SYSTEM_AS_SYSTEM/priv-app/MicroGGMSCore 2>/dev/null
    umount -l $SYSTEM_AS_SYSTEM/priv-app/MicroGGMSCore 2>/dev/null
    rm -rf $SYSTEM_AS_SYSTEM/priv-app/MicroGGMSCore 2>/dev/null
    cp -fR $SYSTEM_SYSTEM/priv-app/MicroGGMSCore $SYSTEM_AS_SYSTEM/priv-app 2>/dev/null
  fi
}

fix_module_perm() {
  if [ "$supported_module_config" = "true" ]; then
    for i in $SYSTEM_APP $SYSTEM_PRIV_APP; do
      (chmod 0755 $i/*) 2>/dev/null
      (chmod 0644 $i/*/.replace) 2>/dev/null
    done
    for i in $SYSTEM_ETC_DEFAULT $SYSTEM_ETC_PERM $SYSTEM_ETC_PREF $SYSTEM_ETC_CONFIG; do
      (chmod 0644 $i/*) 2>/dev/null
    done
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
      unzip -o "$ZIPFILE" "runtime.sh" -d "$TMP"
    fi
    # Allow unpack, when installation base is Magisk
    if [[ "$(getprop "sys.bootmode")" == "2" ]]; then
      $(unzip -o "$ZIPFILE" "runtime.sh" -d "$TMP" >/dev/null 2>&1)
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
      unzip -o "$ZIPFILE" "modprobe.sh" -d "$TMP"
    fi
    # Allow unpack, when installation base is Magisk
    if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
      $(unzip -o "$ZIPFILE" "modprobe.sh" -d "$TMP" >/dev/null 2>&1)
    fi
    # Install module service
    rm -rf /data/adb/service.d/modprobe.sh
    cp -f $TMP/modprobe.sh /data/adb/service.d/modprobe.sh
    chmod 0755 /data/adb/service.d/modprobe.sh
    chcon -h u:object_r:adb_data_file:s0 "/data/adb/service.d/modprobe.sh"
    # Update file GROUP
    chown -h root:shell /data/adb/service.d/modprobe.sh
  fi
}

module_service() {
  if [ "$supported_module_config" = "true" ] && [ -d "/data/adb/post-fs-data.d" ]; then
    if [ "$BOOTMODE" = "false" ]; then
      unzip -o "$ZIPFILE" "service.sh" -d "$TMP"
    fi
    # Allow unpack, when installation base is Magisk
    if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
      $(unzip -o "$ZIPFILE" "service.sh" -d "$TMP" >/dev/null 2>&1)
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
      unzip -o "$ZIPFILE" "uninstall.sh" -d "$TMP"
    fi
    # Allow unpack, when installation base is Magisk
    if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
      $(unzip -o "$ZIPFILE" "uninstall.sh" -d "$TMP" >/dev/null 2>&1)
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
  size=`df -k $ANDROID_ROOT | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
  # Disk space in human readable format (k=1024)
  ds_hr=`df -h $ANDROID_ROOT | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
  # Common target
  CAPACITY="$CAPACITY"
  # Print partition type
  partition="System"
}

df_checker() {
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
  is_encrypted_data
  require_new_magisk
  set_bitgapps_module
  set_module_layout
  system_module_layout
  product_module_layout
  common_module_layout
  pre_installed_v25
  sdk_v25_install
  backup_script
  fix_gms_hide
  fix_module_perm
  maps_config
  maps_framework
  module_info
  system_info
  permissions
  module_probe
  module_service
  module_cleanup
  on_installed
}

# Begin installation
{
  pre_install
  post_install
}
# End installation

# End method