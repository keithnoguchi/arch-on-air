all: provision guest

.PHONY: provision guest
provision guest:
	@ansible-playbook $@.yml -e verbose=false -e latest=true

clean:
	$(RM) *.retry
	$(RM) .*.sw? **/.*.sw?
