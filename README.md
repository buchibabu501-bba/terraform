**Terraform EC2 Example**

This repository contains a minimal Terraform configuration to provision an EC2 instance and a security group, plus a GitHub Actions workflow to run plan and apply.

**Action Items**
- Add apply button
- Figure out OIDC
- state file in bucket

## Cluster definitions

Create cluster-specific variable files under `cluster/`:

- `cluster/dev.tfvars`
- `cluster/test.tfvars`
- `cluster/prod.tfvars`

Each file defines `cluster`, `aws_region`, and `instance_names`.

Example: `cluster/dev.tfvars`

```hcl
cluster = "dev"
aws_region = "us-east-1"
instance_names = [
  "devpostdb1",
]
```

## Run a cluster

Use the cluster file with Terraform:

```bash
terraform init
terraform plan -var-file=cluster/dev.tfvars -out=tfplan
terraform apply tfplan
```

Each cluster file can also set its own region with `aws_region`.

For test:

```bash
terraform plan -var-file=cluster/test.tfvars -out=tfplan
terraform apply tfplan
```

For prod:

```bash
terraform plan -var-file=cluster/prod.tfvars -out=tfplan
terraform apply tfplan
```

## Run using GitHub Actions GUI

If you use the GitHub Actions workflow, click the `Terraform CI/CD` workflow, then `Run workflow` and enter the cluster file path under `cluster_file`.

Example values:
- `cluster/dev.tfvars`
- `cluster/test.tfvars`
- `cluster/prod.tfvars`

This lets you select the instance file directly from the GitHub UI.
