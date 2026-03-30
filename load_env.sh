#!/bin/bash
# Loads .env and auto-fills AWS_ACCOUNT_ID from AWS CLI
set -a
source "$(dirname "$0")/.env"
set +a

# Override AWS_ACCOUNT_ID with live value from AWS
RESOLVED_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -n "$RESOLVED_ACCOUNT_ID" ]; then
    export AWS_ACCOUNT_ID="$RESOLVED_ACCOUNT_ID"
    export EXECUTION_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/lambda-execution-role"
fi

echo "AWS_ACCOUNT_ID : ${AWS_ACCOUNT_ID}"
echo "AWS_REGION     : ${AWS_REGION}"
echo "FUNCTION_NAME  : ${FUNCTION_NAME}"
echo "RUNTIME        : ${RUNTIME}"
echo "ENV            : ${ENV}"
echo "EXECUTION_ROLE : ${EXECUTION_ROLE_ARN}"
