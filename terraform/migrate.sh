#!/bin/bash

set -e

echo "================================"
echo "Database Migration Script"
echo "================================"
echo ""

CLUSTER_NAME="rails-app-cluster"
SERVICE_NAME="rails-app-service"
CONTAINER_NAME="rails-app"

# ECS Exec が有効化されているか確認
echo "Step 1: ECSサービスの確認..."
SERVICE_STATUS=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query 'services[0].status' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVICE_STATUS" != "ACTIVE" ]; then
    echo "Error: ECSサービスが見つからないか、起動していません"
    echo "ECSサービスが完全に起動するまで待ってから、再度実行してください"
    exit 1
fi

echo "✓ ECSサービスが起動しています"
echo ""

# 実行中のタスクを取得
echo "Step 2: 実行中のタスクを検索..."
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --desired-status RUNNING \
  --query 'taskArns[0]' \
  --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
    echo "Error: 実行中のタスクが見つかりません"
    echo "ECSタスクが起動するまで待ってから、再度実行してください"
    exit 1
fi

TASK_ID=$(echo $TASK_ARN | cut -d'/' -f3)
echo "✓ タスクが見つかりました: $TASK_ID"
echo ""

# マイグレーションの実行
echo "Step 3: データベースマイグレーションの実行..."
echo ""
echo "注意: ECS Exec が有効化されていない場合、このコマンドは失敗する可能性があります"
echo "その場合は、一時的なタスクでマイグレーションを実行してください（README参照）"
echo ""

aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ID \
  --container $CONTAINER_NAME \
  --interactive \
  --command "bin/rails db:migrate"

echo ""
echo "✓ マイグレーション完了"
