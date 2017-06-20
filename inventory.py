#!/usr/bin/env python

import os
import json
import argparse
import subprocess
import sys
import libvirt

def main():
    inventory = {'all': {'hosts': [],
                         'vars': {'ansible_user': os.environ['USER']}}}
    inventory['host'] = {'hosts': ['localhost'],
                         'vars': {'ansible_python_interpreter':
                                  '/usr/bin/python2'}}
    inventory['guest'] = guests()

    hostvars = {}
    for type in ['guest']:
        for host in inventory[type]['hosts']:
            inventory['all']['hosts'].append(host)
            hostvars[host] = {'name': host}

    # noqa https://github.com/ansible/ansible/commit/bcaa983c2f3ab684dca6c2c2c8d1997742260761
    inventory['_meta'] = {'hostvars': hostvars}

    parser = argparse.ArgumentParser(description="KVM inventory")
    parser.add_argument('--list', action='store_true',
                        help="List KVM inventory")
    parser.add_argument('--host', help='List details of a KVM inventory')
    args = parser.parse_args()

    if args.list:
        print(json.dumps(inventory))
    elif args.host:
        print(json.dumps(hostvars.get(args.host, {})))

def guests():
    c = libvirt.openReadOnly("qemu:///system")
    if c == None:
        print 'Failed to open connection to the hypervisor'
        sys.exit(1)

    guests = {'hosts': []}
    for i in c.listDomainsID():
        dom = c.lookupByID(i)
        guests['hosts'].append(dom.name())

    return guests


if __name__ == "__main__":
    main()
