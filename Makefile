# SPDX-License-Identifier: GPL-2.0
SUDO   ?= sudo
GITURL ?= "git@github.com:"
.PHONY: all ls list
all:
	@ansible-playbook -vvv main.yaml -e latest=true -c local \
		-e gitsite=$(GITURL)
%:
	@ansible-playbook $*.yaml -e latest=true \
		-e gitsite=$(GITURL)
ls list:
	@$(SUDO) virsh net-list
	@$(SUDO) virsh list

# Hypervisor related playbook.  Please refer to HV.md for more detail.
.PHONY: host guest
host guest:
	@ansible-playbook -vvv $@.yaml -i inventory.py -e latest=true \
		-e gitsite=$(GITURL)

.PHONY: clean ansible
clean:
	$(SUDO) $(RM) -rf .ansible
	$(RM) *.bak *.retry .*.sw? **/.*.sw?

ansible:
	git clone https://github.com/ansible/ansible .ansible
	cd .ansible \
		&& $(SUDO) pip install -r requirements.txt \
		&& $(SUDO) python setup.py install 2>&1 > /dev/null
ping-%:
	ansible -vvv -m ping -i inventory.ini -c local $*.yaml

# CI targets
.PHONY: ci-all
ci-all: ci-main
ci-%: ping-%
	ansible-playbook -vvv $*.yaml -i inventory.ini -c local \
		-e ci=true -e gitsite=https://github.com/
