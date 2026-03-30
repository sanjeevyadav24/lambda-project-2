# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Single AWS Lambda function (`lambda_function.py`) migrated to Azure Functions (`function_app.py`). Python 3.12, no custom dependencies.

## Architecture

| File | Purpose |
|---|---|
| `lambda_function.py` | Original AWS Lambda handler |
| `function_app.py` | Azure Functions HTTP trigger (v2 model) |
| `host.json` | Azure Functions runtime config |
| `requirements.txt` | `azure-functions` dependency |
| `event.json` | Local test payload |
| `load_env.sh` | Resolves AWS account ID via CLI and exports env vars |
| `.env` | Local env vars — **never commit** |

## AWS Lambda

```bash
# Test locally
python3 -c "import json; from lambda_function import lambda_handler; print(lambda_handler(json.load(open('event.json')), None))"

# Package & deploy
python3 -c "import zipfile; z=zipfile.ZipFile('function.zip','w'); z.write('lambda_function.py'); z.close()"
aws lambda update-function-code --function-name lambda-project-2 --zip-file fileb://function.zip --region us-east-1

# Invoke & logs
aws lambda invoke --function-name lambda-project-2 --payload file://event.json --cli-binary-format raw-in-base64-out response.json --region us-east-1
aws logs tail /aws/lambda/lambda-project-2 --follow
```

## Azure Functions

```bash
# Test locally
func start
curl http://localhost:7071/api/hello

# Deploy
func azure functionapp publish lambda-project-2-fn

# Verify
curl "https://lambda-project-2-fn.azurewebsites.net/api/hello?code=<function-key>"
```

Live endpoint: `https://lambda-project-2-fn.azurewebsites.net/api/hello`
Azure resource group: `lambda-project-2-rg` (centralindia)

---

## Migration: AWS Lambda → Azure Functions

Reference: https://learn.microsoft.com/en-us/azure/azure-functions/migration/migrate-aws-lambda-to-azure-functions

### AWS → Azure Concepts
| AWS Lambda | Azure Functions |
|---|---|
| `lambda_handler(event, context)` | `@app.route()` + `func.HttpRequest` |
| API Gateway HTTP trigger | HTTP trigger (built-in) |
| CloudWatch Logs | Application Insights |
| IAM execution role | Managed Identity + RBAC |

### Step 1 — Rewrite Handler
```python
# Azure (function_app.py)
import azure.functions as func
app = func.FunctionApp()

@app.route(route="hello", methods=["GET", "POST"])
def lambda_handler(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse("Hello from Azure Functions!", status_code=200)
```

### Step 2 — Scaffold Project
```bash
npm install -g azure-functions-core-tools@4
func init . --worker-runtime python --model V2
```

### Step 3 — Create Azure Resources
```bash
az group create --name lambda-project-2-rg --location centralindia
az storage account create --name lp2storage248 --resource-group lambda-project-2-rg --sku Standard_LRS --location centralindia
az functionapp create \
  --resource-group lambda-project-2-rg \
  --name lambda-project-2-fn \
  --storage-account lp2storage248 \
  --consumption-plan-location centralindia \
  --runtime python --runtime-version 3.12 \
  --functions-version 4 --os-type linux
```

### Step 4 — Migrate Environment Variables
```bash
az functionapp config appsettings set \
  --name lambda-project-2-fn \
  --resource-group lambda-project-2-rg \
  --settings ENV=production LOG_LEVEL=INFO
```

### Step 5 — Deploy & Verify
```bash
func azure functionapp publish lambda-project-2-fn
curl "https://lambda-project-2-fn.azurewebsites.net/api/hello?code=<function-key>"
```

### Step 6 — Decommission Lambda
```bash
aws lambda delete-function --function-name lambda-project-2 --region us-east-1
aws iam detach-role-policy --role-name lambda-execution-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name lambda-execution-role
```
