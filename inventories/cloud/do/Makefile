all: deploy

# Some terraform command aliases.
.PHONY: init plan show output apply
init plan show refresh output apply:
	terraform $@

.PHONY: deploy
deploy: init plan
	terraform apply -auto-approve

.PHONY: clean clean-all clean-firewalls
clean: init
	terraform destroy -force
	$(RM) *.tfstate*
	$(RM) *.log
