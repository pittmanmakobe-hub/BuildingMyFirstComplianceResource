# main.tf
terraform {
# compliant-s3

This module provisions a compliant AWS S3 bucket and enforces the following
NIST 800-53 controls on every deployment:

| Control | Enforcement |
|---------|-------------|
| SC-28   | AES-256 server-side encryption via aws_s3_bucket_server_side_encryption_configuration |
| AU-3    | S3 server access logging routed to a dedicated log bucket |
| AU-6    | Log bucket encrypted and publicly blocked for safe long-term retention |
| CM-6    | Versioning enabled; required compliance tags enforced via provider default_tags |
| AC-3    | All four public access block flags set to true on both buckets |

## Usage

```hcl
module "compliant_s3" {
  source       = "./terraform/primitives/compliant-s3"
  project_name = "cgep-lab"
  environment  = "dev"
}
```

## Outputs

- `bucket_arn` — ARN of the primary data bucket
- `bucket_name` — Name of the primary data bucket
- `log_bucket_arn` — ARN of the access-log bucket
- `encryption_algorithm` — SC-28 attestation value ("AES256")

## Evidence

After `terraform apply`, run:

```bash
mkdir -p evidence/lab-2-3
terraform show -json tfplan > evidence/lab-2-3/plan.json
terraform show -json        > evidence/lab-2-3/state.json
```

Commit both JSON files as machine-readable compliance evidence.
