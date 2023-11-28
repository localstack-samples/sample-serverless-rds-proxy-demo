import json
import boto3
from os import environ
from urllib.parse import urlparse

import psycopg2


endpoint_url = environ.get("AWS_ENDPOINT_URL")
url = urlparse(endpoint_url)
hostname = url.hostname

client = boto3.client('rds', endpoint_url=endpoint_url)  # get the rds object


def create_proxy_connection_token(username):
    # get the required parameters to create a token
    region = environ.get('region')
    port = 4510 # database port

    # generate the authentication token -- temporary password
    token = client.generate_db_auth_token(
        DBHostname=hostname,
        Port=port,
        DBUsername=username,
        Region=region
    )

    return token


def db_ops():
    username = "test_iam_user"

    token = create_proxy_connection_token(username)

    try:
        # create a connection object
        connection = psycopg2.connect(
            host=hostname,
            database="mylab",
            user=username,
            password=token,
            port= 4510,
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
