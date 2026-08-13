**Terraform EC2 Example**

This repository contains a minimal Terraform configuration to provision an EC2 instance and a security group, plus a GitHub Actions workflow to run plan and apply.

**Action Items**
- Try re running tf with existing server which gets state.
- Add custom AMI instead 
- Figure out OIDC


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

## Configure remote state backend

1. Create an S3 bucket in the AWS Console:
   - Go to Services → S3 → Create bucket
   - Choose a name like `my-terraform-state-bucket`
   - Choose the region you want to use for state storage
   - Enable encryption and versioning if available

2. Create a DynamoDB table for state locking:
   - Services → DynamoDB → Create table
   - Table name: `terraform-locks`
   - Primary key: `LockID` (String)
   - Use default settings, no sort key needed

3. Update `backend.tf` with your bucket, table, and region:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "terraform/state.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

4. Initialize Terraform with the backend:

```bash
terraform init
```

If this is the first time, Terraform will ask to migrate state into the new backend.

## AWS IAM permissions for backend access

Your Terraform AWS user or role needs permissions for S3 and DynamoDB.

Minimal permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::my-terraform-state-bucket",
        "arn:aws:s3:::my-terraform-state-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:YOUR_ACCOUNT_ID:table/terraform-locks"
    }
  ]
}
```

## AWS Console setup summary

- S3 bucket: create and enable encryption/versioning
- DynamoDB table: create with `LockID` partition key
- Update `backend.tf` with bucket/table names and region
- Run `terraform init` and accept backend migration if prompted

## Run using GitHub Actions GUI

If you use the GitHub Actions workflow, click the `Terraform CI/CD` workflow, then `Run workflow` and enter the cluster file path under `cluster_file`.

Example values:
- `cluster/dev.tfvars`
- `cluster/test.tfvars`
- `cluster/prod.tfvars`

This lets you select the instance file directly from the GitHub UI.
