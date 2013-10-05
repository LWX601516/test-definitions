#!/bin/sh

dmesg|grep 'Hyp mode initialized successfully' && echo kvm-init-1: pass || echo kvm-init-1: fail

wget --no-check-certificate http://snapshots.linaro.org/kernel-hwpack/linux-vexpress-kvm/linux-vexpress-kvm/kvm.qcow2.gz
gunzip kvm.qcow2.gz

modprobe nbd max_part=16
qemu-nbd -c /dev/nbd0 kvm.qcow2
mount /dev/nbd0p2 /mnt/

cp /mnt/boot/vmlinuz-*-linaro-vexpress ./zImage
cp /mnt/lib/firmware/*-linaro-vexpress/device-tree/vexpress-v2p-ca15-tc1.dtb .
cp common/scripts/kvm/kvm-lava.conf  /mnt/etc/init/kvm-lava.conf
cp /usr/bin/hackbench /mnt/usr/bin/hackbench
cp common/scripts/kvm/test-rt-tests.sh /mnt/root/test-rt-tests.sh
chmod 777 /mnt/root/test-rt-tests.sh
umount /mnt
sync
qemu-nbd -d /dev/nbd0

echo setting up and testing networking bridge for guest
brctl addbr br0
tunctl -u root
ifconfig eth0 0.0.0.0 up
ifconfig tap0 0.0.0.0 up
brctl addif br0 eth0
brctl addif br0 tap0
udhcpc -t 10 -i br0
ping -W 4 -c 10 192.168.1.10 && echo "kvm-host-net-1: pass" || echo "kvm-host-net-1: fail"

qemu-system-arm -smp 2 -m 1024 -cpu cortex-a15 -M vexpress-a15 \
	-kernel ./zImage -dtb ./vexpress-v2p-ca15-tc1.dtb \
	-append 'root=/dev/mmcblk0p2 rw rootwait mem=1024M console=ttyAMA0,38400n8' \
	-drive if=sd,cache=writeback,file=kvm.qcow2 \
	-netdev tap,id=tap0,script=no,downscript=no,ifname="tap0" \
	-device virtio-net-device,netdev=tap0 \
	-nographic -enable-kvm \
	 2>&1|tee kvm-log.txt

if ! grep -q "kvm-boot-1:" kvm-log.txt
then
    echo "kvm-boot-1: fail"
fi
