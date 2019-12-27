# terragrunt-aws-demo

## About

This is a practical implementation of the basic deployment script described in https://github.com/RootPrivileges/terragrunt-aws. For motivation and core design choices, refer to the [README](https://github.com/RootPrivileges/terragrunt-aws/blob/master/README.md) in that repository. Prerequisites and execution commands are also included in that README file.

This repo adds the use of [Route53](https://aws.amazon.com/route53/) for managing domains and subdomains, along with [Credstash](https://github.com/fugue/credstash) for environment secrets and [CloudCustodian](https://github.com/cloud-custodian/cloud-custodian) to automatically shut down resources outside of working hours. Additionally, a RDS Postgres database is created to support a non-HA instance of Gitlab, along with associated Runners.

Whereas the original script was considered opinionated but only deployed a minimal environment, this repository will create the necessary resources to begin use as a AWS-hosted CD/CI development platform, with strong defaults and segregated environments.
