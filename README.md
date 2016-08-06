# Arch-on-Air

Yet another note on *Let's make ArchLinux up and running on MacBook Air!*

Thie is my way of running *Arch* on *Air*, based on the official
[ArchLinux on MacBook(Air)](https://wiki.archlinux.org/index.php/MacBook) wiki.

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

I follow the officieal [Arch Installation guide](https://wiki.archlinux.org/index.php/installation_guide) section format, so that I don't have to think about the order. :)

## Pre-installation

## Dual booting

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

##### Phisical volumes

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

## Installation

### Configure the system

### Install the base packages

### Configure the system

### Install the boot loader

## Post-installation

### Video

### Audio

### Bluetooth

### WiFi

### X

### Touchpad

### Natural Scrolling
