all: provision guest

.PHONY: provision guest
provision guest:
	@ansible-playbook $@.yml -e verbose=true -e latest=true

.PHONY: test
test:
	ansible-playbook provision.yml -e verbose=true -e latest=true \
		-e travis_ci=true -e gitsite=https://github.com/

clean:
	$(RM) *.retry
	$(RM) .*.sw? **/.*.sw?
