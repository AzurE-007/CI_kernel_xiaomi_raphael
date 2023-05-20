#!/bin/bash

set -e

# Working Directory 
WORKING_DIR=$(pwd)

# Module Directory
MODULE_DIR=/out/modules

# Functions For Telegram Post
msg() {
	curl -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage?chat_id=$TG_CHAT_ID \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

file() {
	MD5=$(md5sum "$1" | cut -d' ' -f1)
	curl -F document=@"$1" https://api.telegram.org/bot$BOT_TOKEN/sendDocument?chat_id=$TG_CHAT_ID \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=Markdown" \
	-F caption="$2 | *MD5 Checksum : *\`$MD5\`"
}

# Cloning Anykernel
git clone --depth=1 https://github.com/back-up-git/AnyKernel3.git -b 1805-modules $WORKING_DIR/Anykernel

# Cloning Kernel
git clone --depth=1 $REPO_LINK -b $BRANCH_NAME $WORKING_DIR/kernel

# Cloning GCC
git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 $WORKING_DIR/gcc32
git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 $WORKING_DIR/gcc64

# Change Directory to the Source Directry
cd $WORKING_DIR/kernel

# Build Info Variables
DEVICE="RMX1805"
DISTRO=$(source /etc/os-release && echo $NAME)
COMPILER=$($WORKING_DIR/gcc64/bin/aarch64-linux-android-gcc --version | head -n 1)
ZIP_NAME=RMX1805-$(TZ=Asia/Kolkata date +%Y%m%d-%H%M).zip

#Starting Compilation
BUILD_START=$(date +"%s")
msg "<b>$BUILD_ID CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Date : </b><code>$(TZ=Asia/Kolkata date)</code>%0A<b>Device : </b><code>$DEVICE</code>%0A<b>Compiler : </b><code>$COMPILER</code>%0A<b>Branch: </b><code>$BRANCH_NAME</code>"
export KBUILD_BUILD_USER="AB"
export KBUILD_BUILD_HOST="Server"
export ARCH=arm64
export SUBARCH=arm64

export PATH=$WORKING_DIR/gcc64/bin:$WORKING_DIR/gcc32/bin:/usr/bin:$PATH
mkdir -p out
make O=out clean
make O=out mrproper
make O=out MSM_18355_msm8953-perf_defconfig
BUILD_START=$(date +"%s")
make -j$(nproc --all) O=out \
      CC="ccache $WORKING_DIR/gcc64/bin/aarch64-linux-android-gcc" \
      CROSS_COMPILE=aarch64-linux-android- \
      CROSS_COMPILE_ARM32=arm-linux-androideabi- \
      2>&1 | tee out/error.txt
      
	echo "Making modules..."
	make O=out ARCH=arm64 INSTALL_MOD_PATH=$MODULE_DIR INSTALL_MOD_STRIP=1 modules_install || exit
	echo "Done."

BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

#Zipping & Uploading Flashable Kernel Zip
if [ -e out/arch/arm64/boot/Image.gz-dtb ]; then
cp out/arch/arm64/boot/Image.gz-dtb $WORKING_DIR/Anykernel
cp out/modules/"*.ko" $WORKING_DIR/Anykernel/modules/system/lib/modules
cd $WORKING_DIR/Anykernel
zip -r9 $ZIP_NAME * -x .git README.md *placeholder
file "$ZIP_NAME" "*Build Completed :* $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
else
file "$WORKING_DIR/kernel/out/error.txt" "*Build Failed :* $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
fi
