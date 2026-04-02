.PHONY: fmt-check validate lint security docs

fmt-check:
	terraform fmt -check -recursive

validate: fmt-check
	terraform init -backend=false
	terraform validate

lint:
	tflint --init
	tflint --recursive

security:
	checkov -d . --framework terraform --quiet
	trivy fs . --scanners secret,misconfig --quiet

docs:
	terraform-docs .
