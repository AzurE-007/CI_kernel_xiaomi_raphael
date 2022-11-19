#!/bin/bash

set -e

# Working Directory
WORKING_DIR="$(pwd)"

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
git clone --depth=1 https://github.com/back-up-git/AnyKernel3.git -b main $WORKING_DIR/Anykernel

# Cloning Kernel
git clone --depth=1 $REPO_LINK -b $BRANCH_NAME $WORKING_DIR/kernel

# Cloning Toolchain
git clone --depth=1 https://github.com/kdrag0n/proton-clang $WORKING_DIR/clang

# Change Directory to the Source Directry
cd $WORKING_DIR/kernel

# Build Info Variables
DEVICE="RMX_1805"
DISTRO=$(source /etc/os-release && echo $NAME)
COMPILER=GCC
ZIP_NAME=RMX_1805-$(TZ=Asia/Kolkata date +%Y%m%d-%H%M).zip

#Starting Compilation
BUILD_START=$(date +"%s")
msg "<b>$BUILD_ID CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Date : </b><code>$(TZ=Asia/Kolkata date)</code>%0A<b>Device : </b><code>$DEVICE</code>%0A<b>Compiler : </b><code>$COMPILER</code>%0A<b>Branch: </b><code>$BRANCH_NAME</code>"
export KBUILD_BUILD_USER="AB"
export KBUILD_BUILD_HOST="Server"
export ARCH=arm64
export WT_FINAL_RELEASE=yes
export PROJCT="18355"
export PRJ_NAME="MSM_18355"
export PATH=$WORKING_DIR/clang/bin/:/usr/bin:$PATH
make O=out MSM_18355_msm8953-perf_defconfig
make -j$(nproc --all) O=out \
      CROSS_COMPILE=aarch64-linux-gnu- \
      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
      CC=clang \
      AR=llvm-ar \
      OBJDUMP=llvm-objdump \
      STRIP=llvm-strip
      2>&1 | tee out/error.txt
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

#Zipping & Uploading Flashable Kernel Zip
if [ -e out/arch/arm64/boot/Image.gz-dtb ]; then
cp out/arch/arm64/boot/Image.gz-dtb $WORKING_DIR/Anykernel
cd $WORKING_DIR/Anykernel
zip -r9 $ZIP_NAME * -x .git README.md *placeholder
file "$ZIP_NAME" "*Build Completed :* $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
else
file "$WORKING_DIR/kernel/out/error.txt" "*Build Failed :* $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
fi
