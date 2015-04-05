#!/bin/bash

: ${ANDROID_ROOT?"'ANDROID_ROOT not set"}

WORK_DIR="$HOME/scripts/sailfishBuildUtils"
BACKUP_DIR="$WORK_DIR/backups"
SCRIPT_NAME=`basename "$0"`
SCRIPT_BACKUPS="$BACKUP_DIR/$SCRIPT_NAME"
SCRIPT_BACKUPS=${SCRIPT_BACKUPS%.sh}

mkdir -p "$SCRIPT_BACKUPS"

CYAN_KERNEL_CONFIG="kernel/oneplus/msm8974/arch/arm/configs/cyanogenmod_bacon_defconfig"
KERNEL_CHECK_SCRIPT="hybris/mer-kernel-check/mer_verify_kernel_config"
TMP_WORKDIR=`mktemp -d "/tmp/sailfishKernelCheck.XXXXX"`
TMP_KERNEL_CHECK="$TMP_WORKDIR/kernelCheck"
TMP_ADDED_CONFIG="$TMP_WORKDIR/addedConfig"
BACKUP_KERNEL_CONFIG="$SCRIPT_BACKUPS/cyanogenmod_bacon_defconfig."`date +"%Y%m%d_%H%M%S"`
CUR_DIR=`pwd`
TMP_KERNEL_CONFIG="$TMP_WORKDIR/"`basename "$CYAN_KERNEL_CONFIG"`
NEW_KERNEL_CONFIG="$BACKUP_KERNEL_CONFIG.new"

function checkConfig() {
	$KERNEL_CHECK_SCRIPT $CYAN_KERNEL_CONFIG | grep -A2 'ERROR\|WARNING' > $TMP_KERNEL_CHECK
}

function genUnsetConfigs() {
	echo -e "\n## Sailfish Added Configs" > $TMP_ADDED_CONFIG
	cat $TMP_KERNEL_CHECK | grep -B1 -A1 'It is unset' | awk -F':' '{print $2}' | awk '{print $1}' | grep -v '^$' | awk -F',' '{ORS="="; print $1; getline; ORS="\n"; print $1}' >> $TMP_ADDED_CONFIG
	cat $TMP_ADDED_CONFIG | awk '{print "\t+ "$0}'
}

function genCorrectedConfigs() {
	sed_params=`cat $TMP_KERNEL_CHECK | grep -B1 -A1 'Value is:' | grep -v 'Value is:' | awk -F': ' '{print $2}' | grep -v '^$' | awk '{print $1}' |awk -F',' '{ORS=""; print "s/\\\("$1"\\\)=.*/\\\1="; getline; ORS=";"; print $1"/g"}'`
	sed "$sed_params" $BACKUP_KERNEL_CONFIG
}


pushd $ANDROID_ROOT
	echo "Backing up current Kernel config..."
	echo -e "\t - $BACKUP_KERNEL_CONFIG"
	cp -af $CYAN_KERNEL_CONFIG $BACKUP_KERNEL_CONFIG
	echo ""

	echo "Running Kernel Config Check..."
	checkConfig
	echo ""

	echo "Correcting incorrect Configs..."
	genCorrectedConfigs > $NEW_KERNEL_CONFIG
	echo ""

	echo "Setting Unset Configs..."
	genUnsetConfigs
	cat $TMP_ADDED_CONFIG >> $NEW_KERNEL_CONFIG
	echo ""
popd

rm -rvf $TMP_WORKDIR
