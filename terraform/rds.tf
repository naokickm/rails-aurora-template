# ========================================
# RDS用セキュリティグループ（データベースへのアクセス制御）
# ========================================

# RDS用セキュリティグループの定義
resource "aws_security_group" "rds" {
  # 所属するVPC
  vpc_id = aws_vpc.main.id

  # インバウンドルール（ECSタスクからのMySQL接続のみ許可）
  ingress {
    # 開始ポート番号（MySQL/Auroraのデフォルトポート）
    # - 3306: MySQL/Aurora MySQL
    # - 5432: PostgreSQL/Aurora PostgreSQL
    from_port       = 3306
    # 終了ポート番号
    to_port         = 3306
    # プロトコル
    protocol        = "tcp"
    # 許可する送信元セキュリティグループ（ECSタスクのセキュリティグループのみ）
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  # アウトバウンドルール（全ての通信を許可）
  egress {
    # 開始ポート（0 = 全てのポート）
    from_port   = 0
    # 終了ポート（0 = 全てのポート）
    to_port     = 0
    # プロトコル（-1 = 全てのプロトコル）
    protocol    = "-1"
    # 許可する宛先IPアドレス範囲
    cidr_blocks = ["0.0.0.0/0"]
  }

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-rds-sg"
  }
}

# ========================================
# DBサブネットグループ（RDSを配置するサブネットの定義）
# ========================================

# DBサブネットグループの定義
resource "aws_db_subnet_group" "main" {
  # サブネットグループ名
  name       = "${var.app_name}-db-subnet-group"
  # RDSを配置するサブネット（マルチAZ構成のため複数のプライベートサブネット）
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

# ========================================
# Aurora RDSクラスター（データベース本体の定義）
# ========================================

# Aurora RDSクラスターの定義
resource "aws_rds_cluster" "main" {
  # クラスター識別子（一意の名前）
  cluster_identifier      = "${var.app_name}-aurora-cluster"
  # データベースエンジン
  # - aurora-mysql: Aurora MySQL互換（MySQLベース）
  # - aurora-postgresql: Aurora PostgreSQL互換（PostgreSQLベース）
  # - aurora: Aurora MySQL 5.6互換（旧バージョン）
  engine                  = "aurora-mysql"
  # エンジンバージョン（使用するデータベースのバージョン）
  engine_version          = "8.0.mysql_aurora.3.04.0"
  # 初期データベース名（クラスター作成時に作成されるデータベース）
  database_name           = "myapp_production"
  # マスターユーザー名（管理者アカウント）
  master_username         = "myapp"
  # マスターパスワード（ランダム生成されたパスワードを使用）
  master_password         = random_password.db_password.result

  # DBサブネットグループ（RDSを配置するサブネット）
  db_subnet_group_name    = aws_db_subnet_group.main.name
  # VPCセキュリティグループ（アクセス制御）
  vpc_security_group_ids  = [aws_security_group.rds.id]

  # 最終スナップショットのスキップ
  # - true: クラスター削除時にスナップショットを作成しない（開発環境向け）
  # - false: クラスター削除時に最終スナップショットを作成（本番環境推奨）
  skip_final_snapshot     = true
  # バックアップ保持期間（日数）
  # - 1～35: 自動バックアップを保持する日数
  # - 1: 最小バックアップ期間（コスト削減、開発環境向け）
  # - 7: 本番環境推奨
  backup_retention_period = 1

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-aurora-cluster"
  }
}

# ========================================
# Aurora RDSクラスターインスタンス（実際の計算リソース）
# ========================================

# Aurora RDSクラスターインスタンスの定義
resource "aws_rds_cluster_instance" "main" {
  # インスタンス識別子（一意の名前）
  identifier         = "${var.app_name}-aurora-instance-1"
  # 所属するクラスター
  cluster_identifier = aws_rds_cluster.main.id
  # インスタンスクラス（コンピューティングとメモリ容量）
  # - db.t3.small: 2vCPU, 2GB RAM（Aurora最小インスタンス、t3.microは非対応）
  # - db.t3.medium: 2vCPU, 4GB RAM
  # - db.r5.large: 2vCPU, 16GB RAM（メモリ最適化）
  instance_class     = "db.t3.small"
  # データベースエンジン（クラスターの設定を継承）
  engine             = aws_rds_cluster.main.engine
  # エンジンバージョン（クラスターの設定を継承）
  engine_version     = aws_rds_cluster.main.engine_version

  # パブリックアクセス可否
  # - false: プライベートサブネット内のみアクセス可能（セキュア、推奨）
  # - true: インターネットから直接アクセス可能（非推奨）
  publicly_accessible = false

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-aurora-instance-1"
  }
}

# ========================================
# ランダムパスワード生成（セキュアなパスワードを自動生成）
# ========================================

# ランダムパスワードリソースの定義
resource "random_password" "db_password" {
  # パスワードの長さ（文字数）
  # - 推奨: 16文字以上
  # - ここでは32文字で強固なパスワードを生成
  length  = 32
  # 特殊文字を含める
  # - true: 記号(!@#$%等)を含む、より強固なパスワード
  # - false: 英数字のみ
  special = true
}

# ========================================
# 出力（他のリソースやモジュールから参照可能な値）
# ========================================

# データベースパスワードの出力
output "db_password" {
  # 出力する値（ランダム生成されたパスワード）
  value     = random_password.db_password.result
  # 機密情報フラグ
  # - true: terraform applyやplanの出力で値を隠す（パスワード等の機密情報）
  # - false: 値を表示する
  sensitive = true
}

# データベースエンドポイントの出力
output "db_endpoint" {
  # 出力する値（RDSクラスターの接続エンドポイント）
  # 形式: <cluster-identifier>.cluster-<random>.ap-northeast-1.rds.amazonaws.com
  value = aws_rds_cluster.main.endpoint
}