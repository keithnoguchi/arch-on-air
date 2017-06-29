all: provision guest

.PHONY: provision guest
provision guest:
	@ansible-playbook $@.yml -e verbose=true -e latest=true

# test target is run by the travis-ci through .travis.yml.
.PHONY: test
test:
	ansible-playbook provision.yml -e verbose=true -e latest=true \
		-i inventory.local -c local -e travis_ci=true \
		-e gitsite=https://github.com/

clean:
	$(RM) *.retry
	$(RM) .*.sw? **/.*.sw?
