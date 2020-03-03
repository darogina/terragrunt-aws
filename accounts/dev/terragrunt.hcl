# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder.
terraform {
  source = "git::git@github.com:darogina/terragrunt-aws-modules.git//account?ref=v0.2.0"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
inputs = {
  account_name       = "dev"
  account_email_slug = "zjonsson+thenumberdev"
  domain             = "phoenixabs.com"
}
