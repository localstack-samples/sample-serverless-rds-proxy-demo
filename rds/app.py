import boto3
import json
from os import environ
from urllib.parse import urlparse

import psycopg2


endpoint_url = environ.get("AWS_ENDPOINT_URL")
url = urlparse(endpoint_url)
host = url.hostname

client = boto3.client('rds', endpoint_url=endpoint_url)
sm = boto3.client('secretsmanager', endpoint_url=endpoint_url)


def db_ops():
    secret_arn = sm.list_secrets()["SecretList"][0]["ARN"]
    secret = sm.get_secret_value(SecretId=secret_arn)
    username = json.loads(secret["SecretString"]).get('username')
    password = json.loads(secret["SecretString"]).get('password')

    try:
        # create a connection object
        connection = psycopg2.connect(
            host=host,
            database="mylab",
            user=username,
            password=password,
            port=4510,
        )
    except psycopg2.Error as e:
        return e

    return connection


def lambda_handler(event, context):
    conn = db_ops()
    cursor = conn.cursor()
    query = "SELECT version()"
    cursor.execute(query)
    results = cursor.fetchmany(1)

    return {
        'statusCode': 200,
        'body': json.dumps(results, default=str)
    }
