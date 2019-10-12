#!/bin/bash

# Based on script from https://github.com/liatrio/aws-accounts-terraform
# Builds on the work of the following blog posts:
#   - https://www.liatrio.com/blog/secure-aws-account-structure-with-terraform-and-terragrunt
#   - https://medium.com/@EmiiKhaos/automated-aws-account-initialization-with-terraform-and-onelogin-saml-sso-1301ff4851ab
#   - https://medium.com/@EmiiKhaos/part-2-automated-aws-multi-account-setup-with-terraform-and-onelogin-sso-44baaf563877

set -e

DEFAULT_REGION='eu-west-2'

function usage {
    echo "DESCRIPTION:"
    echo "  Script for initializing a basic AWS account structure:"
    echo "  - An organisation will be configured"
    echo "  - Management, Production and Staging sub-accounts will be created"
    echo "  - Various groups, including administrators, developers, finance, terragrunt and users will be created"
    echo "  - An IAM user will be created in the Master organisation with the necessary permissions to run terragrunt"
    echo "  - An IAM administrator user will be created"
    echo "  *** MUST BE INITIALLY RUN WITH CREDENTIALS FOR A SPECIALLY-PROVISIONED USER IN THE MASTER ACCOUNT ***"
    echo ""
    echo "USAGE:"
    echo "  ${0} -a <access key> -s <secret key> -k <keybase profile> [-l <local_modules_directory>] [-r <region>]"
    echo ""
    echo "OPTIONAL ARGUMENTS:"
    echo "  -l   Use a local folder as the source for Terragrunt modules e.g. ~/Code/terraform/modules"
    echo "  -r   Override the default AWS region (eu-west-2)"
    echo ""
    echo "Requirements:"
    echo "  - Terraform"
    echo "  - Terragrunt"
    echo "  - Keybase"
}

while getopts "a:k:l:r:s:dh" option; do
    case ${option} in
        a ) ACCESS_KEY=$OPTARG;;
        d ) DEV_MODE=1;;
        k ) KEYBASE_PROFILE=$OPTARG;;
        l ) LOCAL_MODULES_DIR=$OPTARG;;
        r ) DEFAULT_REGION=$OPTARG;;
        s ) SECRET_KEY=$OPTARG;;
        h )
            usage
            exit 0
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            usage
            exit 1
            ;;
    esac
done

if [ -z "$DEV_MODE" ]; then
    DEV_MODE=0
fi

if [[ -z "${ACCESS_KEY}" ]]; then
    echo "Please provide the terragrunt.init user's access key with -a <access key>" 1>&2
    VALIDATION_ERROR=1
fi
if [[ -z "${SECRET_KEY}" ]]; then
    echo "Please provide the terragrunt.init user's secret key with -s <secret key>" 1>&2
    VALIDATION_ERROR=1
fi
if [[ -z "${KEYBASE_PROFILE}" ]]; then
    echo "Please provide the keybase username as -k <keybase profile> " 1>&2
    VALIDATION_ERROR=1
fi
if [[ -n "${VALIDATION_ERROR}" ]]; then
    echo ""
    exit 1
fi

if [[ -n "${LOCAL_MODULES_DIR}" ]]; then
    TG_SOURCE="--terragrunt-source ${LOCAL_MODULES_DIR}"
fi


export AWS_DEFAULT_REGION=${DEFAULT_REGION}

function export_master_keys {
    echo ""
    echo "USING MASTER CREDENTIALS"
    echo ""
    export AWS_ACCESS_KEY_ID=${ACCESS_KEY}
    export AWS_SECRET_ACCESS_KEY=${SECRET_KEY}
}

function export_admin_keys {
    echo ""
    echo "USING ADMIN CREDENTIALS"
    echo ""
    export AWS_ACCESS_KEY_ID=${ADMIN_ACCESS_KEY}
    export AWS_SECRET_ACCESS_KEY=${ADMIN_SECRET_KEY}
}

function pushd () {
    command pushd "$@" > /dev/null
}

function popd () {
    command popd "$@" > /dev/null
}

export_master_keys
echo "=== CREATING ORGANISATION ==="
pushd ./first-run/convert-to-organisation
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//utility/convert-to-organisation"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE}
popd
pushd ./organisation
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//organisation"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE}
ACCOUNT_ID=$(terragrunt output ${TG_SOURCE_MODULE} master_account_id)
popd

echo "=== CREATING MANAGEMENT ACCOUNT ==="
pushd ./accounts/management
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//account"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE}
MANAGEMENT_ID=$(terragrunt output ${TG_SOURCE_MODULE} account_id)
popd
echo "=== CREATING PRODUCTION ACCOUNT ==="
pushd ./accounts/production
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//account"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE}
PRODUCTION_ID=$(terragrunt output ${TG_SOURCE_MODULE} account_id)
popd
echo "=== CREATING STAGING ACCOUNT ==="
pushd ./accounts/staging
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//account"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE}
STAGING_ID=$(terragrunt output ${TG_SOURCE_MODULE} account_id)
popd

echo "=== CREATING terragrunt GROUP ==="
pushd ./iam/groups/terragrunt
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//iam/groups/terragrunt"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE}
popd

echo "=== CREATING terragrunt.gitlab USER ==="
pushd ./iam/users/terragrunt-gitlab
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//iam/users/terragrunt"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE} -var keybase=${KEYBASE_PROFILE}
TERRAGRUNT_GITLAB_ACCESS_KEY=$(terragrunt output ${TG_SOURCE_MODULE} terragrunt_user_access_key)
TERRAGRUNT_GITLAB_SECRET_KEY=$(terragrunt output ${TG_SOURCE_MODULE} terragrunt_user_secret_key | base64 --decode | keybase pgp decrypt)
popd

echo "=== CREATING users GROUP ==="
pushd ./iam/groups/users
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//iam/groups/users"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE}
popd
echo "=== CREATING administrators GROUP ==="
pushd ./iam/groups/administrators
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//iam/groups/administrators"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE}
popd
echo "=== CREATING finance GROUP ==="
pushd ./iam/groups/finance
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//iam/groups/finance"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE}
popd
echo "=== CREATING developers GROUP ==="
pushd ./iam/groups/developers
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//iam/groups/developers"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE}
popd

echo "=== CREATING ADMINISTRATOR USER ==="
pushd ./iam/users/administrator
if [[ -n "${TG_SOURCE}" ]]; then
    TG_SOURCE_MODULE="${TG_SOURCE}//iam/users/administrator"
fi
terragrunt init ${TG_SOURCE_MODULE}
terragrunt apply ${TG_SOURCE_MODULE} -var keybase=${KEYBASE_PROFILE}
ADMIN_USERNAME=$(terragrunt output ${TG_SOURCE_MODULE} admin_username)
ADMIN_PASSWORD=$(terragrunt output ${TG_SOURCE_MODULE} admin_user_password | base64 --decode | keybase pgp decrypt)
ADMIN_ACCESS_KEY=$(terragrunt output ${TG_SOURCE_MODULE} admin_user_access_key)
ADMIN_SECRET_KEY=$(terragrunt output ${TG_SOURCE_MODULE} admin_user_secret_key | base64 --decode | keybase pgp decrypt)
popd

export_admin_keys

if [ "$DEV_MODE" -eq 0 ]; then
    echo "=== DELETING terragrunt.init IAM USER ==="
    pushd ./first-run/delete-terragrunt-init
    if [[ -n "${TG_SOURCE}" ]]; then
        TG_SOURCE_MODULE="${TG_SOURCE}//utility/import-unmanaged-iam-user"
    fi
    terragrunt init ${TG_SOURCE_MODULE}
    terragrunt import ${TG_SOURCE_MODULE} aws_iam_policy.policy "arn:aws:iam::${ACCOUNT_ID}:policy/TerragruntInit"
    terragrunt import ${TG_SOURCE_MODULE} aws_iam_user.user terragrunt.init
    terragrunt import ${TG_SOURCE_MODULE} aws_iam_user_policy_attachment.attachment "terragrunt.init/arn:aws:iam::${ACCOUNT_ID}:policy/TerragruntInit"

    # Well, this was super annoying... "terraform import" doesn't pick up force_destroy preventing the user being deleted due to unmanaged access keys
    # https://github.com/terraform-providers/terraform-provider-aws/issues/7859
    #
    # Running apply makes terraform see that the force_destroy flag is set for the user, and updates accordingly
    terragrunt apply ${TG_SOURCE_MODULE}

    terragrunt destroy ${TG_SOURCE_MODULE}
fi

echo "=== COMPLETING ENVIRONMENT DEPLOYMENT==="
terragrunt apply-all --terragrunt-exclude-dir first-run ${TG_SOURCE}


echo ""
echo "=== INITIALISATION COMPLETE ==="
echo "Console login                : https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
echo "----------------------------------------------------------------"
echo "Role Switch Links"
echo "Master Administrator         :  https://signin.aws.amazon.com/switchrole?account=${ACCOUNT_ID}&roleName=Administrator&displayName=Master%20-%20Administrator"
echo "Master Billing               :  https://signin.aws.amazon.com/switchrole?account=${ACCOUNT_ID}&roleName=Billing&displayName=Master%20-%20Billing"
echo "Terragrunt Bucket Read       :  https://signin.aws.amazon.com/switchrole?account=${ACCOUNT_ID}&roleName=TerragruntReader&displayName=Master%20-%20Terragrunt%20Read"
echo "Management Administrator     :  https://signin.aws.amazon.com/switchrole?account=${MANAGEMENT_ID}&roleName=Administrator&displayName=Management%20-%20Administrator"
echo "Production Administrator     :  https://signin.aws.amazon.com/switchrole?account=${PRODUCTION_ID}&roleName=Administrator&displayName=Production%20-%20Administrator"
echo "Staging Administrator        :  https://signin.aws.amazon.com/switchrole?account=${STAGING_ID}&roleName=Administrator&displayName=Staging%20-%20Administrator"
echo "Staging Power User           :  https://signin.aws.amazon.com/switchrole?account=${STAGING_ID}&roleName=PowerUser&displayName=Staging%20-%20Power%20User"
echo "----------------------------------------------------------------"
echo "Administrator username       : " $ADMIN_USERNAME
echo "Administrator password       : " $ADMIN_PASSWORD
echo "Administrator access key     : " $ADMIN_ACCESS_KEY
echo "Administrator secret key     : " $ADMIN_SECRET_KEY
echo "----------------------------------------------------------------"
echo "terragrunt.gitlab access key : " $TERRAGRUNT_GITLAB_ACCESS_KEY
echo "terragrunt.gitlab secret key : " $TERRAGRUNT_GITLAB_SECRET_KEY
