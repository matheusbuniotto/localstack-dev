#!/bin/bash

echo "🔗 Configuring event-driven architecture..."

# Set AWS CLI to use LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Get SNS topic ARNs
INPUT_TOPIC_ARN=$(aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL --query 'Topics[?contains(TopicArn, `input-topic`)].TopicArn' --output text)
OUTPUT_TOPIC_ARN=$(aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL --query 'Topics[?contains(TopicArn, `output-topic`)].TopicArn' --output text)

# Get SQS queue URLs and ARNs
INPUT_QUEUE_URL=$(aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL --query 'QueueUrls[?contains(@, `input-queue`)]' --output text)
OUTPUT_QUEUE_URL=$(aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL --query 'QueueUrls[?contains(@, `output-queue`)]' --output text)

INPUT_QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url $INPUT_QUEUE_URL --attribute-names QueueArn --endpoint-url=$AWS_ENDPOINT_URL --query 'Attributes.QueueArn' --output text)
OUTPUT_QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url $OUTPUT_QUEUE_URL --attribute-names QueueArn --endpoint-url=$AWS_ENDPOINT_URL --query 'Attributes.QueueArn' --output text)

echo "📋 Found resources:"
echo "  Input Topic ARN: $INPUT_TOPIC_ARN"
echo "  Output Topic ARN: $OUTPUT_TOPIC_ARN"
echo "  Input Queue ARN: $INPUT_QUEUE_ARN"
echo "  Output Queue ARN: $OUTPUT_QUEUE_ARN"

# Subscribe SQS queues to SNS topics
echo "🔗 Subscribing SQS queues to SNS topics..."
aws sns subscribe --topic-arn $INPUT_TOPIC_ARN --protocol sqs --notification-endpoint $INPUT_QUEUE_ARN --endpoint-url=$AWS_ENDPOINT_URL
aws sns subscribe --topic-arn $OUTPUT_TOPIC_ARN --protocol sqs --notification-endpoint $OUTPUT_QUEUE_ARN --endpoint-url=$AWS_ENDPOINT_URL

# Configure S3 event notification for input bucket
echo "📦 Configuring S3 event notifications..."
cat > /tmp/s3-notification-config.json << EOF
{
  "TopicConfigurations": [
    {
      "Id": "ObjectCreatedEvents",
      "TopicArn": "$INPUT_TOPIC_ARN",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
EOF

aws s3api put-bucket-notification-configuration --bucket input-bucket --notification-configuration file:///tmp/s3-notification-config.json --endpoint-url=$AWS_ENDPOINT_URL

echo "✅ Event-driven architecture configured!"
echo "📈 Data flow: S3 (input-bucket) → SNS (input-topic) → SQS (input-queue)"
echo "📈 Data flow: SNS (output-topic) → SQS (output-queue)"