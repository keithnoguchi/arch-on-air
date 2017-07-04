all: provision guest

.PHONY: provision guest
provision guest:
	@ansible-playbook $@.yml -e latest=true

# those are the target primarily used by the travis CI through .travis.yml.
.PHONY: ansible-arch ansible-ubuntu ping test test-guest
ansible-arch: clean
	git clone https://github.com/ansible/ansible .ansible
	cd .ansible \
		&& sudo pip2 install -r requirements.txt \
		&& sudo python2 setup.py install

ansible-ubuntu: clean
	git clone https://github.com/ansible/ansible .ansible
	cd .ansible \
		&& sudo pip install -r requirements.txt \
		&& sudo python setup.py install

ping:
	ansible -vvv -m ping -i inventory.test -c local host

test: ansible-arch ping
	ansible-playbook -vvv -i inventory.test -c local provision.yml \
		-e travis_ci=true -e latest=true \
		-e gitsite=https://github.com/

test-guest: ansible-ubuntu ping
	ansible-playbook -vvv guest.yml -e latest=true \
		-i inventory.test -c local -e travis_ci=true \
		-e gitsite=https://github.com/

clean:
	sudo $(RM) -rf .ansible
	$(RM) *.bak *.retry .*.sw? **/.*.sw?
