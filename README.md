# Arch-on-Air

Yet another note on *Let's make ArchLinux up and running on MacBook Air!*

Thie is one way, or I would say, *my way* of running *Arch* on *Air*,
based on the official
[ArchLinux on MacBook(Air)](https://wiki.archlinux.org/index.php/MacBook) wiki
and
[Arch Installation guide](https://wiki.archlinux.org/index.php/installation_guide).

Buckle up and let's roll!

- [Spec](#spec)
- [Pre-installation](#pre-installation)
- [Installation](#installation)
- [Post-installation](#post-installation)

## Spec

Her is my air:

```
Model Name:		MacBook Air
Model Identifier:	MacBookAir7,1
Processor Name:		Intel Core i7
Processor Speed:	2.2 GHz
Number of Processors:	1
Total Number of Cores:	2
L2 Cache (per Core):	256 KB
L3 Cache:		4 MB
Memory:			8 GB
```

## Pre-installation

- [Dualboot](#dual-booting)
- [Keyboard](#set-the-keyboard-layout)
- [Network](#connect-to-the-internet)
- [Clock](#update-the-system-clock)
- [Partition](#partition-the-disks)
- [Format](#format-the-partitions)
- [Mount](#mount-the-partitions)

### Dual booting

As I use OSX ocasionally, I dual boot the air with OSX.  As recommended on
[Arch on MacBook(Air) wiki](https://wiki.archlinux.org/index.php/MacBook#OS_X_with_Arch_Linux),
I use the Apple partition tool to shrink the OSX partition to around 180GB to
make enough space for linux.

```
root@archiso ~ # lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0 465.9G  0 disk
__sda1   8:1    0   200M  0 part
__sda2   8:2    0 179.2G  0 part
__sda3   8:3    0 619.9M  0 part
```

Here, *sda1* for the EFI system partition, *sda2* for OSX, *sda4* for the base Linux,
and *sda5* for the libvirt storage pool.

### Set the keyboard layout

Load *emacs key binding*, as usual:

```
root@archiso ~ # loadkeys /usr/share/kbd/keymaps/i386/qwerty/emacs2.map.gz
```

### Connect to the Internet

As default wifi doesn't work out of the box, I just connect TP-Link power over
ether adapter and hook into the thunderbolt port:

```
root@archiso ~ # ip l
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group
default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: ens9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether 38:c9:86:04:85:78 brd ff:ff:ff:ff:ff:ff
```

and then, run *dhcp* on top of it:

```
root@archiso ~ # systemctl start dhcpcd@ens9
```

### Update the system clock

```
root@archiso ~ # timedatectl set-ntp true
```

### Partition the disks

#### gdisk

Create two LVM partitions by `gdisk`, one for the base Linux OS and the other
for the libvirt storage pool.  As mentioned in
[ArchWiki](https://wiki.archlinux.org/index.php/MacBook#Option_1:_EFI), use
*+128M* as the starting point to make a gap after OSX partition:

```
root@archiso ~ # gdisk /dev/sda
GPT fdisk (gdisk) version 1.0.1

Partition table scan:
MBR: protective
BSD: not present
APM: not present
GPT: present

Found valid GPT with protective MBR; using GPT.

Command (? for help): p
Disk /dev/sda: 977105060 sectors, 465.9 GiB
Logical sector size: 512 bytes
Disk identifier (GUID): D05045F2-0A79-46AD-B240-1E67BE21E787
Partition table holds up to 128 entries
First usable sector is 34, last usable sector is 977105026
Partitions will be aligned on 8-sector boundaries
Total free space is 524294 sectors (256.0 MiB)

Number  Start (sector)    End (sector)  Size       Code  Name
1              40          409639   200.0 MiB   EF00  EFI System Partition
2          409640       376118559   179.2 GiB   AF05  Customer
3       376118560       377388095   619.9 MiB   AB00  Recovery HD
4       377650240       713194559   160.0 GiB   8E00  Linux LVM
5       713456704       977105026   125.7 GiB   8E00  Linux LVM

Command (? for help): q
```

#### LVM

Let's create LVM logical volumes on partition *sda4* for the base OS installation:

```
root@archiso ~ # lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0 465.9G  0 disk
__sda1   8:1    0   200M  0 part
__sda2   8:2    0 179.2G  0 part
__sda3   8:3    0 619.9M  0 part
__sda4   8:4    0   160G  0 part
__sda5   8:5    0 125.7G  0 part
```

##### Physical volumes

Initialize those two partitions as a LVM physical volumes with `pvcreate`:

```
root@archiso ~ # pvcreate /dev/sda4
Physical volume "/dev/sda4" successfully created.
root@archiso ~ # pvcreate -ff /dev/sda5
Physical volume "/dev/sda5" successfully created.
root@archiso ~ # pvs
PV         VG Fmt  Attr PSize   PFree
/dev/sda4     lvm2 ---  160.00g 160.00g
/dev/sda5     lvm2 ---  125.72g 125.72g
```

##### Logical groups

Create a logical groups, one for base OS, *vg0*, and the other for the the
libvirt storage pool, *vg1*, with `vgcreate`:

```
root@archiso ~ # vgcreate vg0 /dev/sda4
Volume group "vg0" successfully created
root@archiso ~ # vgcreate vg1 /dev/sda5
Volume group "vg1" successfully created
```

##### Logical volumes

Create logical volumes for the base OS with `lvcreate`:

```
root@archiso ~ # lvcreate -L 32G -n root vg0
Logical volume "root" created.
root@archiso ~ # lvcreate -L 64G -n home vg0
Logical volume "home" created.
root@archiso ~ # lvcreate -l 100%FREE -n var vg0
Logical volume "var" created.
root@archiso ~ # lvs
LV   VG  Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
home vg0 -wi-a----- 64.00g
root vg0 -wi-a----- 32.00g
var  vg0 -wi-a----- 64.00g
```

### Format the partitions

Let's format those three logical volumes as *btrfs* file systems:

```
root@archiso ~ # mkfs.btrfs /dev/vg0/root
btrfs-progs v4.6.1
See http://btrfs.wiki.kernel.org for more information.

Detected a SSD, turning off metadata duplication.  Mkfs with -m dup if you want to forc
e metadata duplication.
Performing full device TRIM (32.00GiB) ...
Label:              (null)
UUID:               7a0d3277-5c30-4576-a269-f9aa7fff2e1e
Node size:          16384
Sector size:        4096
Filesystem size:    32.00GiB
Block group profiles:
  Data:             single            8.00MiB
  Metadata:         single            8.00MiB
  System:           single            4.00MiB
SSD detected:       yes
Incompat features:  extref, skinny-metadata
Number of devices:  1
Devices:
  ID        SIZE  PATH
   1    32.00GiB  /dev/vg0/root

root@archiso ~ # mkfs.btrfs /dev/vg0/home
btrfs-progs v4.6.1
See http://btrfs.wiki.kernel.org for more information.

Detected a SSD, turning off metadata duplication.  Mkfs with -m dup if you want to force metadata duplication.
Performing full device TRIM (64.00GiB) ...
Label:              (null)
UUID:               4d9072c7-8ebf-4208-9603-a447c77e0321
Node size:          16384
Sector size:        4096
Filesystem size:    64.00GiB
Block group profiles:
  Data:             single            8.00MiB
  Metadata:         single            8.00MiB
  System:           single            4.00MiB
SSD detected:       yes
Incompat features:  extref, skinny-metadata
Number of devices:  1
Devices:
  ID        SIZE  PATH
   1    64.00GiB  /dev/vg0/home

root@archiso ~ # mkfs.btrfs /dev/vg0/var
btrfs-progs v4.6.1
See http://btrfs.wiki.kernel.org for more information.

Detected a SSD, turning off metadata duplication.  Mkfs with -m dup if you want to force metadata duplication.
Performing full device TRIM (64.00GiB) ...
Label:              (null)
UUID:               305f28f3-edfd-4656-8ba3-36dad6703d64
Node size:          16384
Sector size:        4096
Filesystem size:    64.00GiB
Block group profiles:
  Data:             single            8.00MiB
  Metadata:         single            8.00MiB
  System:           single            4.00MiB
SSD detected:       yes
Incompat features:  extref, skinny-metadata
Number of devices:  1
Devices:
  ID        SIZE  PATH
   1    64.00GiB  /dev/vg0/var
```

### Mount the partitions

Mount all those LVM based partitions, in addition to the EFI system partition
as below:

```
root@archiso ~ # mount /dev/vg0/root /mnt
root@archiso ~ # for i in home var
\`for> do
\`for> mkdir /mnt/$i
\`for> mount /dev/vg0/$i /mnt/$i
\`for> done
root@archiso ~ # mount /dev/sda1 /mnt/boot
root@archiso ~ # df -k
Filesystem           1K-blocks   Used Available Use% Mounted on
dev                    4025808      0   4025808   0% /dev
run                    4040120  46588   3993532   2% /run
/dev/sdb1               759808 759808         0 100% /run/archiso/bootmnt
cowspace                262144   7244    254900   3% /run/archiso/cowspace
/dev/loop0              328704 328704         0 100% /run/archiso/sfs/airootfs
airootfs                262144   7244    254900   3% /
tmpfs                  4040120      0   4040120   0% /dev/shm
tmpfs                  4040120      0   4040120   0% /sys/fs/cgroup
tmpfs                  4040120      0   4040120   0% /tmp
tmpfs                  4040120   1200   4038920   1% /etc/pacman.d/gnupg
tmpfs                   808024      0    808024   0% /run/user/0
/dev/mapper/vg0-root  33554432  16576  33278912   1% /mnt
/dev/mapper/vg0-home  67108864  16768  66046720   1% /mnt/home
/dev/mapper/vg0-var   67104768  16768  66042624   1% /mnt/var
/dev/sda1               201633 129864     71770  65% /mnt/boot
```

## Installation

- [Pacman](#pacman-mirror)
- [Packages](#install-the-base-packages)
- [Configuration](#configure-the-system)
- [Bootloader](#install-the-boot-loader)
- [Reboot!](#reboot-the-system)

### Pacman mirror

Bring the `kernel.org` to the top.

```
root@archiso ~ # head -10 /etc/pacman.d/mirrorlist
##
## Arch Linux repository mirrorlist
## Sorted by mirror score from mirror status page
## Generated on 2016-08-01
##

Server = http://mirrors.kernel.org/archlinux/$repo/os/$arch
## Score: 0.2, France
Server = http://archlinux.polymorf.fr/$repo/os/$arch
## Score: 0.3, France
```

### Install the base packages

Install the *base* package with `pacstrap`:

```
root@archiso ~ # pacstrap /mnt base
```

### Configure the system

#### /etc/fstab

Run `genfstab`

```
root@archiso ~ # genfstab -p /mnt >> /mnt/etc/fstab
```

and here you are:

```
root@archiso ~ # cat /mnt/etc/fstab
#
# /etc/fstab: static file system information
#
# <file system> <dir>   <type>  <options>       <dump>  <pass>
# UUID=7a0d3277-5c30-4576-a269-f9aa7fff2e1e
/dev/mapper/vg0-root    /               btrfs           rw,relatime,ssd,space_cache,subvolid=5,subvol=/        0 0

# UUID=4d9072c7-8ebf-4208-9603-a447c77e0321
/dev/mapper/vg0-home    /home           btrfs           rw,relatime,ssd,space_cache,subvolid=5,subvol=/        0 0

# UUID=305f28f3-edfd-4656-8ba3-36dad6703d64
/dev/mapper/vg0-var     /var            btrfs           rw,relatime,ssd,space_cache,subvolid=5,subvol=/        0 0

# UUID=67E3-17ED LABEL=EFI
/dev/sda1               /boot           vfat            rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro   0 2

```

#### chroot

You do `arch-chroot`

```
root@archiso ~ # arch-chroot /mnt
```

and will be in the sandbox:

```
[root@archiso /]# df -k
Filesystem           1K-blocks   Used Available Use% Mounted on
/dev/mapper/vg0-root  33554432 697848  32629464   3% /
/dev/mapper/vg0-home  67108864  16768  66046720   1% /home
/dev/mapper/vg0-var   67104768 227932  65832356   1% /var
/dev/sda1               201633  53823    147811  27% /boot
udev                   4025808      0   4025808   0% /dev
shm                    4040120      0   4040120   0% /dev/shm
run                    4040120      0   4040120   0% /run
tmp                    4040120      0   4040120   0% /tmp
airootfs                262144   7280    254864   3% /etc/resolv.conf
[root@archiso /]#
```

#### timezone

Link the `zoneinfo` file

```
[root@archiso /]# ln -s /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
```

to get your local time.

```
[root@archiso /]# date
Fri Aug  5 23:15:10 PDT 2016
```

#### locale

Uncomment *UTF-8*

```
[root@archiso /]# grep -v "^#" /etc/locale.gen
en_US.UTF-8 UTF-8
```

and run `locale-gen`

```
[root@archiso /]# locale-gen
Generating locales...
  en_US.UTF-8... done
Generation complete.
```

#### Hostname

Of course, it will be called *air*:)

```
[root@archiso /]# echo air > /etc/hostname
```

```
root@archiso /]# sed -i.orig -e "s/localhost$/localhost air/" /etc/hosts
```

#### Initial ramdisk

Install `btrfs-progs`

```
[root@archiso /]# pacman -S btrfs-progs
resolving dependencies...
looking for conflicting packages...

Packages (1) btrfs-progs-4.6.1-1

Total Download Size:   0.56 MiB
Total Installed Size:  3.97 MiB

:: Proceed with installation? [Y/n] y
:: Retrieving packages...
 btrfs-progs-4.6.1-1-x...   571.1 KiB   159K/s 00:04 [###########################] 100%
 (1/1) checking keys in keyring                       [###########################] 100%
 (1/1) checking package integrity                     [###########################] 100%
 (1/1) loading package files                          [###########################] 100%
 (1/1) checking for file conflicts                    [###########################] 100%
 (1/1) checking available disk space                  [###########################] 100%
 :: Processing package changes...
 (1/1) installing btrfs-progs                         [###########################] 100%
 :: Running post-transaction hooks...
 (1/1) Updating manpage index...
```

enable *LVM*

```
[root@archiso /]# grep '^HOOKS' /etc/mkinitcpio.conf
HOOKS="base udev autodetect modconf block lvm2 filesystems keyboard fsck"
```

and create an initial RAM disk with `mkinitcpio`

```
[root@archiso /]# mkinitcpio -p linux
==> Building image from preset: /etc/mkinitcpio.d/linux.preset: 'default'
 -> -k /boot/vmlinuz-linux -c /etc/mkinitcpio.conf -g /boot/initramfs-linux.img
==> Starting build: 4.6.4-1-ARCH
 -> Running build hook: [base]
 -> Running build hook: [udev]
 -> Running build hook: [autodetect]
 -> Running build hook: [modconf]
 -> Running build hook: [block]
 -> Running build hook: [lvm2]
 -> Running build hook: [filesystems]
 -> Running build hook: [keyboard]
 -> Running build hook: [fsck]
==> Generating module dependencies
==> Creating gzip-compressed initcpio image: /boot/initramfs-linux.img
==> Image generation successful
==> Building image from preset: /etc/mkinitcpio.d/linux.preset: 'fallback'
 -> -k /boot/vmlinuz-linux -c /etc/mkinitcpio.conf -g /boot/initramfs-linux-fallback.img -S autodetect
==> Starting build: 4.6.4-1-ARCH
 -> Running build hook: [base]
 -> Running build hook: [udev]
 -> Running build hook: [modconf]
 -> Running build hook: [block]
==> WARNING: Possibly missing firmware for module: wd719x
==> WARNING: Possibly missing firmware for module: aic94xx
 -> Running build hook: [lvm2]
 -> Running build hook: [filesystems]
 -> Running build hook: [keyboard]
 -> Running build hook: [fsck]
==> Generating module dependencies
==> Creating gzip-compressed initcpio image: /boot/initramfs-linux-fallback.img
==> Image generation successful
```

#### root password

Do it before you forget:

```
[root@archiso /]# passwd root
New password:
Retype new password:
passwd: password updated successfully
```

### Install the boot loader

Let's go with [systemd-boot](https://wiki.archlinux.org/index.php/Systemd-boot)
with `bootctl`, as we're [UEFI](https://en.wikipedia.org/wiki/Unified_Extensible_Firmware_Interface)!

```
[root@archiso /]# bootctl --path=/boot install
Created "/boot/EFI/systemd".
Created "/boot/EFI/BOOT".
Copied "/usr/lib/systemd/boot/efi/systemd-bootx64.efi" to "/boot/EFI/systemd/systemd-bootx64.efi".
Copied "/usr/lib/systemd/boot/efi/systemd-bootx64.efi" to "/boot/EFI/BOOT/BOOTX64.EFI".
Created EFI boot entry "Linux Boot Manager".
```

and edit `/boot/loader/loader.conf` and `/boot/loader/entries/arch.conf`:

```
[root@archiso /]# cat /boot/loader/loader.conf
default arch
timeout 4
editor  0
```
```
[root@archiso /]# cat /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=/dev/mapper/vg0-root rw
```

### Reboot the system

Before reboot, let's exit from the *chroot* and unmount all the partition:

```
[root@archiso /]# exit
exit
arch-chroot /mnt  15.90s user 2.04s system 0% cpu 48:35.87 total
```

```
root@archiso ~ # df -k
Filesystem           1K-blocks   Used Available Use% Mounted on
dev                    4025808      0   4025808   0% /dev
run                    4040120  46596   3993524   2% /run
/dev/sdb1               759808 759808         0 100% /run/archiso/bootmnt
cowspace                262144   7280    254864   3% /run/archiso/cowspace
/dev/loop0              328704 328704         0 100% /run/archiso/sfs/airootfs
airootfs                262144   7280    254864   3% /
tmpfs                  4040120      0   4040120   0% /dev/shm
tmpfs                  4040120      0   4040120   0% /sys/fs/cgroup
tmpfs                  4040120      0   4040120   0% /tmp
tmpfs                  4040120   1200   4038920   1% /etc/pacman.d/gnupg
tmpfs                   808024      0    808024   0% /run/user/0
/dev/mapper/vg0-root  33554432 703604  32623804   3% /mnt
/dev/mapper/vg0-home  67108864  16768  66046720   1% /mnt/home
/dev/mapper/vg0-var   67104768 225852  65834468   1% /mnt/var
/dev/sda1               201633  65311    136323  33% /mnt/boot
```

Unmount all those four partitions:

```
root@archiso ~ # umount /mnt/{boot,home,var,}
```

```
root@archiso ~ # df -k
Filesystem     1K-blocks   Used Available Use% Mounted on
dev              4025808      0   4025808   0% /dev
run              4040120  46596   3993524   2% /run
/dev/sdb1         759808 759808         0 100% /run/archiso/bootmnt
cowspace          262144   7280    254864   3% /run/archiso/cowspace
/dev/loop0        328704 328704         0 100% /run/archiso/sfs/airootfs
airootfs          262144   7280    254864   3% /
tmpfs            4040120      0   4040120   0% /dev/shm
tmpfs            4040120      0   4040120   0% /sys/fs/cgroup
tmpfs            4040120      0   4040120   0% /tmp
tmpfs            4040120   1200   4038920   1% /etc/pacman.d/gnupg
tmpfs             808024      0    808024   0% /run/user/0
```

Cool, let's reboot!

```
root@archiso ~ # reboot
```

## Post-installation

### X

### WiFi

### Audio

### Video

### Bluetooth

### Touchpad

### Natural Scrolling

### KVM

### Slack

### Google hangout

### Zoom
