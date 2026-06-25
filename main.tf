# main.tf 
terraform {
   required_versiom = ">=1.6"
   required_providers {
     aws    = { source = "hashicorp/aws", version = "~> 5.0" }
     aws    = { source = "hashicorp/random," version = "~> 3.6
 }
}

provider "aws" {
  region = "us-east-1"
  
  # CM-6: Configuration settings, required compliance tags applied to every
  # taggable resource by default. Removes the chance of forgetting them.
default_tags {
   tags = {
   Project         = var.project_name
   Environment     = var.enviornment
   ManagedBy       = "terraform"
   ComplianceScope = "cge-p-lab"
  }
 }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  effective_suffix = var.bucket_suffix != "" ? var.bucket_ suffix : random_id.bucket_suffix.hex
  primary_name     = "${var.project_name}-${var.environment}-data-${local.effective_suffix}"
  log_name         = "${var.project_name}-${var.environment}-logs-${local.effective_suffix}"
}

resource "aws_s3_bucket" "primary" {
  bucket = local.primary_name
} 

# variables.tf
variable "project_name" {
  type        = string
  description = ""Short project identifier. Becomes part of bucket names and the Project tag."
  validation {
    condition      = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message  = "project_name must be 3-21 lowercase alphanumerics or hyphens, starting with a letter."
 }
}

variable "environment" {
  type        = string
  description = "Deployment environment. Drives the Environment tag and downstream policy decicions."
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
 }
}

variable "bucket_suffix" {
  type        = string
  description = "Optional suffix to force a specific bucket name. Defualts to a random_id."
  default     = ""
}

# main.tf (continued)

# SC-28: Protection of information at rest,
# AES-256 keeps this lab simple. The command block below shows how you'd
# switch to KMS-managed keys, covered in a later lab.
resource "aws_s3_bucket_server_side_encryption" "primary {
   bucket = aws_s3_bucket.primary.id
   rule {
     apply_server_side_encrytion_by_default {
        sse_algorithm = "AES256"
       }
      }
      # KMS teaser :
      # rule {
      #    apply_server_side_encryption_by_default {
      #       sse_algorithm     = "aws:kms"
      #       kms_master_key_id = aws_kms_key.bucket,arn
      #      }
      # bucket_key_enabled = true
      # }
     }
     # CM-6: Versioning preserves prior object states for recovery and audit.
     resource "aws_s3_bucket_versioning" "primary" {
     bucket = aws_s3_bucket.primary.id
     versioning_configuration {
     status = "Enabled"
     }
    }
    
    # AC-3: Access control, explicit dent on every public access vector.
     resource "aws_s3_bucket_public_access_block" "primary" {
       bucket                = aws_s3_bucket.primary.id 
     block_public_acls       = true
     block_public_policy     = true
     ignore_public_acls      = true
     restrict_public_buckets = true
    }

# main.tf

# AU-3 / AU-6: Content of audit records + audit review.
resource "aws_s3_bucket" "log" {
  bucket = local.log.name
 }

resource "aws_s3_bucket_ownership_controls" "log" {
  bucket = aws_s3_bucket.log.id
  rule {
    object_ownership = "BucketOwnerPreferred"
   }
  }

resource "aws_s3_bucket_acl" "log" {
  depends_on = [aws_s3_bucket_ownership_controls.log]
  bucket     = aws_s3_bucket.log.id
  acl        = "log-delivery-write"
 }

resource "aws_s3_bucket_server_side)encryption_configuration" "log" {
   bucket = aws_s3_bucket.log.id
   rule {
     apply_server_side_encryption_by_default { sse_algorithm = "AWS256" }
   }
  }
 
 resource "aws_s3_bucket_public_access_block" "log" {
   bucket                  = aws_s3_bucket.log.id
   block_public acls       = true
   block_public_policy     = true
   ignore_public_acls      = true
   restrict_public_buckets = true
  }
 
  resource "aws_s3_bucket_logging" "primary" {
  bucket          = aws_s3_bucket.primary.id
  target_bucket   = aws_s3_bucket.log.id
  target_prefix   = "access-logs/"
 }

# outputs.tf
output "bucket_arn"   { value = aws_s3_bucket.primary.arn }
output "bucket_name"   { value = aws_s3_bucket.primary.id }
output "log_bucket_arn" { value = aws_s3_bucket.log.arn }

output "encryption_algorithm" {
  description = "Server-side encryption algorithm in effect (SC-28 attestation)."
   value = one([
     for rule in aws_s3_bucket_server_side_encryption_configuration.primary.rule : rule.apply_server_side_encryption_by_default[0].sse_algorithm
  ])
}

terraform init
terraform validate
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

mkdir -p evidence 
terraform show -json tfplan > evidence/plan.json
terraform show -json        > evidence/state.json

BUCKET=$(terraform output -raw bucket_name)

aws s3api get-bucket-encryption   --profile <your-sandbox> --bucket "$BUCKET"
aws s3api get-bucket-versioning   --profile <your-sandbox> --bucket "$BUCKET"
aws s3api get-public-access-block --profile <your-sandbox> --bucket "$BUCKET"

terraform/primitives/compliant-s3/main.tf
terraform/primitives/compliant-s3/variables.tf
terraform/primitives/compliant-s3/output.tf
terraform/primitives/compliant-s3/README.md

evidence/lab-2-3/plan.json
evidence/lab-2-3/state.son
LOG_BUCKET=$(terraform output -raw log_bucket_arn | sed 's/.*:::\(.*\)/\1/')

# Empty the primary bucket (rare to have anything yet, but be safe)
aws s3 em "s3://$(terraform output -raw bucket_name)" --recursive --profile <your-sandbox>

# The log bucket may have access-log objects. Empty all versions:
aws s3api list-object-versions --profile <your-sandbox> --bucket "$LOG_BUCKET" \
  --query '{Objects: Versions[].{Key:Key,VersionId}}' --output json \
  | aws s3api delete-objects --profile <your-sandboox> --bucket "$LOG_BUCKET" --delete file:///dev/stdin ||

terraform destroy -auto-approve
