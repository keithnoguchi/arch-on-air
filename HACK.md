# Let's hack!

Let's hack the virtualization on Air!

- [KVM/Libvirt](#kvm-libvirt)
- [Open vSwitch](#open-vswitch)
- [Docker](#docker)
- [Configuration Management Tools](#configuration-management-tools)
- [Vagrant/VirtualBox](#vagrant-virtualbox)

## KVM/Libvirt

### libvirt

I love *KVM* and *OvS* based virtualization through *libvirt* on Linux
because of their simplicity and performance.  Here is the basic steps to
make your KVM up and running under libvirt on your Arch:

```
air$ sudo pacman -S qemu-headless libvirt
```

Before running the libvirtd, let's add her to the `kvm` group
through `/etc/libvirt/qemu.conf

```
air$ grep '^group' /etc/libvirt/qemu.conf
group="kvm"
```

Now, you're ready to run KVM based virtual machines through the libvirt.
Let's run those services through `systemd`:

```
air$ sudo systemctl start libvirtd
air$ sudo systemctl start virtlogd
```

You can also make it startup daemons by using the `enable` sub command:

```
air$ sudo systemctl enable libvirtd
air$ sudo systemctl enable virtlogd
```

You can add yourself to the `libvirt` group

```
air$ sudo usermod -a -G libvirt $USER
air$ su $USER
Password:
air$ id
uid=1000($USER) gid=10(wheel) groups=10(wheel),995(libvirt),996(git)
```

### KVM in KVM

As explained in
[ArchLinux KVM wiki](https://wiki.archlinux.org/index.php/KVM#Nested_virtualization),
you can do KVM in KVM by doing below:

```
air$ sudo modprobe -r kvm_intel
air$ sudo modprobe kvm_intel nested=1
air$ sudo systool -m kvm_intel -v | grep nested
    nested              = "Y"
air$
```

Make it persistent by adding it to the `/etc/modprobe.d/modprobe.conf`

```
air$ cat /etc/modprobe.d/modprobe.conf
options kvm_intel nested=1
```

### Storage pool

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

### Volumes

As we setup a storage pool, we can finally create a storage volumes
for the guest OS:

```
air$ sudo virsh vol-create-as images hv10 12G --format qcow2
```

Cool, now let's check it both from `virsh` as well as `lvs`

```
air$ sudo virsh vol-info hv10 images
Name:           hv10
Type:           block
Capacity:       12.00 GiB
Allocation:     12.00 GiB
```

```
air$ sudo lvs
  LV   VG  Attr       LSize  Pool Origin         Data%  Meta%  Move Log Cpy%Sync Convert
  home vg0 -wi-ao---- 32.00g
  root vg0 -wi-ao---- 32.00g
  var  vg0 -wi-ao---- 32.00g
  hv10 vg1 swi-a-s--- 12.00g
air$
```

### Network

We'll use the default Linux kernel bridge, just because, as of August 2016,
Open vSwitch [doesn't support *NAT mode* for libvirt networking](https://github.com/openvswitch/ovs/blob/master/Documentation/howto/libvirt.rst).

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
      <range start='192.168.122.64' end='192.168.122.254'/>
      <host mac='00:00:bb:16:04:10' ip='192.168.122.110'/>
      <host mac='00:00:bb:16:04:11' ip='192.168.122.111'/>
      <host mac='00:00:bb:16:04:12' ip='192.168.122.112'/>
      <host mac='00:00:bb:16:04:13' ip='192.168.122.113'/>
    </dhcp>
  </ip>
</network>
```

### Guest OS

Install the guest OS installer package, called `virt-install` as well as
VNC client package, `tigervnc`, through `pacman`:

```
air$ sudo pacman -S virt-install virt-viewer tigervnc
```

Let's install the guest, after downloading the image of your choise.  I usually play with [Ubuntu LTS](http://mirror.pnl.gov/releases/16.04.3/), just to see what they're up to. :)

```
air$ sudo virt-install --name hv10 --disk /dev/vg1/hv10 \
--cdrom /var/lib/libvirt/boot/ubuntu-16.04.3-server-amd64.iso \
--hvm --memory 2048 --cpu host,require=vmx --graphics vnc
Starting install...
Creating domain...
Domain installation still in progress. Waiting for installation to complete.
```

I've focus on the minimum required setup in the command line above, which
doesn't slow down the installation process.  Here is the break down:

1. `--name hv10`: Specify new guest name, e.g. `hv10`, a.k.a `-n`
2. `--disk /dev/vg1/hv10`: Specify the guest local hard disk.
3. `--cdrom /var/lib/...`: Specify the boot image (ISO), a.k.a `-c`
4. `--hvm`: Does hardware virtualization, a.k.a `-v` (*optional*)
5. `--memory 2048`: Allocate 2G of memory to the guest. (*optional*)
6. `--cpu host,require=vmx`: For KVM in KVM. (*optional*)
7. `--graphics vnc`: Use VNC for the installation process. (*optional*)

Out of all, `--cpu host,require=vmx` is the most important thing to remember,
if you're planing to run KVM inside your guest OS.

Check the IP address and the port to connect to the new guest OS by
`virsh vncdisplay hv10`:

```
air$ sudo virsh vncdisplay hv10
127.0.0.1:0
```

Let's connect to the guest and finish it up the work!

```
air$ vncviewer 127.0.0.1
```

#### Guest OS name resolution

You can setup your own name servers to take care of the name resolution
for all your guest OSes but if you're lazy, just like me, you can do the
simple way to take care of it through the `/etc/hosts` files, as show
below:

First setup guest network MAC address through `virsh edit` command:

```
air$ sudo virsh dumpxml hv10 | grep '04:10'
      <mac address='00:00:bb:16:04:10'/>
```

setup the libvirt network with the MAC to IP address mapping:

```
air$ sudo virsh net-dumpxml default | grep '04:10'
      <host mac='00:00:bb:16:04:10' ip='192.168.122.110'/>
```

and setup the host `/etc/hosts` file to do the name to address
resolution:

```
air$ grep hv10 /etc/hosts
192.168.122.110 hv10
air$
```

Now, you can ping with the shorter names, e.g. `hv10`, as below:

```
air$ ping -c2 hv10
PING hv10 (192.168.122.110) 56(84) bytes of data.
64 bytes from hv10 (192.168.122.110): icmp_seq=1 ttl=64 time=0.127 ms
64 bytes from hv10 (192.168.122.110): icmp_seq=2 ttl=64 time=0.187 ms

--- hv10 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1015ms
rtt min/avg/max/mdev = 0.127/0.157/0.187/0.030 ms
air$
```

## Open vSwitch

### Build

Let's compile, instead of installing it through `pacman`, for fun!

```
air$ git clone git@github.com:openvswitch/ovs
```

Install autotools, if you haven't done that.

```
air$ sudo pacman -S m4 automake autoconf
```

As of Summer 2016, [*OvS* code is not ready *python2* yet](https://github.com/openvswitch/ovs/blob/master/INSTALL.md#installation-requirements) and,
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
[intro/install/general.rst](https://github.com/openvswitch/ovs/blob/master/Documentation/intro/install/general.rst).

```
air$ ./boot.sh
air$ ./configure --with-linux=/lib/modules/$(uname -r)/build
air$ make && sudo make install
```

Load the kernel module and build the *OVSDB* database, as explained in
[intro/install/general.rst](https://github.com/openvswitch/ovs/blob/master/Documentation/intro/install/general.rst).

### Initialize

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

and build the initial *OVSDB database* based off on the OvS
[schema](https://github.com/openvswitch/ovs/blob/master/vswitchd/vswitch.ovsschema)

```
air$ pwd
/usr/local/git/ovs
air$ sudo ovsdb-tool create /usr/local/etc/openvswitch/conf.db vswitchd/vswitch.ovsschema
air$ ls -l /usr/local/etc/openvswitch/conf.db
-rw-r--r-- 1 root root 12964 Aug 10 09:45 /usr/local/etc/openvswitch/conf.db
```

### Run

Let's run `ovsdb-server`, the OvS database server, and the `ovs-vswitchd`,
vswitch itself, as explained in [intro/install/general.rst](https://github.com/openvswitch/ovs/blob/master/Documentation/intro/install/general.rst).

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

## Docker

Let's have docker for the containerized world, by following
[the official docker for ArchLinux](https://wiki.archlinux.org/index.php/Docker)
wiki:

```
air$ sudo pacman -S docker
```

and add yourself to `docker` group by:

```
air$ sudo usermod -a -G docker $USER
air$ su $USER
Password:
air$ id
uid=1000($USER) gid=10(wheel) groups=10(wheel),991(docker),995(libvirt),996(git)
```

now, you can execute `docker` client command without sudo:

```
air$ docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
air$
```

## Configuration Management Tools

I'm a big fan of configuration management tools, especially push based,
as [ansible](https://ansible.com) and [terraform](https://terraform.io)

### Ansible

You can install ansible through `pacman` but let's make it more fun by
installing it from the source:

Let's install `pip` so that we can take care of the python dependency
quick by `pip install -r requirements.txt`:

```
air$ sudo pacman -S python2-pip
```

Then checkout the source code from their [github repo](https://github.com/ansible/ansible):

```
air$ git clone git@github.com:ansible/ansible
```

As mentioned before, let's lay the foundation by `pip install -r` command:

```
air$ cd ansible
air$ sudo pip install -r requirements.txt
```

now, you're ready to build and install:

```
air$ python setup.py build
air$ sudo python setup.py install
```

Let's check if `ansible` command is up and running by
[ping](http://docs.ansible.com/ping_module.html) to localhost:

```
air$ ansible -m ping localhost
 [WARNING]: No inventory was parsed, only implicit localhost is available

 [WARNING]: provided hosts list is empty, only localhost is available

localhost | SUCCESS => {
    "changed": false,
    "failed": false,
    "ping": "pong"
}
air$
```

Welcome to the fun [ansible](https://ansible.com) world!

## Vagrant/VirtualBox

Good to have Vagrant/VirtualBox handy for some quick check on different
distro/OS.  Both of them are provided through the `pacman`.

```
air$ sudo pacman -S virtualbox vagrant
```

Happy Hacking!
