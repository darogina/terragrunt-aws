locals {
  aws_region = "eu-west-2"
  domain     = "domain.com"
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"

  config = {
    encrypt        = true
    bucket         = "tfstate.${local.domain}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "tflocks.${local.domain}"
  }
}

# Configure root level variables that all resources inherit
inputs = {
  aws_region                   = local.aws_region
  domain                       = local.domain
  cloudtrail_bucket_name       = "cloudtrail.${local.domain}"
  tfstate_global_bucket        = "tfstate.${local.domain}"
  tfstate_global_bucket_region = local.aws_region
  tfstate_global_dynamodb      = "tflocks.${local.domain}"
}