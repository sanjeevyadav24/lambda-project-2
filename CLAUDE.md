# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Single AWS Lambda function (`lambda_function.py`) with handler `lambda_function.lambda_handler`. No framework, no dependencies.

## Commands

**Test locally:**
```bash
python3 -c "import json; from lambda_function import lambda_handler; print(lambda_handler(json.load(open('event.json')), None))"
```

**Package:**
```bash
zip function.zip lambda_function.py
# With dependencies:
pip install -r requirements.txt -t package/ && cd package && zip -r ../function.zip . && cd .. && zip function.zip lambda_function.py
```

**First deploy:**
```bash
aws lambda create-function \
  --function-name lambda-project-2 \
  --runtime python3.12 \
  --role arn:aws:iam::<account-id>:role/<execution-role> \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://function.zip \
  --region us-east-1
```

**Update code:**
```bash
aws lambda update-function-code --function-name lambda-project-2 --zip-file fileb://function.zip --region us-east-1
```

**Invoke & check logs:**
```bash
aws lambda invoke --function-name lambda-project-2 --payload file://event.json --cli-binary-format raw-in-base64-out response.json --region us-east-1
aws logs tail /aws/lambda/lambda-project-2 --follow
```

## Architecture

- `lambda_function.py` — sole entry point; returns `{"statusCode": 200, "body": ...}`
- `event.json` — test payload passed as `event` parameter during local testing
- `requirements.txt` — empty; add packages here before packaging

# Migration: AWS Lambda → Azure Functions

Reference: https://learn.microsoft.com/en-us/azure/azure-functions/migration/migrate-aws-lambda-to-azure-functions

## Step 1 — Assess the Lambda Function
- Runtime: `python3.12` → Azure Functions supports Python 3.9–3.13 ✓
- Handler: `lambda_function.lambda_handler` → becomes `@app.route()` decorator in Azure Functions v2 model
- No dependencies → `requirements.txt` needs `azure-functions` added
- No VPC, no layers → straightforward migration

## Step 2 — Map AWS → Azure Concepts
| AWS Lambda | Azure Functions |
|---|---|
| `lambda_handler(event, context)` | `def fn(req: func.HttpRequest)` with `@app.route()` |
| API Gateway HTTP trigger | HTTP trigger (built-in) |
| CloudWatch Logs | Application Insights |
| IAM execution role | Managed Identity + RBAC |
| `event.json` test payload | `func start` + curl locally |

## Step 3 — Rewrite Handler for Azure

**Current (`lambda_function.py`):**
```python
def lambda_handler(event, context):
    return {"statusCode": 200, "body": json.dumps("Hello from Lambda!")}
```

**Migrated (`function_app.py`):**
```python
import azure.functions as func

app = func.FunctionApp()

@app.route(route="hello", methods=["GET", "POST"])
def lambda_handler(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse("Hello from Azure Functions!", status_code=200)
```

## Step 4 — Scaffold Azure Functions Project

```bash
# Install tooling
npm install -g azure-functions-core-tools@4
pip install azure-functions

# Init project
func init . --worker-runtime python --model V2

# Add the function file
# Create function_app.py with the migrated handler above
```

`requirements.txt`:
```
azure-functions
```

`host.json`:
```json
{
  "version": "2.0",
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
  }
}
```

## Step 5 — Create Azure Resources

```bash
az group create --name lambda-project-2-rg --location centralindia
az storage account create --name lp2storage --resource-group lambda-project-2-rg --sku Standard_LRS --location centralindia
az functionapp create \
  --resource-group lambda-project-2-rg \
  --name lambda-project-2-fn \
  --storage-account lp2storage \
  --consumption-plan-location centralindia \
  --runtime python --runtime-version 3.12 \
  --functions-version 4 --os-type linux
```

## Step 6 — Migrate Environment Variables

```bash
# Read from .env and apply to Azure
az functionapp config appsettings set \
  --name lambda-project-2-fn \
  --resource-group lambda-project-2-rg \
  --settings ENV=production LOG_LEVEL=INFO
```

## Step 7 — Test Locally

```bash
func start
curl http://localhost:7071/api/hello
```

## Step 8 — Deploy

```bash
func azure functionapp publish lambda-project-2-fn
```

## Step 9 — Verify

```bash
curl https://lambda-project-2-fn.azurewebsites.net/api/hello
az monitor app-insights component show --app lambda-project-2-fn --resource-group lambda-project-2-rg
```

## Step 10 — Decommission Lambda

```bash
aws lambda delete-function --function-name lambda-project-2 --region us-east-1
aws iam detach-role-policy --role-name lambda-execution-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name lambda-execution-role
```