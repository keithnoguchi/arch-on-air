all: host guest

.PHONY: host guest provision hack
host guest provision hack:
	@ansible-playbook $@.yml -e latest=true

# those are the target primarily used by the travis CI through .travis.yml.
.PHONY: ansible-arch ansible-ubuntu ping test test-guest
ansible-arch: clean
	git clone https://github.com/ansible/ansible .ansible
	cd .ansible \
		&& sudo pip2 install -r requirements.txt \
		&& sudo python2 setup.py install 2>&1 > /dev/null

ansible-ubuntu: clean
	git clone https://github.com/ansible/ansible .ansible
	cd .ansible \
		&& sudo pip install -r requirements.txt \
		&& sudo python setup.py install 2>&1 > /dev/null

ping:
	ansible -vvv -m ping -i inventories/test/inventory.ini -c local host

test: ping
	ansible-playbook -vvv host.yml -e latest=true \
		-i inventories/test/inventory.ini -c local -e travis_ci=true \
		-e gitsite=https://github.com/

test-guest: ansible-ubuntu ping
	ansible-playbook -vvv guest.yml -e latest=true \
		-i inventories/test/inventory.ini -c local -e travis_ci=true \
		-e gitsite=https://github.com/

clean:
	sudo $(RM) -rf .ansible
	$(RM) *.bak *.retry .*.sw? **/.*.sw?
