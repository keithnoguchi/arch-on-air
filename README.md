# Arch-on-Air

Yet another note on *Let's make ArchLinux up and running on MacBook Air!*

This is one way, or I would say, *my way* of running *Arch* on *Air*,
based on the official
[ArchLinux on MacBook(Air)](https://wiki.archlinux.org/index.php/MacBook) wiki
and
[Arch Installation guide](https://wiki.archlinux.org/index.php/installation_guide).

- [Spec](#spec)
- [Pre-installation](#pre-installation)
- [Installation](#installation)
- [Post-installation](#post-installation)

Buckle up and let's roll!

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

I wish it's a quad core with 16GB of memory, but hey, it does a decent job! :)

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
+-sda1   8:1    0   200M  0 part
+-sda2   8:2    0 179.2G  0 part
+-sda3   8:3    0 619.9M  0 part
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
for the libvirt storage pool.  As explained in
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

- [Console](#console)
- [Kernel](#kernel)
- [WiFi](#wifi)
- [Video](#video)
- [Backlight](#screen-backlight)
- [X](#x)
- [WindowManager](#window-manager)
- [KeyMapping](#key-mapping)
- [Fonts](#fonts)
- [Scrolling](#natural-scrolling)
- [Power](#power)
- [Bluetooth](#bluetooth)
- [Web](#browser)
- [Slack](#slack)
- [Audio](#audio)
- [Facetime HD](#facetime-hd)
- [Hangouts](#google-hangouts)
- [Zoom](#zoom)
- [Vagrant/VirtualBox](#vagrant-virtualbox)
- [KVM](#kvm)
- [Open vSwitch](#open-vswitch)

### Console

Let's disable caps-lock on the console

```
air$ cat /etc/vconsole.conf
KEYMAP=emacs2
```

#### Console apps

Those are my favorite apps on console

```
air$ sudo pacman -S tmux vim irssi mutt cscope w3m tcpdump net-tools gnu-netcat
```

### Kernel

Let's build the kernel(TM)

First get the toolkit,

```
air$ sudo pacman -S gcc make bc
```

compile,

```
air$ tar xfJ linux-4.7.tar.xz
air$ cd linux-4.7
air$ zcat /proc/config.gz > .config
air$ make oldconfig
...
air$ make
```

and, install!

```
air$ sudo make modules_install
air$ sudo cp ./arch/x86_64/boot/bzImage /boot/vmlinuz-4.7.0.1
air$ sudo mkinitcpio -k 4.7.0.1 -g /boot/initramfs-4.7.0.1.img
```

Create new boot loader entries under `/boot/loader/entries`

```
air$ cat /boot/loader/entries/4.7.0.conf
title   4.7.0.1 train
linux   /vmlinuz-4.7.0.1
initrd  /initramfs-4.7.0.1.img
options root=/dev/mapper/vg0-root rw
```
make the new one as a default kernel

```
air$ sudo sed -i.old -e "s/arch/4.7.0/"  /boot/loader/loader.conf
air$ cat /boot/loader/loader.conf
default 4.7.0
timeout 4
editor  0
```
and `reboot`!

Here is the current [.config](kernel/.config) file I use for your reference.

### WiFi

#### wlp3s0

As explained in
[Arch MacBook wiki](https://wiki.archlinux.org/index.php/MacBook#WiFi),
there is
[broadcom-wl-dkms AUR](https://aur.archlinux.org/packages/broadcom-wl-dkms/)
for `wl` driver.

Let's first get `git`, `dkms`, and `fakeroot` through pacman

```
air$ sudo pacman -S git dkms fakeroot
```

clone the `broadcom-wl-dkms` repo and `makepkg`

```
air$ git clone https://aur.archlinux.org/broadcom-wl-dkms
```
```
air$ cd broadcom-wl-dkms/
air$ makepkg -f
```

Then, just install the self-build package with `pacman`

```
air$ sudo pacman -U broadcom-wl-dkms-6.30.223.271-8-x86_64.pkg.tar.xz
loading packages...
warning: broadcom-wl-dkms-6.30.223.271-8 is up to date -- reinstalling
resolving dependencies...
looking for conflicting packages...

Packages (1) broadcom-wl-dkms-6.30.223.271-8

Total Installed Size:  7.66 MiB
Net Upgrade Size:      0.00 MiB

:: Proceed with installation? [Y/n] y
(1/1) checking keys in keyring                       [###########################] 100%
(1/1) checking package integrity                     [###########################] 100%
(1/1) loading package files                          [###########################] 100%
(1/1) checking for file conflicts                    [###########################] 100%
(1/1) checking available disk space                  [###########################] 100%
:: Running pre-transaction hooks...
(1/1) Remove DKMS modules
==> No kernel 4.6.4-1-ARCH headers. You must install them to use DKMS!
==> dkms remove -m broadcom-wl -v 6.30.223.271 -k 4.7.0.1
Error! There are no instances of module: broadcom-wl
6.30.223.271 located in the DKMS tree.
:: Processing package changes...
(1/1) reinstalling broadcom-wl-dkms                  [###########################] 100%

To load the new module, run as root:

  rmmod b43 b43legacy ssb bcm43xx brcm80211 brcmfmac brcmsmac bcma wl
  modprobe wl

or just reboot the system.

:: Running post-transaction hooks...
(1/1) Install DKMS modules
==> No kernel 4.6.4-1-ARCH headers. You must install them to use DKMS!
==> dkms install -m broadcom-wl -v 6.30.223.271 -k 4.7.0.1
```

Just do `sudo modprobe wl` then boom, you have `wlp3s0` on air!

```
air$ sudo modprobe wl
air$ ip l show wlp3s0
3: wlp3s0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 08:6d:41:bc:2d:1c brd ff:ff:ff:ff:ff:ff
```

#### WPA

Install `wpa_supplicant` with `pacman`

```
air$ sudo pacman -S wpa_supplicant
```

and run it with your config, say

```
air$ sudo wpa_supplicant -B -c your_wpa_config -i wlp3s0
```

then you get the link up!

```
air$ ip a show wlp3s0
3: wlp3s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:6d:41:bc:2d:1c brd ff:ff:ff:ff:ff:ff
    inet6 fe80::a6d:41ff:febc:2d1c/64 scope link
       valid_lft forever preferred_lft forever
```

Run DHCP, say with `systemctl`

```
air$ sudo systemctl start dhcpcd@wlp3s0
```

and you got the IP over the air!

#### wifi-menu

`wifi-menu` is a good to have app, to automatically look for the available
wifi, which helps especially at public WiFi.  The main app is available
but you need to install `dialog` package to make it work.

```
air$ sudo pacman -S dialog
```

Then, you just run `air$ sudo wifi-menu` to look for the available wireless.

### Video

Let's install `xf86-video-intel`, as we have Intel GPU

```
air$ lspci | grep VGA
00:02.0 VGA compatible controller: Intel Corporation HD Graphics 6000 (rev 09)
```

```
air$ sudo pacman -S xf86-video-intel
```

### Screen backlight

You can change the backlight through `/sys/class/backlight/intel_backlight/brightness` as

```
air$ sudo bash -c 'tee /sys/class/backlight/intel_backlight/brightness <<< 700'
```

you can check the maximum backlight brightness through
`cat /sys/class/backlight/intel_backlight/max_brightness`

### X

Install X server and related packages

```
air$ sudo pacman -S xorg-server xorg-xinit xorg-xsetroot
...
```

pick mesa-libgl, as a LibGL library

```
resolving dependencies...
:: There are 4 providers available for libgl:
:: Repository extra
   1) mesa-libgl  2) nvidia-304xx-libgl  3) nvidia-340xx-libgl  4) nvidia-libgl

   Enter a number (default=1): 1
```
pick the option #2, `xf86-input-libinput`.  This is needed for the natural
scrolling, which I touch up on later.

```
:: There are 2 providers available for xf86-input-driver:
:: Repository extra
   1) xf86-input-evdev  2) xf86-input-libinput

   Enter a number (default=1): 2
```

### Window manager

As WM is more of based on the personal preference, please skip this
section if you use something different.  I use [dwm](http://dwm.suckless.org/)
these days, for their simplicity and the ease of use.

Install some X libraries and the stuff, first

```
air$ sudo pacman -S libxft libxinerama pkg-config
```

then, clone the latest `dwm`

```
air$ git clone http://git.suckless.org/dwm
```

and `make && sudo make install`

```
air$ cd dwm
air$ make && sudo make install
```

I do the same, too, for [st](http://st.suckless.org) and
[dmenu](http://dmenu.suckless.org) from [suckless](http://suckless.org).

### Key mapping

I can't live without this on X

```
air$ cat /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
	MatchIsKeyboard "on"
	# Left caps lock to ctrl key.
	Option "XkbOptions" "ctrl:nocaps,altwin:swap_alt_win"
EndSection
```

### Fonts

At this point, I'm with `ttf-freefont`, as it's simple and clean, and have
`free` in the name.

```
air$ sudo pacman -S ttf-freefont
```

### Natural Scrolling

#### USB mouse

I don't think I can go back to the old way anymore.

Let's install `xinput` through `pacman`

```
air$ sudo pacman -S xorg-xinput
```

and then, find the mouse, get the propety number and set


```
air$ xinput | grep -i mouse
_   _ Mitsumi Electric Apple Optical USB Mouse  id=12   [slave  pointer  (2)]
air$ xinput list-props 12 | grep -i natural
	libinput Natural Scrolling Enabled (283):       0
	libinput Natural Scrolling Enabled Default (284):       0
air$ xinput set-prop 12 283 1
```

#### Touchpad

Let's install synaptics, just for the natural scrolling.

```
air$ sudo pacman -S xf86-input-synaptics
```

and put the following file under `/etc/X11/xorg.conf.d`

```
air$ cat /etc/X11/xorg.conf.d/70-synaptics.conf
Section "InputClass"
        Identifier "touchpad"
	Driver "synaptics"
	MatchIsTouchpad "on"
		Option "VertScrollDelta" "-111"
		Option "HorizScrollDelta" "-111"
EndSection
```

Here is the [one](https://github.com/keinohguchi/arch-on-air/blob/master/xorg.conf.d/70-synaptics.conf)
 I use for synaptics.

### Power

Install `acpi` ACPI client package to retrieve a current battery life

```
air$ sudo pacman -S acpi
```

You can get the current buttery status with `acpi -b`.  I set it up
in `.xinitrc` to periodically check the status

```
while true
do
  xsetroot -name "$(acpi -b),$(date +%l:%M%P)"
  sleep 1m
done &
```

[TLP](https://wiki.archlinux.org/index.php/TLP), Linux Advanced Power Managemnt
Tool, for suspend/sleep.  I'll come back here, once I explore that.  Yep,
I just shutdown/start when I'm done.  Hey, we're in a SSD era, buddy. :)

### Bluetooth

Install `bluez` and `bluez-utils` as explained in
[ArchLinux bluetooth guide](https://wiki.archlinux.org/index.php/Bluetooth).

```
air$ sudo pacman -S bluez bluez-utils
```

Now, let's start `bluetooth.service` through `systemctl`

```
air$ sudo systemctl start bluetooth
```

First of all, let's become `lp` group so that you can omit
`sudo` when you run `bluetoothctl`.  Then follow the steps
below to connect your mighty mouse.

```
air$ bluetoothctl
[NEW] Controller 08:6D:41:BC:2D:1D air [default]
[bluetooth]# power on
[CHG] Controller 08:6D:41:BC:2D:1D Class: 0x10010c
Changing power on succeeded
[CHG] Controller 08:6D:41:BC:2D:1D Powered: yes
[bluetooth]# scan on
Discovery started
[CHG] Controller 08:6D:41:BC:2D:1D Discovering: yes
[NEW] Device 04:4B:ED:D0:66:4F mm2
[bluetooth]# pair 04:4B:ED:D0:66:4F
Attempting to pair with 04:4B:ED:D0:66:4F
[CHG] Device 04:4B:ED:D0:66:4F Connected: yes
[CHG] Device 04:4B:ED:D0:66:4F UUIDs: 00001124-0000-1000-8000-00805f9b34fb
[CHG] Device 04:4B:ED:D0:66:4F UUIDs: 00001200-0000-1000-8000-00805f9b34fb
[CHG] Device 04:4B:ED:D0:66:4F Paired: yes
Pairing successful
[mm2]#
```

Cool!  Let's mighty mouse! :)

### Browser

I'm big fan of [surf](http://surf.suckless.org) but am forced to use
chromium these days...

#### surf

Install `xorg-xprop`, `gtk3`, and `webkitgtk2` through `pacman`

```
air$ sudo pacman -S xorg-xprop gtk3 webkitgtk2
```

then, clone the latest `surf`

```
air$ git clone http://git.suckless.org/surf
```

and `make && sudo make install`

```
air$ cd surf
air$ make && sudo make install
```

#### chromium

I'm just lazy that I usually use `pacman` for `chromium`

```
air$ sudo pacman -S chromium
```

And I usually install [Vimium](https://chrome.google.com/webstore/detail/vimium/dbepggeogbaibhgnhhndojpepiihcmeb?hl=en)
extension for Vim key binding.

### Slack

There is a native [Slack](https://slack.com) app, `slack-desktop` on
[AUR](https://aur.archlinux.org/packages/slack-desktop/), but I usually use
normal browser.  Both surf as well as chromium work just like a native app.

You can also setup [IRC gateway](https://get.slack.help/hc/en-us/articles/201727913-Connecting-to-Slack-over-IRC-and-XMPP),
so that you can slack through IRC client, e.g. `irssi`.

### Audio

Let's install
[PulseAudio](https://wiki.archlinux.org/index.php/PulseAudio) and
[ALSA utils](https://wiki.archlinux.org/index.php/Advanced_Linux_Sound_Architecture#Installation),
Advanced Linux Sound Architecture,
through `pacman`:

```
air$ sudo pacman -S pulseaudio alsa-utils
```

We'll use analog PCH device as a default device, as HDMI device doesn't
work somehow.

```
air$ aplay -l
**** List of PLAYBACK Hardware Devices ****
card 0: HDMI [HDA Intel HDMI], device 3: HDMI 0 [HDMI 0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 0: HDMI [HDA Intel HDMI], device 7: HDMI 1 [HDMI 1]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 0: HDMI [HDA Intel HDMI], device 8: HDMI 2 [HDMI 2]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 1: PCH [HDA Intel PCH], device 0: CS4208 Analog [CS4208 Analog]
  Subdevices: 0/1
  Subdevice #0: subdevice #0
```

I use the [~/.asoundrc](https://github.com/keinohguchi/home/blob/master/.asoundrc)
file to set the default device, as explained in
[ArchLinux wiki](https://wiki.archlinux.org/index.php/Advanced_Linux_Sound_Architecture#Alternative_method):

```
air$ cat ~/.asoundrc
pcm.!default {
        type hw
        card PCH
}

ctl.!default {
        type hw
        card PCH
}
```

Let's check the audio by watching
[youtube](https://www.youtube.com/watch?v=tnSkHhsLqpM) video.

You can change the volume mute/unmute through `amixer` or `alsamixer`
as explained in [ArchLinux wiki](https://wiki.archlinux.org/index.php/Advanced_Linux_Sound_Architecture#Unmuting_the_channels):

Unmute the sound

```
air$ amixer sset Master unmute
Simple mixer control 'Master',0
  Capabilities: pvolume pvolume-joined pswitch pswitch-joined
  Playback channels: Mono
  Limits: Playback 0 - 127
  Mono: Playback 104 [82%] [-11.50dB] [on]
```

and mute the sound!

```
air$ amixer sset Master mute
Simple mixer control 'Master',0
  Capabilities: pvolume pvolume-joined pswitch pswitch-joined
  Playback channels: Mono
  Limits: Playback 0 - 127
  Mono: Playback 104 [82%] [-11.50dB] [off]
```

### Facetime HD

As explained in
[ArchLinux wiki](https://wiki.archlinux.org/index.php/MacBook#Facetime_HD),
[bcwc_pcie driver](https://github.com/patjak/bcwc_pcie) is the one to make
our Facetime HD up and running.  Let's make it work as explained in
their [wiki](https://github.com/patjak/bcwc_pcie/wiki/Get-Started#get-started-on-arch).

First, install `cpio` package through `pacman`

```
air$ sudo pacman -S cpio
```

Now, clone the [bcwc_pcie driver](https://github.com/patjak/bcwc_pcie)
package and download the firmware, as explained in their wiki

```
git clone https://github.com/patjak/bcwc_pcie.git
air$ cd bcwc_pcie/firmware
air$ make

Checking dependencies for driver download...
/usr/bin/curl
/usr/bin/xzcat
/usr/bin/cpio

Downloading the driver, please wait...


Found matching hash from OS X, El Capitan 10.11.3
==> Extracting firmware...
--> Decompressing the firmware using gzip...
--> Deleting temporary files...
--> Extracted firmware version 1.43.0

air$ ls -F
AppleCameraInterface*  Makefile  debian/  extract-firmware.sh*  firmware.bin
```

Then, install the driver into `/usr/lib/firmware` with `sudo make install`

```
air$ sudo make install
Copying firmware into '//usr/lib/firmware/facetimehd'
```

Load the `facetimehd` with `modprobe`

```
air$ sudo depmod
air$ sudo modprobe facetimehd
```

Now, `make && sudo make install` under `bcwc_pcie` directory

```
air$ cd ..
air$ make && sudo make install
```

If it's not up and running, do [sudo modprobe -r bdc_pci](https://github.com/patjak/bcwc_pcie/wiki/Get-Started#devvideo-not-created).

### Google hangouts

Once you make both [Audio](#audio) and [Facetime HD](#facetime-hd) up and
running, [google hangouts](http://hangouts.google.com/) are up and running.

Enjoy hangouting!

### Zoom

There is a [AUR](https://aur.archlinux.org/packages/zoom/) package.  Just
download the snapshot, `makepkg -f`, and do `sudo pacman -U` to get `zoom`
up and running.

But before that, let's resolve the dependency by install those by `pacman`.

```
air$ sudo pacman -S qt5-webengine gstreamer0.10-base qt5-svg
```

```
air$ tar xvfz zoom.tar.gz
zoom/
zoom/.SRCINFO
zoom/PKGBUILD
```

`makepkg`

```
air$ cd zoom
air$ makepkg -f
```

and `pacman -U`

```
air$ sudo pacman -U zoom-2.0.63547.0830-1-x86_64.pkg.tar.xz
```

Happy zooming!

> Note that please grab `0830` version or above for the screen sharing!

### Vagrant/VirtualBox

Good to have Vagrant/VirtualBox handy for some quick check on different
distro/OS.  Both of them are provided through the `pacman`.

```
air$ sudo pacman -S virtualbox vagrant
```

### KVM

#### libvirt

I love *KVM* and *OVS* based virtualization through *libvirt* on Linux
because of their simplicity and performance.  Here is the basic steps to
make your KVM up and running under libvirt on your Arch:

```
air$ sudo pacman -S qemu libvirt
```

Now, you're ready to run KVM based virtual machines through the libvirt.
Let's run those services through `systemd`:

```
air$ sudo systemctl start libvirtd
air$ sudo systemctl start virtlogd
```

You can also make it startup daemons by using the `enable` subcommand:

```
air$ sudo systemctl enable libvirtd
air$ sudo systemctl enable virtlogd
```

Now, add yourself to the `libvirt` group

```
air$ sudo usermod -a -G libvirt admin
air$ su admin
Password:
air$ id
uid=1000(admin) gid=10(wheel) groups=10(wheel),995(libvirt),996(git)
```

#### KVM in KVM

As explained in
[ArchLinux KVM wiki](https://wiki.archlinux.org/index.php/KVM#Nested_virtualization),
you can do KVM in KVM by doing below:

```
air$ sudo modprobe -r kvm_intel
air$ sudo modprobe kvm_intel nested=1
air$ sudo systool -m kvm_intel -v | grep ne
sted
    nested              = "Y"
air$
```

Make it persistent by adding it to the `/etc/modprobe.d/modprobe.conf`

```
air$ cat /etc/modprobe.d/modprobe.conf
options kvm_intel nested=1
```

#### Storage pool

As we allocate separate partition for storage pool before, let's define
the *volume group* as a new *storage pool*:

```
air$ sudo virsh pool-define-as images logical - - /dev/sda5 vg1
air$ sudo virsh pool-build images
air$ sudo virsh pool-start images
```

now, we setup the storage pool for VM images

```
virsh # pool-info images
Name:           images
UUID:           d67d0287-6cbd-4584-91f5-8d76fb971b58
State:          running
Persistent:     yes
Autostart:      no
Capacity:       125.71 GiB
Allocation:     0.00 B
Available:      125.71 GiB
```

Check it through the *LVM* command line tool, *vgs*

```
air$ sudo vgs
VG  #PV #LV #SN Attr   VSize   VFree
vg0   1   3   0 wz--n- 160.00g      0
vg1   1   0   0 wz--n- 125.71g 125.71g
air$
```

Now, make it run by default.

```
air$ sudo virsh pool-autostart images
```

#### Volumes

As we setup a storage pool, we can finally create a storage volumes
for the guest OS:

```
air$ sudo virsh vol-create-as images hv0 20G --format qcow2 --allocation 0
```

Cool, now let's check it both from `virsh` as well as `lvs`

```
virsh # vol-info --pool images hv0
Name:           hv0
Type:           block
Capacity:       20.00 GiB
Allocation:     4.00 MiB
```

```
air$ sudo lvs
  LV   VG  Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  home vg0 -wi-ao---- 64.00g
  root vg0 -wi-ao---- 32.00g
  var  vg0 -wi-ao---- 64.00g
  hv0  vg1 -wi-a----- 20.00g
```

#### Network

We'll use the default Linux kernel bridge, just because, as of August 2016,
Open vSwitch [doesn't support *NAT mode* for libvirt networking](http://openvswitch.org/support/dist-docs/INSTALL.Libvirt.md.html).

We'll install those packages through `pacman` so that KVM guests will get
the IP address through the DHCP.

```
air$ sudo pacman -S ebtables dnsmasq
```

Let's restart `libvirtd` to make the change affected, so that the default
network will up and running

```
air$ sudo systemctl restart libvirtd
```

Let's check it with `virsh net-dumpxml` command

```
air$ sudo virsh net-dumpxml default
<network>
  <name>default</name>
  <uuid>bb24f0ba-754c-4f00-b16b-5e7dbb35807e</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='mgmt' stp='off' delay='0'/>
  <mac address='00:00:bb:00:00:00'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.129' end='192.168.122.254'/>
      <host mac='00:00:bb:14:04:00' ip='192.168.122.129'/>
      <host mac='00:00:bb:16:04:00' ip='192.168.122.130'/>
    </dhcp>
  </ip>
</network>
```

#### Guest OS

Install the guest OS installer package, called `virt-install` as well as
VNC client package, `tigervnc`, through `pacman`:

```
air$ sudo pacman -S virt-install tigervnc
```

Once you download the OS, let's install it through headlless
by `virt-install` as below:

```
air$ sudo virt-install -n hv0 --memory 2048 --vcpus 1 --hvm --cpu host,require=vmx --virt-type kvm --cdrom /var/lib/libvirt/boot/ubuntu-16.04.1-server-amd64.iso --disk /dev/vg1/hv0 --graphics vnc
Starting install...
Creating domain...                                          |    0 B  00:00
Domain installation still in progress. Waiting for installation to complete.
```

where `--cpu require=vmx` is important to provide the nested KVM feature
inside the guest OS.

Check the IP address and the port to connect to the new guest OS by
`virsh vncdisplay hv0`:

```
air$ sudo virsh vncdisplay hv0
127.0.0.1:0
```

Let's connect to the guest and finish it up the work!

```
air$ vncviewer 127.0.0.1
```

### Open vSwitch

#### Build

Let's compile, instead of installing it through `pacman`, for fun!

```
air$ git clone git@github.com:openvswitch/ovs
```

Install autotools, if you haven't done that.

```
air$ sudo pacman -S m4 automake autoconf
```

As of Summer 2016, [*OVS* code is not ready *python2* yet](https://github.com/openvswitch/ovs/blob/master/INSTALL.md#installation-requirements) and,
as Arch has been shifted to *python3* as the default *python* long time ago,
you need to hack around it to make it work.  Here is one way of doing
it, as explained on
[ArchLinux wiki](https://wiki.archlinux.org/index.php/Python#Python_2):

```
air$ mkdir -p ~/bin
air$ ln -s /usr/bin/python2 ~/bin/python
air$ ln -s /usr/bin/python2-config ~/bin/python-config
air$ export PATH=~/bin:$PATH
```

Cool!  Now, we're ready to compile and it's really easy just like *1-2-3*
as explained in
[INSTALL.md](https://github.com/openvswitch/ovs/blob/master/INSTALL.md).

```
air$ ./boot.sh
air$ ./configure
air$ make && sudo make install
```

Load the kernel module and build the *OVSDB* database, as explained in
[INSTALL.md](https://github.com/openvswitch/ovs/blob/master/INSTALL.md#building-the-sources).

#### Initialize

```
air$ sudo modprobe openvswitch
air$ modinfo openvswitch
filename:       /lib/modules/4.7.0.1/kernel/net/openvswitch/openvswitch.ko.gz
license:        GPL
description:    Open vSwitch switching datapath
depends:        nf_conntrack,nf_nat,libcrc32c,nf_nat_ipv6,nf_nat_ipv4,nf_defrag_ipv6
intree:         Y
vermagic:       4.7.0.1 SMP preempt mod_unload modversions
air$
```

and build the initial *OVSDB database* based off on the OVS
[schema](https://github.com/openvswitch/ovs/blob/master/vswitchd/vswitch.ovsschema)

```
air$ pwd
/usr/local/git/ovs
air$ sudo ovsdb-tool create /usr/local/etc/openvswitch/conf.db vswitchd/vswitch.ovsschema
air$ ls -l /usr/local/etc/openvswitch/conf.db
-rw-r--r-- 1 root root 12964 Aug 10 09:45 /usr/local/etc/openvswitch/conf.db
```

#### Run

Let's run `ovsdb-server`, the OVS database server, and the `ovs-vswitchd`,
vswitch itself, as explained in [INSTALL.md](https://github.com/openvswitch/ovs/blob/master/INSTALL.md#startup).

```
air$ sudo ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock --pidfile
```

and initialize the database through `ovs-vsctl` for the first time.

```
air$ sudo ovs-vsctl --no-wait init
```

and then run the `ovs-vswitchd`

```
air$ sudo ovs-vswitchd --pidfile
```

Let's create a simple L2 switch with `ovs-vsctl` called *sw0*:

```
air$ sudo ovs-vsctl add-br sw0
```

and edit libvirt XML file for the VMs to attach to that bridge:

```
air$ sudo virsh dumpxml hv0 | grep -A 10 "interface type='bridge'"
<interface type='bridge'>
  <mac address='00:00:00:14:04:00'/>
  <source bridge='sw0'/>
  <virtualport type='openvswitch'>
    <parameters interfaceid='e4aedd4d-c540-403b-96ad-0a9592a1d41c'/>
  </virtualport>
  <target dev='vnet3'/>
  <model type='virtio'/>
  <alias name='net1'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
</interface>
```

and same for *hv1*

```
air$ sudo virsh dumpxml hv1 | grep -A 10 "interface type='bridge'"
<interface type='bridge'>
  <mac address='00:00:00:16:04:00'/>
  <source bridge='sw0'/>
  <virtualport type='openvswitch'>
    <parameters interfaceid='7ffe491d-ecbb-4496-9224-ccffb865c14d'/>
  </virtualport>
  <target dev='vnet1'/>
  <model type='virtio'/>
  <alias name='net1'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
</interface>
```

Once you `sudo virsh start hv0` and `sudo virsh start hv1`, those guests are
connected through the `sw0` OvS switch, as shown below.

```
air$ sudo ovs-vsctl show
a86d4283-5862-428a-8576-f39646655c5f
    Bridge "br0"
        Port "br0"
            Interface "br0"
                 type: internal
        Port "vnet1"
            Interface "vnet1"
        Port "vnet3"
            Interface "vnet3"
```

Once you assign the IP address inside the VM, you can make a IP reachability.

Happy Hacking!
