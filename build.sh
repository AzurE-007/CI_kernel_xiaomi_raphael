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
git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 --depth=1 -b master
mv linux-x86/clang-r450784d toolchain && rm -rf linux-x86

# Change Directory to the Source Directry
cd $WORKING_DIR/kernel

# Build Info Variables
DEVICE="raphael"
DISTRO=$(source /etc/os-release && echo $NAME)
COMPILER=$($WORKING_DIR/toolchain/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/version//g' -e 's/  */ /g' -e 's/[[:space:]]*$//')
ZIP_NAME=WAFFLES-RAPHAEL-$(TZ=Asia/Kolkata date +%Y%m%d-%H%M).zip

#Starting Compilation
BUILD_START=$(date +"%s")
msg "<b>$BUILD_ID CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Date : </b><code>$(TZ=Asia/Kolkata date)</code>%0A<b>Device : </b><code>$DEVICE</code>%0A<b>Compiler : </b><code>$COMPILER</code>%0A<b>Branch: </b><code>$BRANCH_NAME</code>"
export KBUILD_BUILD_USER="Azure"
export KBUILD_BUILD_HOST="Server"
export ARCH=arm64
export PATH="$WORKING_DIR/toolchain/bin/:$PATH"
make O=out raphael_defconfig
make -j$(nproc --all) O=out \
      ARCH=arm64
      CC=clang
      LLVM=1 \
      LLVM_IAS=1 \
      CROSS_COMPILE=aarch64-linux-gnu- \
      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
      2>&1 | tee out/error.txt
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

#Zipping & Uploading Flashable Kernel Zip
if [ -e out/arch/arm64/boot/Image.gz-dtb ] && [ -e out/arch/arm64/boot/dtbo.img ]; then
cp out/arch/arm64/boot/Image.gz-dtb $WORKING_DIR/Anykernel
cp out/arch/arm64/boot/dtbo.img $WORKING_DIR/Anykernel
cd $WORKING_DIR/Anykernel
zip -r9 $ZIP_NAME * -x .git README.md *placeholder
file "$ZIP_NAME" "*Build Completed :* $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
else
file "$WORKING_DIR/kernel/out/error.txt" "*Build Failed :* $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
fi
