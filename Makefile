all: provision guest

.PHONY: provision guest
provision guest:
	@ansible-playbook $@.yml -e verbose=true -e latest=true

clean:
	$(RM) *.retry
	$(RM) .*.sw? **/.*.sw?
