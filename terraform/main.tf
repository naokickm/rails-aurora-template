# ========================================
# Terraform設定
# ========================================

# Terraformブロック（Terraform自体の設定）
terraform {
  # 必要なプロバイダーの定義
  required_providers {
    # AWSプロバイダーの設定
    aws = {
      # プロバイダーのソース（HashiCorp公式のAWSプロバイダー）
      source  = "hashicorp/aws"
      # プロバイダーのバージョン制約（5.x系を使用、マイナーバージョンアップは許可）
      version = "~> 5.0"
    }
  }
}

# AWSプロバイダーの設定（AWSリソースを操作するための設定）
provider "aws" {
  # デプロイ先のAWSリージョン（変数で指定）
  region = var.aws_region
}

# ========================================
# VPC（Virtual Private Cloud）
# ========================================

# VPCの定義（AWSクラウド内のプライベートネットワーク空間）
resource "aws_vpc" "main" {
  # VPCのIPアドレス範囲（10.0.0.0 ～ 10.0.255.255、65536個のIPアドレス）
  # /16 = サブネットマスク255.255.0.0
  cidr_block           = "10.0.0.0/16"
  # DNSホスト名の有効化（インスタンスにDNSホスト名を自動割り当て）
  enable_dns_hostnames = true
  # DNS解決の有効化（VPC内でDNS解決を使用可能にする）
  enable_dns_support   = true

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# ========================================
# パブリックサブネット（インターネットからアクセス可能）
# ========================================

# パブリックサブネット1（AZ-a）
resource "aws_subnet" "public_1" {
  # 所属するVPC
  vpc_id                  = aws_vpc.main.id
  # サブネットのIPアドレス範囲（10.0.1.0 ～ 10.0.1.255、256個のIPアドレス）
  # /24 = サブネットマスク255.255.255.0
  cidr_block              = "10.0.1.0/24"
  # アベイラビリティゾーン（物理的に分離されたデータセンター）
  availability_zone       = "${var.aws_region}a"
  # インスタンス起動時にパブリックIPを自動割り当て（パブリックサブネットの特徴）
  map_public_ip_on_launch = true

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-public-subnet-1"
  }
}

# パブリックサブネット2（AZ-c）- 冗長性とマルチAZ構成のため
resource "aws_subnet" "public_2" {
  # 所属するVPC
  vpc_id                  = aws_vpc.main.id
  # サブネットのIPアドレス範囲（10.0.2.0 ～ 10.0.2.255、256個のIPアドレス）
  cidr_block              = "10.0.2.0/24"
  # アベイラビリティゾーン（AZ-aとは異なるAZで冗長化）
  availability_zone       = "${var.aws_region}c"
  # インスタンス起動時にパブリックIPを自動割り当て
  map_public_ip_on_launch = true

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-public-subnet-2"
  }
}

# ========================================
# プライベートサブネット（インターネットから直接アクセス不可）
# ========================================

# プライベートサブネット1（AZ-a）
resource "aws_subnet" "private_1" {
  # 所属するVPC
  vpc_id            = aws_vpc.main.id
  # サブネットのIPアドレス範囲（10.0.10.0 ～ 10.0.10.255、256個のIPアドレス）
  cidr_block        = "10.0.10.0/24"
  # アベイラビリティゾーン
  availability_zone = "${var.aws_region}a"

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-private-subnet-1"
  }
}

# プライベートサブネット2（AZ-c）- 冗長性とマルチAZ構成のため
resource "aws_subnet" "private_2" {
  # 所属するVPC
  vpc_id            = aws_vpc.main.id
  # サブネットのIPアドレス範囲（10.0.11.0 ～ 10.0.11.255、256個のIPアドレス）
  cidr_block        = "10.0.11.0/24"
  # アベイラビリティゾーン（AZ-aとは異なるAZで冗長化）
  availability_zone = "${var.aws_region}c"

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-private-subnet-2"
  }
}

# ========================================
# インターネットゲートウェイ（VPCとインターネット間の通信を可能にする）
# ========================================

# インターネットゲートウェイの定義
resource "aws_internet_gateway" "main" {
  # 接続するVPC
  vpc_id = aws_vpc.main.id

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-igw"
  }
}

# ========================================
# パブリックルートテーブル（パブリックサブネット用のルーティング設定）
# ========================================

# パブリックルートテーブルの定義
resource "aws_route_table" "public" {
  # 所属するVPC
  vpc_id = aws_vpc.main.id

  # ルート設定
  route {
    # 宛先（0.0.0.0/0 = 全てのIPアドレス）
    cidr_block      = "0.0.0.0/0"
    # 経路（インターネットゲートウェイ経由でインターネットに接続）
    gateway_id      = aws_internet_gateway.main.id
  }

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-public-rt"
  }
}

# パブリックサブネット1とルートテーブルの関連付け
resource "aws_route_table_association" "public_1" {
  # 関連付けるサブネット
  subnet_id      = aws_subnet.public_1.id
  # 使用するルートテーブル
  route_table_id = aws_route_table.public.id
}

# パブリックサブネット2とルートテーブルの関連付け
resource "aws_route_table_association" "public_2" {
  # 関連付けるサブネット
  subnet_id      = aws_subnet.public_2.id
  # 使用するルートテーブル
  route_table_id = aws_route_table.public.id
}

# ========================================
# NAT Gateway（プライベートサブネットからインターネットへの通信を可能にする）
# ========================================

# NAT Gateway用のElastic IP（固定グローバルIPアドレス）
resource "aws_eip" "nat" {
  # VPC用のEIP
  # domain = "vpc" or "standard"（vpc: VPC用、standard: EC2-Classic用）
  domain = "vpc"

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-nat-eip"
  }
}

# NAT Gatewayの定義
resource "aws_nat_gateway" "main" {
  # 割り当てるElastic IPのID
  allocation_id = aws_eip.nat.id
  # NAT Gatewayを配置するサブネット（パブリックサブネットに配置）
  subnet_id     = aws_subnet.public_1.id

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-nat-gateway"
  }

  # 依存関係の明示（Internet Gatewayが作成されてから作成）
  depends_on = [aws_internet_gateway.main]
}

# ========================================
# プライベートルートテーブル（プライベートサブネット用のルーティング設定）
# ========================================

# プライベートルートテーブルの定義
resource "aws_route_table" "private" {
  # 所属するVPC
  vpc_id = aws_vpc.main.id

  # ルート設定
  route {
    # 宛先（0.0.0.0/0 = 全てのIPアドレス）
    cidr_block     = "0.0.0.0/0"
    # 経路（NAT Gateway経由でインターネットに接続、セキュリティ維持）
    nat_gateway_id = aws_nat_gateway.main.id
  }

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-private-rt"
  }
}

# プライベートサブネット1とルートテーブルの関連付け
resource "aws_route_table_association" "private_1" {
  # 関連付けるサブネット
  subnet_id      = aws_subnet.private_1.id
  # 使用するルートテーブル
  route_table_id = aws_route_table.private.id
}

# プライベートサブネット2とルートテーブルの関連付け
resource "aws_route_table_association" "private_2" {
  # 関連付けるサブネット
  subnet_id      = aws_subnet.private_2.id
  # 使用するルートテーブル
  route_table_id = aws_route_table.private.id
}

# ========================================
# セキュリティグループ（ファイアウォールルール）
# ========================================

# ALB用セキュリティグループ（インターネットからの通信を制御）
resource "aws_security_group" "alb" {
  # 所属するVPC
  vpc_id = aws_vpc.main.id

  # インバウンドルール（HTTP）
  ingress {
    # 開始ポート番号
    from_port   = 80
    # 終了ポート番号
    to_port     = 80
    # プロトコル（tcp, udp, icmp, -1=全て）
    protocol    = "tcp"
    # 許可する送信元IPアドレス範囲（0.0.0.0/0 = 全てのIPアドレス）
    cidr_blocks = ["0.0.0.0/0"]
  }

  # インバウンドルール（HTTPS）
  ingress {
    # 開始ポート番号
    from_port   = 443
    # 終了ポート番号
    to_port     = 443
    # プロトコル
    protocol    = "tcp"
    # 許可する送信元IPアドレス範囲
    cidr_blocks = ["0.0.0.0/0"]
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
    Name = "${var.app_name}-alb-sg"
  }
}

# ECSタスク用セキュリティグループ（ALBからの通信のみ許可）
resource "aws_security_group" "ecs_tasks" {
  # 所属するVPC
  vpc_id = aws_vpc.main.id

  # インバウンドルール（ALBからのアプリケーションポート通信のみ許可）
  ingress {
    # 開始ポート番号（アプリケーションのポート）
    from_port       = var.container_port
    # 終了ポート番号
    to_port         = var.container_port
    # プロトコル
    protocol        = "tcp"
    # 許可する送信元セキュリティグループ（ALBのセキュリティグループのみ）
    security_groups = [aws_security_group.alb.id]
  }

  # アウトバウンドルール（全ての通信を許可）
  egress {
    # 開始ポート（0 = 全てのポート）
    from_port   = 0
    # 終了ポート（0 = 全てのポート）
    to_port     = 0
    # プロトコル（-1 = 全てのプロトコル）
    protocol    = "-1"
    # 許可する宛先IPアドレス範囲（外部APIやパッケージダウンロードに必要）
    cidr_blocks = ["0.0.0.0/0"]
  }

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-ecs-sg"
  }
}

# ========================================
# Application Load Balancer（負荷分散とルーティング）
# ========================================

# ALBの定義
resource "aws_lb" "main" {
  # ロードバランサー名
  name               = "${var.app_name}-alb"
  # 内部/外部の指定
  # - false: インターネット向け（パブリックサブネットに配置）
  # - true: 内部向け（プライベートサブネットに配置、VPC内部からのみアクセス可能）
  internal           = false
  # ロードバランサーのタイプ
  # - application: HTTP/HTTPS用（レイヤー7、パスベースルーティング等が可能）
  # - network: TCP/UDP用（レイヤー4、高パフォーマンス）
  # - gateway: サードパーティ仮想アプライアンス用
  load_balancer_type = "application"
  # 適用するセキュリティグループ
  security_groups    = [aws_security_group.alb.id]
  # ALBを配置するサブネット（マルチAZ構成のため複数指定）
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-alb"
  }
}

# ターゲットグループの定義（ALBが転送する先のグループ）
resource "aws_lb_target_group" "app" {
  # ターゲットグループ名
  name        = "${var.app_name}-tg"
  # ターゲットのポート番号
  port        = var.container_port
  # 通信プロトコル
  # - HTTP: 暗号化なし
  # - HTTPS: SSL/TLS暗号化
  protocol    = "HTTP"
  # 所属するVPC
  vpc_id      = aws_vpc.main.id
  # ターゲットタイプ
  # - ip: IPアドレスでターゲット指定（Fargate、Lambdaで必須）
  # - instance: EC2インスタンスIDでターゲット指定
  # - lambda: Lambda関数
  target_type = "ip"

  # ヘルスチェック設定（ターゲットの正常性を監視）
  health_check {
    # 正常と判定するまでの連続成功回数
    healthy_threshold   = 2
    # 異常と判定するまでの連続失敗回数
    unhealthy_threshold = 2
    # タイムアウト時間（秒）
    timeout             = 3
    # ヘルスチェック間隔（秒）
    interval            = 30
    # ヘルスチェック用のパス
    path                = "/up"
    # 正常と判定するHTTPステータスコード
    matcher             = "200"
  }

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-tg"
  }
}

# ALBリスナーの定義（受信した通信をどう処理するか）
resource "aws_lb_listener" "app" {
  # 所属するロードバランサー
  load_balancer_arn = aws_lb.main.arn
  # リッスンするポート番号
  port              = 80
  # リッスンするプロトコル
  # - HTTP: 暗号化なし
  # - HTTPS: SSL/TLS暗号化（証明書が必要）
  protocol          = "HTTP"

  # デフォルトアクション（ルールにマッチしない場合の処理）
  default_action {
    # アクションタイプ
    # - forward: ターゲットグループに転送
    # - redirect: リダイレクト
    # - fixed-response: 固定レスポンスを返す
    # - authenticate-cognito: Cognito認証
    # - authenticate-oidc: OIDC認証
    type             = "forward"
    # 転送先のターゲットグループ
    target_group_arn = aws_lb_target_group.app.arn
  }
}