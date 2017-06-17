.PHONY: guest
guest:
	ansible-playbook guest.yml

clean:
	$(RM) *.retry
	$(RM) tasks/*.retry
