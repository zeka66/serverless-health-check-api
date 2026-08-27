# Serverless Health Check API

A `/health` endpoint that logs every request to CloudWatch and stores it in DynamoDB. Terraform for the infrastructure, GitHub Actions for deployment, staging and prod as separate environments. No AWS credentials stored anywhere — the pipeline authenticates with OIDC.

## Architecture

API Gateway (REST) exposes `GET` and `POST` on `/health` and forwards to a Python 3.12 Lambda through an `AWS_PROXY` integration. The function logs the event, checks the body for a `payload` key, and writes it to DynamoDB with a generated UUID. Missing `payload` gets a 400 and nothing is written.

Every resource is prefixed with its environment, so `staging-requests-db` and `prod-health-check-function`. The prefix is built once in `locals.tf` and passed into the modules.

Throttling is set at the API Gateway stage: 20 req/sec with a burst of 40 in staging, 100/200 in prod.

## Project structure

```text
.github/workflows/deploy.yml   pipeline
.checkov.yaml                  scan config and documented skips
Makefile                       local commands
bootstrap/                     state bucket, OIDC provider, deploy roles
envs/                          tfvars and backend config per environment
modules/                       dynamodb, iam, lambda, api_gateway
src/handler.py                 Lambda source
tests/test_handler.py          unit tests with mocked DynamoDB
```

Four modules composed by the root `main.tf`. They take their names as inputs rather than building them, so the naming convention lives in one place and a module could be reused for something else without edits.

## Setup

You'll need Terraform 1.10+ (1.10 added native S3 state locking, which is why there's no DynamoDB lock table), AWS CLI v2, and Python 3.12. For the local checks: `pip install checkov pip-audit -r tests/requirements-dev.txt`.

The bootstrap stack creates what the main stack can't create for itself — the state bucket, the OIDC provider, and the two deploy roles. It keeps local state, since the bucket it creates doesn't exist yet. Keeping the deploy roles out here also means the pipeline can't widen its own permissions.

```bash
aws configure --profile admin        # admin user with MFA, used once

cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# fill in: state_bucket_name (globally unique), OWNER/REPO, account ID

AWS_PROFILE=admin terraform init
AWS_PROFILE=admin terraform apply

terraform output deploy_role_arns
terraform output state_bucket_name
```

Put the bucket name into `envs/staging.backend.hcl` and `envs/prod.backend.hcl`, then set three repository variables under Settings → Secrets and variables → Actions → Variables:

| Name | Value |
| --- | --- |
| `AWS_REGION` | your region |
| `AWS_ROLE_ARN_STAGING` | staging role ARN from the bootstrap output |
| `AWS_ROLE_ARN_PROD` | prod role ARN from the bootstrap output |

These are variables, not secrets. Role ARNs aren't sensitive, and with OIDC there's no long-lived key to store in the first place.

Last step: create `staging` and `prod` under Settings → Environments. The OIDC subject claim includes the environment name, so the roles won't be assumable without them. Add yourself as a required reviewer on `prod` if you want the approval gate.

## Deployment

Open a pull request against `main`. `validate` runs formatting, `terraform validate` on both stacks, the unit tests, `pip-audit`, and Checkov. `plan` posts the Terraform plan as a comment. Nothing is applied.

Merge it. `deploy-staging` assumes the staging role, applies `envs/staging.tfvars`, and smoke-tests the live endpoint for both a 200 and a 400. If that passes, `deploy-prod` waits for approval before touching production.

Both deploy jobs declare `needs: validate`, so a Checkov finding stops the run before anything is applied. `validate` itself gets no AWS credentials at all — the tests use `moto`, so nothing in that job needs an account, and a PR from a fork has nothing to steal.

You can also run it by hand from Actions → Deploy → Run workflow.

Locally:

```bash
make check                 # everything CI checks, offline
make plan   ENV=staging
make deploy ENV=staging
make smoke
```

Use the `make` targets rather than calling Terraform directly. They pick the backend config and the tfvars from the same `ENV`, so the two can't disagree — I planned prod against staging's state once before adding them, and the output was alarming.

## Testing

```bash
ENDPOINT=$(terraform output -raw health_endpoint)

curl -i -X POST "$ENDPOINT" \
  -H 'content-type: application/json' \
  -d '{"payload": {"source": "manual-test"}}'
```

Returns 200 and `{"status": "healthy", "message": "Request processed and saved."}`.

Drop the key and you get a 400:

```bash
curl -i -X POST "$ENDPOINT" \
  -H 'content-type: application/json' \
  -d '{"not_payload": 1}'
```

`terraform output curl_example` prints a ready-made command. `make logs` tails the function and `make items` scans the table.

## Security

The Lambda role has `dynamodb:PutItem` on one table and log writes to its own log group. Nothing else — no `Scan`, no `Query`, and not `logs:CreateLogGroup`, since Terraform creates the group. The one wildcard in the project is the `:*` suffix on that log group ARN, which addresses the streams inside it; CloudWatch Logs has no narrower form.

The deploy roles have no `Resource = "*"` anywhere. Every statement is pinned to an `env-*` ARN, and each role is limited to its own environment's state prefix, roles, tables and functions. `iam:PassRole` is restricted to the execution role and conditioned on `iam:PassedToService = lambda.amazonaws.com`.

DynamoDB uses server-side encryption. The state bucket is versioned, blocks public access, and denies non-TLS requests. `data_trace_enabled` is off so request bodies don't end up in the access logs.

Checkov passes clean. The skips are in `.checkov.yaml` with a reason on each.

## Design notes

**REST API rather than HTTP API.** HTTP API is cheaper and would be the obvious pick for something this small. REST v1 has gateway request validation and native API keys, which are the next two things I'd add, and switching later would mean replacing the API.

**GET also requires a body.** The brief asks for GET or POST on `/health` and separately says the body must contain `payload`. Applied to both, a GET with no body returns 400. Odd for a health check, but the alternative is ignoring the validation rule for half the methods.

**Payload stored as a JSON string.** DynamoDB has no float type, so `{"payload": 1.5}` fails on write if passed straight through. Serialising avoids coercing numbers to `Decimal`.

**Separate state files per environment** rather than workspaces, selected with `-backend-config`. Workspaces push you toward one variable set and make applying to the wrong environment easy.

**Throttling at the gateway, not the function.** Reserving Lambda concurrency needs 100 unreserved executions left in the account and this one doesn't have the room, so both environments use the shared pool.

**The IAM module gets the log group ARN as a string, not a reference.** Referencing the Lambda module directly creates a cycle: the function needs the role, the role needs the function's log group.

**OIDC subject claims.** The first pipeline runs couldn't assume the deploy role. When a job targets a GitHub Environment the subject is `repo:OWNER/REPO:environment:NAME`, not the `ref` form you get without one. Matching that fixed it, and it also means a staging job can't assume the prod role from the same branch. Took a few commits to work out.

Assumptions: one account, one region, `main` as the only long-lived branch, internal-facing endpoint, no custom domain. Items expire via TTL — 7 days in staging, 90 in prod. The Lambda source is minimal since the brief says it isn't evaluated.

## Future improvements

A customer-managed KMS key, the Lambda in its own VPC, gateway-level request validation, API key auth, and Lambda versions with an alias. The related Checkov checks are skipped with that reason written down rather than hidden.

## Cleanup

```bash
make destroy ENV=staging
make destroy ENV=prod
cd bootstrap && terraform destroy
```

The prod table has deletion protection on, so that needs turning off first. There's no NAT gateway and no WAF here, which are the two things that would otherwise cost real money.
