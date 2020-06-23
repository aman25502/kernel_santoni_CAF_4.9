#!/usr/bin/env bash
export KERNELDIR="$PWD" 
export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache"
git config --global user.email "soniataran79@gmail.com"
git config --global user.name "aman25502"
 
export TZ="Asia/Kolkata";
 
# Kernel compiling script
mkdir -p $HOME/TC
git clone https://github.com/aman25502/AnyKernel3 -b santoni 
git clone https://github.com/kdrag0n/proton-clang.git prebuilts/proton-clang --depth=1 
 
# Upload log to del.dog
function sendlog {
    var="$(cat $1)"
    content=$(curl -sf --data-binary "$var" https://del.dog/documents)
    file=$(jq -r .key <<< $content)
    log="https://del.dog/$file"
    echo "URL is: "$log" "
    curl -s -X POST https://api.telegram.org/bot1294950340:AAF3nyGc8fOZtZ7wkAneQOkiORWZ_1YW2q8/sendMessage -d text="Build failed, "$1" "$log" :3" -d chat_id=-353080174
}
 
# Trim the log if build fails
function trimlog {
    sendlog "$1"
    grep -iE 'crash|error|fail|fatal' "$1" &> "trimmed-$1"
    sendlog "trimmed-$1"
}
 
# Unused function, can be used to upload builds to transfer.sh
function transfer() {
    zipname="$(echo $1 | awk -F '/' '{print $NF}')";
    url="$(curl -# -T $1 https://transfer.sh)";
    printf '\n';
    echo -e "Download ${zipname} at ${url}";
    curl -s -X POST https://api.telegram.org/bot1294950340:AAF3nyGc8fOZtZ7wkAneQOkiORWZ_1YW2q8/sendMessage -d text="$url" -d chat_id=-353080174
    curl -F chat_id="-353080174" -F document=@"${ZIP_DIR}/$ZIPNAME" https://api.telegram.org/bot1294950340:AAF3nyGc8fOZtZ7wkAneQOkiORWZ_1YW2q8/sendDocument
}
 
if [[ -z ${KERNELDIR} ]]; then
    echo -e "Please set KERNELDIR";
    exit 1;
fi
 
 
mkdir -p ${KERNELDIR}/aroma
mkdir -p ${KERNELDIR}/files

export KERNELNAME="TestKernel" 
export BUILD_CROSS_COMPILE="$HOME/TC/aarch64-linux-gnu-8.x/bin/aarch64-linux-gnu-"
export SRCDIR="${KERNELDIR}";
export OUTDIR="${KERNELDIR}/out";
export ANYKERNEL="${KERNELDIR}/AnyKernel3";
export AROMA="${KERNELDIR}/aroma/";
export ARCH="arm64";
export SUBARCH="arm64";
export KBUILD_COMPILER_STRING="$($KERNELDIR/prebuilts/proton-clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
export KBUILD_BUILD_USER="aman25502"
export KBUILD_BUILD_HOST="ahoy"
export PATH="$KERNELDIR/prebuilts/proton-clang/bin:${PATH}"
export DEFCONFIG="santoni_defconfig";
export ZIP_DIR="${KERNELDIR}/files";
export IMAGE="${OUTDIR}/arch/${ARCH}/boot/Image.gz-dtb";
export COMMITMSG=$(git log --oneline -1)
 
export MAKE_TYPE="Treble"
 
if [[ -z "${JOBS}" ]]; then
    export JOBS="$(nproc --all)";
fi
 
export MAKE="make O=${OUTDIR}";
export ZIPNAME="${KERNELNAME}-SANTONI-${MAKE_TYPE}$(date +%m%d-%H).zip"
export FINAL_ZIP="${ZIP_DIR}/${ZIPNAME}"
 
[ ! -d "${ZIP_DIR}" ] && mkdir -pv ${ZIP_DIR}
[ ! -d "${OUTDIR}" ] && mkdir -pv ${OUTDIR}
 
cd "${SRCDIR}";
rm -fv ${IMAGE};
 
MAKE_STATEMENT=make
 
# Menuconfig configuration
# ================
# If -no-menuconfig flag is present we will skip the kernel configuration step.
# Make operation will use santoni_defconfig directly.
if [[ "$*" == *"-no-menuconfig"* ]]
then
  NO_MENUCONFIG=1
  MAKE_STATEMENT="$MAKE_STATEMENT KCONFIG_CONFIG=./arch/arm64/configs/santoni_defconfig"
fi
 
if [[ "$@" =~ "mrproper" ]]; then
    ${MAKE} mrproper
fi
 
if [[ "$@" =~ "clean" ]]; then
    ${MAKE} clean
fi
 
 
# Send Message about build started
# ================
curl -s -X POST https://api.telegram.org/bot1294950340:AAF3nyGc8fOZtZ7wkAneQOkiORWZ_1YW2q8/sendMessage -d text="Build Scheduled for $KERNELNAME Kernel (${MAKE_TYPE})" -d chat_id=-353080174
 
 
 
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
 
# Push to Telegram if successful
# ================
if [ -f "$FINAL_ZIP" ];
then
  if [[ ${success} == true ]]; then
   
 
message="CI build of Test kernel by ahoy completed with the latest commit."

time="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."

curl -F chat_id="-353080174" -F document=@"${ZIP_DIR}/$ZIPNAME" -F caption="$message $time" https://api.telegram.org/bot1294950340:AAF3nyGc8fOZtZ7wkAneQOkiORWZ_1YW2q8/sendDocument

curl -s -X POST https://api.telegram.org/bot1294950340:AAF3nyGc8fOZtZ7wkAneQOkiORWZ_1YW2q8/sendMessage -d text="
♔♔♔♔♔♔♔BUILD-DETAILS♔♔♔♔♔♔♔
🖋️ <b>Author</b>     : <code>AHOY</code>
🛠️ <b>Make-Type</b>  : <code>$MAKE_TYPE</code>
🗒️ <b>Build-Type</b>  : <code>TEST</code>
⌚ <b>Build-Time</b> : <code>$time</code>
🗒️ <b>Zip-Name</b>   : <code>$ZIPNAME</code>
🤖 <b>Commit message</b> : <code>$COMMITMSG</code>
"  -d chat_id=-353080174 -d "parse_mode=html"
 
 
fi
else
echo -e "Zip Creation Failed  ";
fi
rm -rf build-log.txt files/ trimmed-build-log.txt
