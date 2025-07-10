#!/bin/bash

echo "🚀 Setting up AWS infrastructure in LocalStack..."

# Set AWS CLI to use LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Create S3 buckets
echo "📦 Creating S3 buckets..."
aws s3 mb s3://input-bucket --endpoint-url=$AWS_ENDPOINT_URL
aws s3 mb s3://output-bucket --endpoint-url=$AWS_ENDPOINT_URL

# Create SNS topics
echo "📢 Creating SNS topics..."
aws sns create-topic --name input-topic --endpoint-url=$AWS_ENDPOINT_URL
aws sns create-topic --name output-topic --endpoint-url=$AWS_ENDPOINT_URL

# Create SQS queues
echo "📋 Creating SQS queues..."
aws sqs create-queue --queue-name input-queue --endpoint-url=$AWS_ENDPOINT_URL
aws sqs create-queue --queue-name output-queue --endpoint-url=$AWS_ENDPOINT_URL

# Create secrets
echo "🔐 Creating secrets..."
aws secretsmanager create-secret --name "api-keys" --description "API keys for the application" --secret-string '{"api_key_1":"test_key_value"}' --endpoint-url=$AWS_ENDPOINT_URL

echo "✅ Infrastructure setup completed!"