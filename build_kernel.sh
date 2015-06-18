#!/bin/bash
#
# Copyright 2015 Matthew Booth
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Find the absolute path of the kernel source directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  KERNEL_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$KERNEL_DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
KERNEL_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Setup the cross compile
export CROSS_COMPILE=/mnt/Android/Kernels/cr-arm-eabi-4.9.3/bin/arm-eabi-

# Setup the output dir
export OUTPUT_DIR="$KERNEL_DIR"/out

# Architecture
export ARCH=arm

# Number of CPU's available
NUMBEROFCPUS=$(expr `grep processor /proc/cpuinfo | wc -l` + 1);

# Build variant
VARIANT=eur

# Ramdisk location
INITRAMFS="$KERNEL_DIR"/../GE_5.0_Ramdisk

# Distribution folder
DIST="$KERNEL_DIR"/dist

# Kernel filename
FILENAME=JFLTE-GPE_Stock_Kernel.zip


# Ready to build
echo -e "\e[1;91mBuilding JFLTE-GPE stock kernel"
echo -e "\e[0m "

if [ ! -e "$KERNEL_DIR"/out ]; then
	echo -e "\e[1;91mCreating out folder"
	echo -e "\e[0m "
	mkdir "$KERNEL_DIR"/out
fi

echo -e "\e[1;91mRemoving old zImage"
echo -e "\e[0m "
rm "$OUTPUT_DIR"/arch/arm/boot/zImage "$KERNEL_DIR"/arch/arm/boot/zImage

echo -e "\e[1;91mCreating config"
echo -e "\e[0m "
make -j"$NUMBEROFCPUS" -C "$KERNEL_DIR" O="$OUTPUT_DIR" VARIANT_DEFCONFIG=jf_"$VARIANT"_defconfig jf_defconfig SELINUX_DEFCONFIG=selinux_defconfig

echo -e "\e[1;91mBuilding kernel"
echo -e "\e[0m "
make -j"$NUMBEROFCPUS" -C "$KERNEL_DIR" O=$"$OUTPUT_DIR"

if [ -e "$OUTPUT_DIR"/arch/arm/boot/zImage ];then
	echo -e "\e[1;91mPacking kernel into boot.img"
	echo -e "\e[0m "
	cp "$OUTPUT_DIR"/arch/arm/boot/zImage "$DIST"/zImage
	./mkbootfs $INITRAMFS | gzip > $DIST/ramdisk.gz
	./mkbootimg --cmdline 'console=null androidboot.hardware=jgedlte user_debug=23 msm_rtb.filter=0x3F ehci-hcd.park=3 androidboot.bootdevice=msm_sdcc.1 androidboot.selinux=permissive' --kernel "$DIST"/zImage --ramdisk "$DIST"/ramdisk.gz --base 0x80200000 --pagesize 2048 --ramdisk_offset 0x02000000 --output "$DIST"/boot.img
	
	if [ -e "$DIST"/ramdisk.gz ]; then
		rm "$DIST"/ramdisk.gz
	fi;

	if [ -e "$DIST"/zImage ]; then
		rm "$DIST"/zImage
	fi;

	echo -e "\e[1;91mDeleting old modules"
	echo -e "\e[0m "
	rm -rf "$DIST"/modules/*

	echo -e "\e[1;91mCopying new modules"
	echo -e "\e[0m "
	for i in `find $KERNELDIR -name '*.ko'`; do
		cp -av $i "$DIST"/modules/;
	done;

	echo -e "\e[1;91mPacking zip"
	echo -e "\e[0m "
	cd "$DIST"	
	zip -r ../$FILENAME .
	cd "$KERNELDIR"

	echo -e "\e[1;91mDone"
	echo -e "\e[0m "
	exit 0
else
	echo -e "\e[1;91mzImage not found, kernel build failed"
	echo -e "\e[0m "
	exit 1
fi
