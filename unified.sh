#!/usr/bin/env bash
export KERNELDIR="$PWD" 
export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache"
git config --global user.email "dhruvgera61@gmail.com"
git config --global user.name "Dhruv"
 
export TZ="Asia/Kolkata";
 
# Kernel compiling script
mkdir -p $HOME/TC
git clone https://github.com/Dhruvgera/AnyKernel3.git 
git clone https://github.com/kdrag0n/proton-clang.git prebuilts/proton-clang --depth=1 
 
function sendlog {
    # var=$(php -r "echo file_get_contents('$1');")
    var="$(cat $1)"
    content=$(curl -sf --data-binary "$var" https://del.dog/documents)
    file=$(jq -r .key <<< $content)
    log="https://del.dog/$file"
    echo "URL is: "$log" "
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="Build failed, "$1" "$log" :3" -d chat_id=$CHAT_ID
}
 
function trimlog {
    sendlog "$1"
    grep -iE 'crash|error|fail|fatal' "$1" &> "trimmed$1"
    sendlog "trimmed_$1"
}
 
function transfer() {
    zipname="$(echo $1 | awk -F '/' '{print $NF}')";
    url="$(curl -# -T $1 https://transfer.sh)";
    printf '\n';
    echo -e "Download ${zipname} at ${url}";
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="$url" -d chat_id=$CHAT_ID
    curl -F chat_id="$CHAT_ID" -F document=@"${ZIP_DIR}/$ZIPNAME" https://api.telegram.org/bot$BOT_API_KEY/sendDocument
}
 
if [[ -z ${KERNELDIR} ]]; then
    echo -e "Please set KERNELDIR";
    exit 1;
fi
 
export DEVICE=$1;
if [[ -z ${DEVICE} ]]; then
    export DEVICE="HM4X";
fi
 
mkdir -p ${KERNELDIR}/aroma
mkdir -p ${KERNELDIR}/files

export KERNELNAME="RockstarKernel" 
export BUILD_CROSS_COMPILE="$HOME/TC/aarch64-linux-gnu-8.x/bin/aarch64-linux-gnu-"
export SRCDIR="${KERNELDIR}";
export OUTDIR="${KERNELDIR}/out";
export ANYKERNEL="${KERNELDIR}/AnyKernel3";
export AROMA="${KERNELDIR}/aroma/";
export ARCH="arm64";
export SUBARCH="arm64";
export KBUILD_COMPILER_STRING="$($KERNELDIR/prebuilts/proton-clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
export KBUILD_BUILD_USER="Dhruv"
export KBUILD_BUILD_HOST="TeamRockstar"
export PATH="$KERNELDIR/prebuilts/proton-clang/bin:${PATH}"
export DEFCONFIG="beryllium_defconfig";
export ZIP_DIR="${KERNELDIR}/files";
export IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image.gz";
export COMMITMSG=$(git log -1 --pretty=%B)
 
export MAKE_TYPE="Treble"
 
if [[ -z "${JOBS}" ]]; then
    export JOBS="$(nproc --all)";
fi
 
export MAKE="make O=${OUTDIR}";
export ZIPNAME="${KERNELNAME}-POCOPHONE-${MAKE_TYPE}$(date +%m%d-%H).zip"
export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"
 
[ ! -d "${ZIP_DIR}" ] && mkdir -pv ${ZIP_DIR}
[ ! -d "${OUTDIR}" ] && mkdir -pv ${OUTDIR}
 
cd "${SRCDIR}";
rm -fv ${IMAGE};
 
MAKE_STATEMENT=make
 
# Menuconfig configuration
# ================
# If -no-menuconfig flag is present we will skip the kernel configuration step.
# Make operation will use beryllium_defconfig directly.
if [[ "$*" == *"-no-menuconfig"* ]]
then
  NO_MENUCONFIG=1
  MAKE_STATEMENT="$MAKE_STATEMENT KCONFIG_CONFIG=./arch/arm64/configs/beryllium_defconfig"
fi
 
if [[ "$@" =~ "mrproper" ]]; then
    ${MAKE} mrproper
fi
 
if [[ "$@" =~ "clean" ]]; then
    ${MAKE} clean
fi
 
 
# Send Message about build started
# ================
curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="Build Scheduled for $KERNELNAME Kernel (${MAKE_TYPE})" -d chat_id=$CHAT_ID
 
 
 
cd $KERNELDIR
${MAKE} $DEFCONFIG;
START=$(date +"%s");
echo -e "Using ${JOBS} threads to compile"
 
# Start the build
# ================
${MAKE} -j${JOBS} \ ARCH=arm64 \ CC=clang  \ CROSS_COMPILE=aarch64-linux-gnu- \ CROSS_COMPILE_ARM32=arm-linux-gnueabi- \ NM=llvm-nm \ OBJCOPY=llvm-objcopy \ OBJDUMP=llvm-objdump \ STRIP=llvm-strip  | tee build-log.txt ;

 
 
exitCode="$?";
END=$(date +"%s")
DIFF=$(($END - $START))
echo -e "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.";
 
# Send log and trimmed log if build failed
# ================
if [[ ! -f "${IMAGE}" ]]; then
    echo -e "Build failed :P";
    trimlog build-log.txt
    success=false;
    exit 1;
else
    echo -e "Build Succesful!";
    success=true;
fi
 
# Make ZIP using AnyKernel
# ================
echo -e "Copying kernel image";
cp -v "${IMAGE}" "${ANYKERNEL}/";
cd -;
cd ${ANYKERNEL};
zip -r9 ${FINAL_ZIP} *;
cd -;
 
# Push to transfer.sh if successful
# ================
if [ -f "$FINAL_ZIP" ];
then
  if [[ ${success} == true ]]; then
   
 
message="CI build of Rockstar Kernel completed with the latest commit."

time="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."

#curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="$(git log --pretty=format:'%h : %s' -5)" -d chat_id=$CHAT_ID

curl -F chat_id="$CHAT_ID" -F document=@"${ZIP_DIR}/$ZIPNAME" -F caption="$message $time" https://api.telegram.org/bot$BOT_API_KEY/sendDocument

curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="

♔♔♔♔♔♔♔BUILD-DETAILS♔♔♔♔♔♔♔

🖋️ Author     : DhruvGera

🛠️ Make-Type  : $MAKE_TYPE

🗒️ Buld-Type  : TEST

⌚ Build-Time : $time

🗒️ Zip-Name   : $ZIPNAME

Commit message : $COMMITMSG
"  -d chat_id=$CHAT_ID
# curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="CAADBQADFQADIIRIEhVlVOIt6EkuAgc"  -d chat_id=$CHAT_ID
# curl -F document=@$url caption="Latest Build." https://api.telegram.org/bot$BOT_API_KEY/sendDocument -d chat_id=$CHAT_ID
 
 
fi
else
echo -e "Zip Creation Failed  ";
fi
