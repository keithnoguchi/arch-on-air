all: provision guest

.PHONY: provision guest
provision guest:
	@ansible-playbook $@.yml -e verbose=true -e latest=true

# ansible, ping, and test targets are for by the travis-ci through .travis.yml.
.PHONY: ansible ping test travis-ci
ansible: clean
	git clone https://github.com/ansible/ansible .ansible
	cd .ansible \
		&& sudo pip2 install -r requirements.txt \
		&& sudo python2 setup.py install

ping: ansible
	ansible -vvv -m ping -i inventory.local -c local host

test: ping
	ansible-playbook -vvv provision.yml -e verbose=true -e latest=true \
		-i inventory.local -c local -e travis_ci=true \
		-e gitsite=https://github.com/

travis-ci: test

clean:
	$(RM) -rf .ansible
	$(RM) *.retry
	$(RM) .*.sw? **/.*.sw?
