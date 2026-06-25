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
