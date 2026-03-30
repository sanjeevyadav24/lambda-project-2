import azure.functions as func

app = func.FunctionApp()


@app.route(route="hello", methods=["GET", "POST"])
def lambda_handler(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse("Hello from Azure Functions!", status_code=200)
