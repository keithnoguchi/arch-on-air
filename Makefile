SUDO ?= sudo
all: ansible ping
	ansible-playbook -vvv main.yml -e latest=true -c local \
		-e travis_ci=true -e gitsite=https://github.com/
.PHONY: main provision x game hack ansible ping clean
main provision x game hack:
	@ansible-playbook $@.yml -e latest=true
ansible:
	git clone https://github.com/ansible/ansible .ansible
	cd .ansible \
		&& $(SUDO) pip install -r requirements.txt \
		&& $(SUDO) python setup.py install 2>&1 > /dev/null
ping:
	ansible -vvv -m ping -i inventory.ini -c local host
clean:
	$(SUDO) $(RM) -rf .ansible
	$(RM) *.bak *.retry .*.sw? **/.*.sw?
