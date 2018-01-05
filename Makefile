all: main

.PHONY: main provision hack
main provision hack:
	@ansible-playbook $@.yml -e latest=true

# those are the target primarily used by the travis CI through .travis.yml.
.PHONY: ansible ansible ping test
ansible: clean
	git clone https://github.com/ansible/ansible .ansible
	cd .ansible \
		&& sudo pip install -r requirements.txt \
		&& sudo python setup.py install 2>&1 > /dev/null

ping:
	ansible -vvv -m ping -i inventory.ini -c local host

test: ansible ping
	ansible-playbook -vvv main.yml -e latest=true -c local \
		-e travis_ci=true -e gitsite=https://github.com/

clean:
	sudo $(RM) -rf .ansible
	$(RM) *.bak *.retry .*.sw? **/.*.sw?
