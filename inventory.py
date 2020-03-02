#!/usr/bin/env python

import os
import json
import argparse
import subprocess
import sys
import libvirt

guest_management_network = '172.31.255'
guest_network_gateway = '172.30.255.254'
guest_network_prefixlen = 16


def main():
    inventory = {'all': {'hosts': [],
                         'vars': {'ansible_user': os.environ['USER']}}}
    inventory['host'] = {'hosts': ['localhost'],
                         'vars': {'ansible_connection': 'local',
                                  'guest_management_network': guest_management_network,
                                  'guest_network_address': guest_network_gateway,
                                  'guest_network_gateway': guest_network_gateway,
                                  'guest_network_prefixlen': guest_network_prefixlen}}
    inventory['guest'] = guest()

    hostvars = {}
    for type in ['guest']:
        for host in inventory[type]['hosts']:
            num = int(''.join(filter(str.isdigit, host)))
            inventory['all']['hosts'].append(host)
            hostvars[host] = {'name': host,
                              'guest_network_address': '172.30.255.%d' % num}

    # https://github.com/ansible/ansible/commit/bcaa983c2f3ab684dca6c2c2c8d1997742260761
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


def guest():
    nodes = {'hosts': [],
             'vars': {'guest_management_network': guest_management_network,
                      'guest_network_address': guest_network_gateway,
                      'guest_network_gateway': guest_network_gateway,
                      'guest_network_prefixlen': guest_network_prefixlen}}

    c = libvirt.openReadOnly("qemu:///system")
    if c != None:
        for i in c.listDomainsID():
            dom = c.lookupByID(i)
            if dom.name().startswith('arch') == True:
                nodes['hosts'].append(dom.name())

    return nodes


if __name__ == "__main__":
    main()
