# Local developer loop. Everything CI does, runnable from a laptop.
#
#   make check    - all static gates, no AWS account needed
#   make plan     - plan against staging
#   make deploy   - apply to staging
#   make smoke    - hit the deployed endpoint
#   make destroy  - tear down

ENV ?= staging

.PHONY: help check fmt validate test audit scan init plan deploy smoke logs items destroy

help:
	@grep -E '^[a-z-]+:.*?# ' $(MAKEFILE_LIST) | sed 's/:.*# /\t- /'

check: fmt validate test audit scan # Run every gate CI runs, offline

fmt: # Check formatting
	terraform fmt -check -recursive

validate: # Validate HCL without touching the backend
	terraform init -backend=false -upgrade >/dev/null
	terraform validate
	cd bootstrap && terraform init -backend=false >/dev/null && terraform validate

test: # Unit-test the Lambda handler against a mocked DynamoDB
	python3 -m pytest tests/ -v

audit: # Scan Lambda dependencies for known CVEs
	pip-audit --requirement src/requirements.txt --strict

scan: # IaC security scan (the pre-apply gate)
	checkov --directory . --config-file .checkov.yaml --compact

init: # Initialise the backend for $(ENV)
	terraform init -reconfigure -backend-config=envs/$(ENV).backend.hcl

plan: init # Plan $(ENV)
	terraform plan -var-file=envs/$(ENV).tfvars

deploy: init # Apply $(ENV)
	terraform apply -var-file=envs/$(ENV).tfvars

smoke: # Send a valid and an invalid request to the deployed endpoint
	@ENDPOINT=$$(terraform output -raw health_endpoint); \
	echo "--> valid request (expect 200)"; \
	curl -s -w '\nHTTP %{http_code}\n' -X POST "$$ENDPOINT" \
	  -H 'content-type: application/json' \
	  -d '{"payload":{"source":"make-smoke"}}'; \
	echo "--> missing payload (expect 400)"; \
	curl -s -w '\nHTTP %{http_code}\n' -X POST "$$ENDPOINT" \
	  -H 'content-type: application/json' -d '{}'

logs: # Tail the Lambda log group
	aws logs tail $$(terraform output -raw lambda_log_group) --follow

items: # Show what landed in DynamoDB
	aws dynamodb scan --table-name $$(terraform output -raw dynamodb_table_name) \
	  --max-items 10 --output json

destroy: init # Destroy $(ENV)
	terraform destroy -var-file=envs/$(ENV).tfvars
