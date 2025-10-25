# コスト最適化ガイド

## 現在の設定（最安構成）

このTerraform構成は、開発・テスト環境向けに最小コストで設定されています。

### 月額コスト概算（東京リージョン）

| リソース | スペック | 月額コスト（概算） |
|---------|---------|-----------------|
| ECS Fargate | 1タスク, 0.25vCPU, 0.5GB | ~$10 |
| RDS MySQL | db.t3.micro, 20GB | ~$25 |
| ALB | 基本料金 | ~$25 |
| NAT Gateway | 基本料金 + データ転送 | ~$35 |
| データ転送 | 変動 | ~$5 |
| **合計** | | **約$100/月** |

## さらにコストを削減する方法

### 1. NAT Gatewayの削除（月額 -$35）

**最も高額なコンポーネント**がNAT Gatewayです。削除する場合：

#### オプションA: ECSをパブリックサブネットで実行

```hcl
# ecs.tf を編集
resource "aws_ecs_service" "app" {
  # ...
  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]  # プライベート→パブリック
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true  # false→true
  }
}
```

**メリット**: 月額$35削減
**デメリット**: セキュリティが低下（ECSタスクがインターネットに直接公開）

#### オプションA実行後の削除

NAT Gatewayとその関連リソースを削除：

```bash
# main.tf から以下を削除:
# - aws_eip.nat
# - aws_nat_gateway.main
# - aws_route_table.private
# - aws_route_table_association.private_1
# - aws_route_table_association.private_2
```

### 2. 開発時のみ起動（月額 -$70〜90）

使わない時はインフラを停止：

```bash
# 全リソース削除
terraform destroy

# 使う時だけ起動
terraform apply
```

または、ECSタスクのみ停止：

```bash
# タスク数を0に
aws ecs update-service \
  --cluster rails-app-cluster \
  --service rails-app-service \
  --desired-count 0

# 再開
aws ecs update-service \
  --cluster rails-app-cluster \
  --service rails-app-service \
  --desired-count 1
```

RDSも停止可能（最大7日間）：

```bash
# RDS停止
aws rds stop-db-instance --db-instance-identifier rails-app-db

# RDS起動
aws rds start-db-instance --db-instance-identifier rails-app-db
```

### 3. AWS Free Tier（無料枠）を活用

新規AWSアカウントの場合、12ヶ月間の無料枠：

- **RDS**: db.t2.micro/db.t3.micro 750時間/月（無料）
- **ALB**: 無料枠なし（有料）
- **NAT Gateway**: 無料枠なし（有料）
- **データ転送**: 15GB/月まで無料

RDSをdb.t2.microに変更して無料枠を使う：

```hcl
# rds.tf
resource "aws_db_instance" "main" {
  instance_class = "db.t2.micro"  # db.t3.micro → db.t2.micro
  # ...
}
```

### 4. スポットインスタンス（ECS Fargateでは不可）

Fargate Spotを使う（最大70%割引）：

```hcl
# ecs.tf
resource "aws_ecs_service" "app" {
  # ...
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }
  # launch_type = "FARGATE" を削除
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE_SPOT"]
}
```

**注意**: タスクが予告なく終了する可能性があります。

### 5. リザーブドインスタンス（本番環境向け）

1年または3年契約で最大60%割引：

- RDS Reserved Instances
- コミット不要、本番環境で継続利用する場合のみ推奨

## 推奨構成

### 開発・テスト環境（現在の設定）

```
月額: ~$100
- ECS: 1タスク
- RDS: db.t3.micro
- NAT Gateway: あり
```

### 超低コスト構成（セキュリティ低下）

```
月額: ~$65
- ECS: 1タスク（パブリックサブネット）
- RDS: db.t3.micro
- NAT Gateway: なし
```

### 本番環境（高可用性）

```
月額: ~$150
- ECS: 2タスク（異なるAZ）
- RDS: db.t3.small + Multi-AZ
- NAT Gateway: あり
- バックアップ: 7日
```

## コスト監視

### AWS Cost Explorerで確認

```bash
# 今月のコストを確認
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

### Budgetアラートの設定

AWSコンソール → Billing → Budgets で月額予算を設定：

- 例: 月額$100を超えたらメール通知

## まとめ

**最安構成（現在）**:
- ✅ ECS: 1タスク（最小）
- ✅ RDS: db.t3.micro（最小）
- ✅ バックアップ: 1日（最小）
- ⚠️ NAT Gateway: あり（削除で-$35/月）

**さらに削減するには**:
1. NAT Gatewayを削除してECSをパブリックサブネットで実行（-$35/月）
2. 使わない時は停止する（-$70〜90/月）
3. Fargate Spotを使う（-$7/月）
