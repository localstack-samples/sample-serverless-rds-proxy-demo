samlocal deploy -t rds-with-proxy.yaml\
    --stack-name sam-infra \
    --region us-east-1 \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset \
    --no-confirm-changeset 

samlocal list stack-outputs \
    --stack-name sam-infra \
    --region us-east-1 \
    --output json > output-infra.json

vpc_id=$(jq -r '.[] | select(.OutputKey=="vpcId") | .OutputValue' output-infra.json)
subnet_ids=$(jq -r '.[] | select(.OutputKey=="subnetIds") | .OutputValue' output-infra.json)
cluster_endpoint=$(jq -r '.[] | select(.OutputKey=="clusterEndpoint") | .OutputValue' output-infra.json)
rds_proxy_endpoint=$(jq -r '.[] | select(.OutputKey=="rdsProxyEndpoint") | .OutputValue' output-infra.json)
db_proxy_resource_id=$(jq -r '.[] | select(.OutputKey=="dbProxyResourceId") | .OutputValue' output-infra.json)
database_port=$(jq -r '.[] | select(.OutputKey=="databasePort") | .OutputValue' output-infra.json)
secret_arn=$(jq -r '.[] | select(.OutputKey=="secretArn") | .OutputValue' output-infra.json)
lambda_sg_group_id=$(jq -r '.[] | select(.OutputKey=="lambdaSgGroupId") | .OutputValue' output-infra.json)

samlocal build --use-container
samlocal deploy \
    --stack-name sam-app \
    --region us-east-1 \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset \
    --no-confirm-changeset \
    --resolve-s3 \
    --parameter-overrides \
        Vpc=$vpc_id \
        Subnets=$subnet_ids \
        RdsEndpoint=$cluster_endpoint \
        RdsProxyEndpoint=$rds_proxy_endpoint \
        ProxyResourceId=$db_proxy_resource_id \
        Port=$database_port \
        SecretArn=$secret_arn \
        CreateFunctionSecurityGroup=True \
        LambdaSecurityGroupId=$lambda_sg_group_id

samlocal list stack-outputs \
    --stack-name sam-app \
    --region us-east-1 \
    --output json > output-app.json

api_base_path=$(jq -r '.[] | select(.OutputKey=="ApiBasePath") | .OutputValue' output-app.json)
api_base_path=${api_base_path%.*}
api_base_path=${api_base_path%.*}

yq e '.config.target = "'${api_base_path}.localhost.localstack.cloud:4566'"' -i load-no-proxy.yml
yq e '.config.target = "'${api_base_path}.localhost.localstack.cloud:4566'"' -i load-proxy.yml

python create-user.py
