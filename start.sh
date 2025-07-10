#!/bin/bash

echo "🚀 Starting LocalStack Development Environment..."

# Load environment variables
source .env-dev

# Start LocalStack
echo "📦 Starting LocalStack container..."
docker compose up -d

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to be ready..."
sleep 10

# Setup infrastructure
echo "🔧 Setting up AWS infrastructure..."
./scripts/setup-infrastructure.sh

# Configure event-driven architecture
echo "🔗 Configuring event-driven architecture..."
./scripts/configure-events.sh

echo "✅ LocalStack development environment is ready!"
echo ""
echo "📋 Available services:"
echo "  • S3 buckets: input-bucket, output-bucket"
echo "  • SNS topics: input-topic, output-topic"
echo "  • SQS queues: input-queue, output-queue"
echo "  • Secrets Manager: api-keys"
echo ""
echo "🌐 LocalStack endpoint: http://localhost:4566"
echo "📄 Environment variables loaded from .env-dev"
echo ""
echo "🧪 To test the data flow:"
echo "  aws s3 cp yourfile.txt s3://input-bucket/ --endpoint-url=http://localhost:4566"