# SPDX-License-Identifier: GPL-2.0
SUDO   ?= sudo
GITURL ?= "git@github.com:"
all:
	ansible-playbook -vvv main.yaml -e latest=true -c local \
		-e gitsite=$(GITURL)
%:
	@ansible-playbook $*.yaml -e latest=true \
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
ci-%: ping-%
	ansible-playbook -vvv $*.yaml -i inventory.ini -c local \
		-e ci=true -e gitsite=https://github.com/
