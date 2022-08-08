#!/bin/bash

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
	-F chat_id="$TG_CHAT_ID" \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2 | *MD5 Checksum : *\`$MD5\`"
}

# Cloning Anykernel
git clone --depth=1 https://github.com/back-up-git/AnyKernel3.git -b main $WORKING_DIR/Anykernel

# Build Info Variables
DEVICE="raphael"
DISTRO=$(source /etc/os-release && echo $NAME)
ZIP_NAME=IMMENSiTY-ext-RAPHAEL-$(TZ=Asia/Kolkata date +%Y%m%d-%H%M).zip

#Starting Compilation
BUILD_START=$(date +"%s")
msg "<b>$BUILD_ID CI Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Date : </b><code>$(TZ=Asia/Kolkata date)</code>%0A<b>Device : </b><code>$DEVICE</code>%0A<b>Compiler : </b><code>COMPILER</code>%0A<b>Branch: </b><code>BRANCH_NAME</code>"
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

#Zipping & Uploading Flashable Kernel Zip
if [ -e $WORKING_DIR/Anykernel/anykernel.sh ]; then
cd $WORKING_DIR/Anykernel
zip -r9 $ZIP_NAME * -x .git README.md *placeholder
cp $ZIP_NAME $WORKING_DIR/
file "$ZIP_NAME" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
else
file "$WORKING_DIR/Anykernel/anykernel.sh" "Build Failed and took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
fi
