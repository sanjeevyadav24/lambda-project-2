import json

def lambda_handler(event, context):
    """
    Handles an AWS Lambda invocation.

    :param event: The event data (input payload) to the Lambda function.
    :param context: Contains information about the invocation.
    :return: A dictionary with a status code and a JSON body.
    """
    print("Hello from Lambda!")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }