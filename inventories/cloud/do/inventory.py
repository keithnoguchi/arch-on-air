#!/usr/bin/env python

import json
import argparse
import subprocess


def main():
    inventory = {'all': {'hosts': [], 'vars': {'ansible_user': 'root'}}}

    inventory['cloud'] = cloud(1)

    hostvars = {}
    for type in ['cloud']:
        for host in inventory[type]['hosts']:
            inventory['all']['hosts'].append(host)
            hostvars[host] = {'name': host}

    # noqa https://github.com/ansible/ansible/commit/bcaa983c2f3ab684dca6c2c2c8d1997742260761
    inventory['_meta'] = {'hostvars': hostvars}

    parser = argparse.ArgumentParser(description="DO droplet inventory")
    parser.add_argument('--list', action='store_true',
                        help="List DO droplet inventory")
    parser.add_argument('--host', help='List details of a droplet')
    args = parser.parse_args()

    if args.list:
        print(json.dumps(inventory))
    elif args.host:
        print(json.dumps(hostvars.get(args.host, {})))


def cloud(number):
    cloud = {'hosts': [],
             'vars': {'ansible_python_interpreter': '/usr/bin/python'}}
    for i in range(number):
        name = "cloud%d" % i
        proc = subprocess.Popen("cd inventories/cloud/do; terraform output %s_public_ipv4" % name,
                                shell=True, stdout=subprocess.PIPE)
        address = proc.stdout.read().strip('\n')
        cloud['hosts'].append(address)

    return cloud


if __name__ == '__main__':
    main()
