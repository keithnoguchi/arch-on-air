all: provision guest

.PHONY: provision guest
provision guest:
	@ansible-playbook $@.yml -e verbose=false

clean:
	$(RM) *.retry
	$(RM) .*.sw? **/.*.sw?
