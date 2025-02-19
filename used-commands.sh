#!/bin/sh
echo "$0: do not run"; exit 1

# use efibootmgr without arguments to list current entries
efibootmgr

# example how to create boot entry with efibootmgr
efibootmgr --create --disk /dev/sdX --part Y --loader "\EFI\path\to\boot.efi" --label "Label"
# /dev/sdX is a drive, and Y is an EFI system partition on it
# if /dev/sdXY is mounted to /boot/efi, loaded path is relative to it,
# so for /boot/efi/EFI/path/to/boot.efi loader if \EFI\path\to\boot.efi

# example how to remove boot entry with efibootmgr
efibootmgr --bootnum XXXX --delete-bootnum
# where XXXX is an entry number

# example how to change boot order
efibootmgr --bootorder XXXX,YYYY,ZZZZ

# ============================================================================ #
# ============================================================================ #
# ============================================================================ #

modprobe i2c-dev
i2cdetect -yl | sort
# i2c-N   i2c             name                                    I2C adapter
# ===========================================================================
# i2c-0   i2c             2180000.i2c                             I2C adapter
# i2c-1   i2c             2190000.i2c                             I2C adapter
# i2c-2   i2c             i2c-0-mux (chan_id 0)                   I2C adapter
# i2c-3   i2c             i2c-0-mux (chan_id 1)                   I2C adapter
# i2c-4   i2c             i2c-0-mux (chan_id 4)                   I2C adapter
# i2c-5   i2c             i2c-0-mux (chan_id 5)                   I2C adapter
i2cdetect -y $N
i2cdump -y $N $A

# ============================================================================ #
# ============================================================================ #
# ============================================================================ #

filename='<filename>'
directory='<directory>'

cpio -i --extract  # extract archive
cpio -o --create   # create archive (data from stdin)
cpio -c            # use old portable ASCII archive format
cpio -v --verbose  # verbose output
cpio -t --list     # print archived filenames

# examples how to extract cpio archive
cpio -i < "$filename.cpio"
zcat "$filename.cpio.gz" | cpio -i

# example how to create cpio archive
find "$directory" | cpio -o > "$directory.cpio"
find "$directory" | cpio -o | xz -z9 > "$directory.cpio.xz"
find "$directory" -print0 | cpio -0o > "$directory.cpio"
find "$directory" -depth -print0 | cpio -0oHnewc > "$directory.cpio"

# ============================================================================ #
# ============================================================================ #
# ============================================================================ #

sudo echo "/path/to/folder 192.168.0.0/24(rw,sync,no_subtree_check)" > /etc/exports
sudo exportfs -arv && sudo systemctl restart nfs-server

# ============================================================================ #
# ============================================================================ #
# ============================================================================ #

qemu-img create -f qcow2 -o size=32G $DISK.qcow2
sudo DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY \
  qemu-system-x86_64 -enable-kvm -m $MEM -smp $NPROC \
    '# for uefi (copy from /usr/share/qemu...)' \
    -drive if=pflash,format=raw,readonly=on,file=ovmf-x86_64-code.bin \
    -drive if=pflash,format=raw,file=ovmf-x86_64-vars.bin \
    '# for bridged network' \
    -device virtio-net-pci,netdev=net0,mac=12:34:56:78:9A:BC \
    -netdev bridge,id=net0,br=$HOST_BRIDGE_NAME \
    '# drive and cdrom' \
    -drive format=qcow2,file=$DISK.qcow2 \
    -cdrom distro.iso

# ============================================================================ #

modprobe nbd max_part=2
qemu-nbd --connect=/dev/nbd0 $DISK1.qcow2
qemu-nbd --connect=/dev/nbd1 $DISK2.qcow2
mount /dev/nbd0p1 /path/to/mntpoint
mount /dev/nbd1p1 /path/to/mntpoint

# ============================================================================ #

# append to kernel params: intel_iommu=on

# make sure IOMMU is used:
dmesg | grep -e DMAR -e IOMMU

# find PCI ID of passthrough device (xx:xx.x):
lspci

# find in which iommu groum the device is in:
find /sys/kernel/iommu_groups/ -type l  # 15

# find DEVICE ID and VENDOR ID of the device:
lspci -nnks 04:00.0  # [8086:1537]

# setup vfio-pci kernel module
echo "options vfio-pci ids=8086:1537" >> /etc/modprobe.d/vfio.conf
sudo modprobe vfio-pci

# run qemu
qemu-system-x86_64 -enable-kvm -device vfio-pci,host=04:00.0
