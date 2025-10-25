#!/bin/bash

set -e

echo "================================"
echo "Rails App AWS Deployment Script"
echo "================================"
echo ""

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# terraform.tfvarsの存在確認
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars が見つかりません${NC}"
    echo ""
    echo "以下のコマンドで作成してください："
    echo "  cp terraform.tfvars.example terraform.tfvars"
    echo ""
    echo "その後、terraform.tfvars を編集して rails_master_key を設定してください："
    echo "  nano terraform.tfvars"
    exit 1
fi

# RAILS_MASTER_KEYが設定されているか確認
if grep -q "YOUR_RAILS_MASTER_KEY_HERE" terraform.tfvars; then
    echo -e "${RED}Error: rails_master_key が設定されていません${NC}"
    echo ""
    echo "terraform.tfvars を編集して、実際のRAILS_MASTER_KEYを設定してください："
    echo "  nano terraform.tfvars"
    echo ""
    echo "RAILS_MASTER_KEYは config/master.key にあります："
    echo "  cat ../config/master.key"
    exit 1
fi

echo -e "${GREEN}✓ terraform.tfvars が見つかりました${NC}"
echo ""

# Terraformの初期化
echo "Step 1: Terraform の初期化..."
terraform init
echo -e "${GREEN}✓ 初期化完了${NC}"
echo ""

# 実行プランの確認
echo "Step 2: 実行プランの確認..."
terraform plan -out=tfplan
echo -e "${GREEN}✓ プラン作成完了${NC}"
echo ""

# 適用の確認
echo -e "${YELLOW}上記のプランを適用しますか？${NC}"
echo "このステップで以下が作成されます："
echo "  - VPC、サブネット、NAT Gateway"
echo "  - RDS MySQL (約10-15分かかります)"
echo "  - ECS Cluster、ALB"
echo "  - ECR Repository"
echo ""
read -p "続行しますか？ (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "デプロイをキャンセルしました"
    rm -f tfplan
    exit 0
fi

# Terraformの適用
echo "Step 3: インフラストラクチャのデプロイ..."
terraform apply tfplan
rm -f tfplan
echo -e "${GREEN}✓ デプロイ完了${NC}"
echo ""

# 出力の表示
echo "================================"
echo "デプロイ情報"
echo "================================"
terraform output
echo ""

# ECRリポジトリURLを取得
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")

if [ -n "$ECR_REPO" ]; then
    echo "================================"
    echo "次のステップ: Dockerイメージのプッシュ"
    echo "================================"
    echo ""
    echo "1. ECRにログイン："
    echo "   aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin $ECR_REPO"
    echo ""
    echo "2. Dockerイメージをビルド："
    echo "   cd .."
    echo "   docker build -t $ECR_REPO:latest ."
    echo ""
    echo "3. イメージをプッシュ："
    echo "   docker push $ECR_REPO:latest"
    echo ""
    echo "4. ECSサービスが起動したら、マイグレーションを実行："
    echo "   ./terraform/migrate.sh"
    echo ""
fi

echo -e "${GREEN}デプロイスクリプトが完了しました！${NC}"
