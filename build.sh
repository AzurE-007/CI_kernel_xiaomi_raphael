#!/usr/bin/env bash

# Bail out if script fails
set -e

# Working Directory
WORKING_DIR=~/

# Functions For Telegram Post
msg() {
	curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

file() {
	MD5=$(md5sum "$1" | cut -d' ' -f1)
	curl --progress-bar -F document=@"$1" "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
	-d chat_id="$TG_CHAT_ID" \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$2 | <b>MD5 Checksum : </b><code>$MD5</code>"
}

# Cloning Anykernel
git clone --depth=1 https://github.com/back-up-git/AnyKernel3.git -b main $WORKING_DIR/Anykernel

# Cloning Kernel
git clone --depth=1 https://github.com/back-up-git/kernel_xiaomi_raphael.git -b staging $WORKING_DIR/kernel

# Cloning Toolchain
# git clone https://github.com/kdrag0n/proton-clang.git toolchain

# Change Directory to the Source Directry 
cd $WORKING_DIR/kernel

# Build Info Variables
DEVICE="Mi 9T Pro | Redmi K20 Pro"
DISTRO=$(source /etc/os-release && echo $NAME)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMPILER=$($WORKING_DIR/toolchains/proton-clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')

#Starting Compilation
BUILD_START=$(date +"%s")
msg "<b>$BUILD_ID CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Date : </b><code>$(TZ=Asia/NewDelhi date)</code>%0A<b>Device : </b><code>$DEVICE</code>%0A<b>Branch: </b><code>$RUNNER_NAME</code>"
export KBUILD_BUILD_USER="Azure"
export KBUILD_BUILD_HOST="Server"
export ARCH=arm64
export PATH="$WORKING_DIR/toolchains/bin/:$PATH"
cd $WORKING_DIR/kernel
make O=out raphael_defconfig
make -j$(nproc --all) O=../out \
      CC=clang | tee log.txt \
      AR=llvm-ar \
      NM=llvm-nm \
      OBJCOPY=llvm-objcopy \
      OBJDUMP=llvm-objdump \
      STRIP=llvm-strip \
      LD=ld.lld \
      HOSTCC=clang \
      HOSTLD=ld.lld \
      HOSTAR=llvm-ar \
      HOSTCXX=clang++ \
      CLANG_TRIPLE=aarch64-linux-gnu- \
      CROSS_COMPILE=aarch64-linux-gnu- \
      CROSS_COMPILE_ARM32=arm-linux-gnueabi-

#Zipping Into Flashable Zip
if [ -f out/arch/arm64/boot/Image.gz-dtb ]
then
cp out/arch/arm64/boot/Image.gz-dtb $WORKING_DIR/Anykernel
cd $WORKING_DIR/Anykernel
zip -r9 IMMENSiTY-ext-RAPHAEL-$DATE.zip * -x .git README.md */placeholder
cp $WORKING_DIR/Anykernel/IMMENSiTY-ext-RAPHAEL-$DATE.zip $WORKING_DIR/
rm -rf $WORKING_DIR/Anykernel/Image.gz-dtb
rm -rf $WORKING_DIR/Anykernel/IMMENSiTY-$DATE.zip
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

#Upload Kernel ZIP
file "$WORKING_DIR/IMMENSiTY-ext-RAPHAEL-$DATE.zip" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"

else
file "$WORKING_DIR/kernel/log.txt" "Build Failed and took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
fi
