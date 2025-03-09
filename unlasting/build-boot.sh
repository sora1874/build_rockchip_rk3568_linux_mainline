#!/bin/bash

WORKDIR="$(pwd)"
JOBS="8"
BOOT_DEFAULE_CONFIG=unlasting-rock3c_defconfig
KERNEL_DEFAULE_CONFIG=unlasting_defconfig
KERNEL_DTB=rk3566-unlasting-rock3c.dtb

export ROCKCHIP_TPL="/nvme/04_rkbin/bin/rk35/rk3566_ddr_1056MHz_v1.23.bin"
export BL31="/nvme/04_rkbin/bin/rk35/rk3568_bl31_v1.44.elf"

function log_err() {
    echo -e "\e[31m $1 \e[0m"
    return 0
}

function log_info() {
    echo -e "\e[32m $1 \e[0m"
    return 0
}

function build_uboot() {
    cd "${WORKDIR}/u-boot"
    export ARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    mkdir -p build deploy
    chmod 777 build
    chmod 777 deploy
    make clean
    make distclean
    make CROSS_COMPILE=aarch64-linux-gnu- O=build ${BOOT_DEFAULE_CONFIG}
    make CROSS_COMPILE=aarch64-linux-gnu- O=build -j${JOBS}
    cp -v build/u-boot-rockchip.bin deploy/
    # cp -v build/idbloader.img deploy/
    # cp -v build/u-boot.itb deploy/
    cd "${WORKDIR}"
}

function build_kernel() {
    log_info "Building kernel..."

    cd "${WORKDIR}/kernel"
    export ARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    mkdir -p build deploy/modules
    chmod 777 build
    chmod 777 deploy
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=build ${KERNEL_DEFAULE_CONFIG}
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=build Image -j${JOBS}
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=build modules -j${JOBS}
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=build rockchip/${KERNEL_DTB}
    cp -v build/arch/arm64/boot/Image deploy/
    cp -v build/arch/arm64/boot/dts/rockchip/${KERNEL_DTB} deploy/
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=build modules_install INSTALL_MOD_PATH="${WORKDIR}/kernel/deploy/modules" INSTALL_MOD_STRIP=1
    tar --xform s:'^./':: -czf deploy/kmods.tar.gz -C "${WORKDIR}/kernel/deploy/modules" .
    mkimage -A arm -O linux -T script -C none -a 0 -e 0 -d ${WORKDIR}/config/rk356x.bootscript deploy/boot.scr
    cd "${WORKDIR}"
}

if [ ! -d "u-boot" ]; then
    log_err "No u-boot dir"
    exit 1
fi



UBOOT_DEPLOY=${WORKDIR}/u-boot/deploy/u-boot-rockchip.bin
if [ -f ${UBOOT_DEPLOY} ]; then
  log_info "build uboot get ${UBOOT_DEPLOY}"
else
    log_info "Building u-boot..."
    build_uboot
fi


if [ ! -d "kernel" ]; then
    log_err "No kernel dir"
    exit 1
fi

KERNEL_DEPLOY=${WORKDIR}/kernel/deploy/Image
if [ -f ${KERNEL_DEPLOY} ]; then
  log_info "build kernel get ${KERNEL_DEPLOY}"
else
    log_info "Building kernel..."
    build_kernel
fi



# echo "Base system builds completed."
#dd if=idbloader.img of=/dev/mmcblk0 seek=64 conv=notrunc
#dd if=u-boot.itb of=/dev/mmcblk0 seek=16384 conv=notrunc
