#!/usr/bin/env bash
# This script will plan Terraform configuration changes to the 'default' workspace.
set -Eeuo pipefail

source "//build/util"
source "//third_party/sh:shflags"
source "//build/ci/terraform:env"

DEFINE_string 'please_target' '' 'Please terraform_root target to use (required)' 't'

FLAGS "$@" || exit $?
eval set -- "${FLAGS_ARGV}"

if [ -z "${FLAGS_please_target}" ]; then
    flags_help
    exit 1
fi

REPO_ROOT="$(./pleasew query reporoot)"
OPA_BINARY="$REPO_ROOT///third_party/binary:opa"
OPA_BUNDLE="$REPO_ROOT///policy/terraform"

per_tf_root_opa_data_target="${FLAGS_please_target//\:/\:_}#opa_data"
./pleasew build -p "$per_tf_root_opa_data_target"
PER_TF_ROOT_OPA_DATA="$REPO_ROOT/$(./pleasew query output "$per_tf_root_opa_data_target")"

util::info "Running 'terraform plan' for ${FLAGS_please_target}"

./pleasew run -p "$FLAGS_please_target" -- "
terraform init -lock=false && \
terraform plan -refresh=false -compact-warnings -lock=false -out=tfplan.out && \
terraform show -json tfplan.out > tfplan.json && \

# if the OPA tool prints 'undefined', it is happy... 
# It will print a table of errors if it is not happy.
$OPA_BINARY eval \
    --fail-defined \
    --format pretty \
    --bundle $OPA_BUNDLE \
    --data $PER_TF_ROOT_OPA_DATA \
    --input tfplan.json \
    'data.terraform.analysis.deny[_]'
"

util::success "Terraform plan for ${FLAGS_please_target} is OK!"
