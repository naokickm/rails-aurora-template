# ========================================
# 変数定義（Terraformで使用する変数を定義）
# ========================================

# AWSリージョンの変数定義
variable "aws_region" {
  # デフォルト値（変数が指定されない場合に使用される値）
  # - ap-northeast-1: 東京リージョン（日本向けサービスに最適）
  # - us-east-1: バージニア北部（多くのAWSサービスが最初にリリースされる）
  # - us-west-2: オレゴン（米国西海岸向け）
  # - eu-west-1: アイルランド（ヨーロッパ向け）
  default = "ap-northeast-1"
}

# アプリケーション名の変数定義
variable "app_name" {
  # デフォルト値（リソース名のプレフィックスとして使用）
  # この値は各リソース名に含まれ、識別しやすくする
  default = "rails-app"
}

# 環境名の変数定義
variable "environment" {
  # デフォルト値（実行環境の識別）
  # - production: 本番環境
  # - staging: ステージング環境
  # - development: 開発環境
  default = "production"
}

# コンテナポートの変数定義
variable "container_port" {
  # デフォルト値（アプリケーションが使用するポート番号）
  # - 3000: Railsのデフォルトポート
  # - 8080: 一般的なWebアプリケーションポート
  # - 80: HTTP標準ポート
  default = 3000
}

# コンテナCPUユニットの変数定義
variable "container_cpu" {
  # 変数の説明（ドキュメント目的）
  description = "ECS task CPU units (256 = 0.25 vCPU, smallest option)"
  # デフォルト値（ECSタスクに割り当てるCPUユニット）
  # Fargate CPU/メモリの組み合わせ（一部のみ記載）:
  # - 256 (0.25 vCPU): メモリ 512MB, 1GB, 2GB
  # - 512 (0.5 vCPU): メモリ 1GB～4GB
  # - 1024 (1 vCPU): メモリ 2GB～8GB
  # - 2048 (2 vCPU): メモリ 4GB～16GB
  default     = 256
}

# コンテナメモリの変数定義
variable "container_memory" {
  # 変数の説明
  description = "ECS task memory in MB (512MB, smallest option for CPU 256)"
  # デフォルト値（ECSタスクに割り当てるメモリ、MB単位）
  # CPU 256の場合の選択肢: 512MB, 1GB (1024MB), 2GB (2048MB)
  # 512MBが最小、コスト削減に有効
  default     = 512
}

# 実行タスク数の変数定義
variable "desired_count" {
  # 変数の説明
  description = "Number of ECS tasks to run (1 = cheapest, 2+ = high availability)"
  # デフォルト値（維持したいECSタスクの数）
  # - 1: 最小コスト、単一障害点あり（開発環境向け）
  # - 2: 高可用性、冗長化（本番環境推奨）
  # - 3+: より高い可用性とスケーラビリティ
  default     = 1
}

# Rails Master Keyの変数定義
variable "rails_master_key" {
  # 変数の説明
  description = "Rails master key for credentials encryption"
  # データ型（stringで文字列を期待）
  # 他の型: number, bool, list, map, object等
  type        = string
  # 機密情報フラグ
  # - true: terraform planやapplyの出力で値を隠す
  # - false: 値を表示する（デフォルト）
  # この変数にはデフォルト値がないため、terraform apply実行時に必須入力
  sensitive   = true
}