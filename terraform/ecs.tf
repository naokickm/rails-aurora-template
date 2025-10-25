# ECSクラスターの定義（コンテナを実行するための論理的なグループ）
resource "aws_ecs_cluster" "main" {
  # クラスター名を変数から生成
  name = "${var.app_name}-cluster"

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-cluster"
  }
}

# CloudWatch Log Groupの定義（ECSコンテナのログを保存）
resource "aws_cloudwatch_log_group" "ecs" {
  # ログストリームの命名規則に従った名前
  name              = "/ecs/${var.app_name}"
  # ログの保持期間（日数）- コスト削減のため7日間
  retention_in_days = 7


  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-log-groupla
  }
}

# ECSタスク定義（コンテナの設定を定義）
resource "aws_ecs_task_definition" "app" {
  # タスク定義ファミリー名（バージョン管理の単位）
  family                   = var.app_name
  # ネットワークモード
  # - awsvpc: 各タスクに専用のENI（Elastic Network Interface）を割り当て（Fargate必須、最もセキュア）
  # - bridge: Docker bridgeネットワークを使用（EC2のみ、デフォルト）
  # - host: ホストのネットワークを直接使用（EC2のみ、パフォーマンス重視）
  # - none: 外部ネットワーク接続なし（EC2のみ）
  network_mode             = "awsvpc"
  # 起動タイプの互換性
  # - FARGATE: サーバーレス、インフラ管理不要、スケーリング容易（推奨）
  # - EC2: EC2インスタンス上で実行、コスト最適化や特殊要件がある場合に使用
  # - EXTERNAL: オンプレミスや他のクラウド上で実行（AWS Outposts等）
  requires_compatibilities = ["FARGATE"]
  # タスクに割り当てるCPUユニット（1024 = 1 vCPU）
  cpu                      = var.container_cpu
  # タスクに割り当てるメモリ（MB単位）
  memory                   = var.container_memory
  # タスク実行ロール（ECRプル、ログ出力、シークレット取得に必要）
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  # タスクロール（コンテナ内のアプリケーションが使用するAWS権限）
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  # コンテナ定義をJSONエンコードして設定
  container_definitions = jsonencode([
    {
      # コンテナ名
      name      = var.app_name
      # 使用するDockerイメージ（ECRの最新タグを使用）
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      # コンテナの必須フラグ
      # - true: このコンテナが停止したらタスク全体を停止（重要なアプリケーションコンテナ）
      # - false: このコンテナが停止してもタスクは継続（サイドカーコンテナ等）
      essential = true
      # ポートマッピング設定
      portMappings = [
        {
          # コンテナ内のポート番号
          containerPort = var.container_port
          # ホスト側のポート番号（awsvpcモードでは同じ値）
          hostPort      = var.container_port
          # 通信プロトコル
          # - tcp: TCP通信（HTTP/HTTPS等、ほとんどのアプリケーション）
          # - udp: UDP通信（DNS、ストリーミング等）
          protocol      = "tcp"
        }
      ]
      # 環境変数の設定（平文で保存される）
      environment = [
        {
          # Rails実行環境
          name  = "RAILS_ENV"
          value = "production"
        },
        {
          # データベース接続先ホスト（RDSのエンドポイント）
          name  = "DATABASE_HOST"
          value = aws_rds_cluster.main.endpoint
        },
        {
          # Railsログを標準出力に出力（CloudWatch Logsで収集）
          name  = "RAILS_LOG_TO_STDOUT"
          value = "true"
        }
      ]
      # 秘密情報の設定（Secrets Managerから取得）
      secrets = [
        {
          # データベースパスワードの環境変数名
          name      = "MYAPP_DATABASE_PASSWORD"
          # Secrets Managerからパスワードを取得
          valueFrom = aws_secretsmanager_secret_version.db_password.arn
        },
        {
          # Rails暗号化キーの環境変数名
          name      = "RAILS_MASTER_KEY"
          # Secrets ManagerからMaster Keyを取得
          valueFrom = aws_secretsmanager_secret_version.rails_master_key.arn
        }
      ]
      # ログ設定
      logConfiguration = {
        # ログドライバー
        # - awslogs: CloudWatch Logsに送信（AWS統合、推奨）
        # - fluentd: Fluentdに送信（カスタムログ収集）
        # - gelf: Graylogに送信（集中ログ管理）
        # - json-file: JSONファイルとして保存（デフォルト、非推奨）
        # - splunk: Splunkに送信（エンタープライズログ管理）
        # - syslog: Syslogに送信（従来型ログ収集）
        logDriver = "awslogs"
        # ログドライバーのオプション
        options = {
          # ログを送信するCloudWatch Logsグループ
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          # AWSリージョン
          "awslogs-region"        = var.aws_region
          # ログストリーム名のプレフィックス
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-task-definition"
  }
}

# ECSサービスの定義（タスクの実行と管理を行う）
resource "aws_ecs_service" "app" {
  # サービス名
  name            = "${var.app_name}-service"
  # サービスを実行するECSクラスター
  cluster         = aws_ecs_cluster.main.id
  # 使用するタスク定義のARN
  task_definition = aws_ecs_task_definition.app.arn
  # 維持したいタスクの数（変数で設定）
  desired_count   = var.desired_count
  # 起動タイプ
  # - FARGATE: サーバーレスコンテナ、インフラ管理不要（推奨）
  # - EC2: EC2インスタンス上で実行、より細かいコントロールが必要な場合
  # - EXTERNAL: オンプレミスや他のクラウド環境で実行
  launch_type     = "FARGATE"

  # ECS Exec機能の有効化
  # - true: コンテナへの対話的シェルアクセスを許可（デバッグやトラブルシューティングに便利）
  # - false: シェルアクセス無効（セキュリティ重視、本番環境では検討）
  enable_execute_command = true

  # ネットワーク構成
  network_configuration {
    # タスクを起動するプライベートサブネット（マルチAZ構成）
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    # タスクに適用するセキュリティグループ
    security_groups  = [aws_security_group.ecs_tasks.id]
    # パブリックIPの割り当て
    # - false: パブリックIP不要（プライベートサブネット + NAT Gateway経由でインターネット接続、セキュア）
    # - true: パブリックIPを割り当て（パブリックサブネットで直接インターネット接続、コスト削減）
    assign_public_ip = false
  }

  # ロードバランサーとの統合設定
  load_balancer {
    # ALBのターゲットグループARN
    target_group_arn = aws_lb_target_group.app.arn
    # ロードバランサーが転送するコンテナ名
    container_name   = var.app_name
    # コンテナの公開ポート
    container_port   = var.container_port
  }

  # 依存関係の明示（これらが作成されるまでサービスを作成しない）
  depends_on = [
    # ALBリスナーが設定されている必要がある
    aws_lb_listener.app,
    # IAMロールポリシーが適用されている必要がある
    aws_iam_role_policy.ecs_task_execution_role_policy
  ]

  # リソース識別用のタグ
  tags = {
    Name = "${var.app_name}-service"
  }
}

# ========================================
# IAMロール（ECSタスク実行用）
# ========================================

# ECSタスク実行ロール（ECSがタスクを起動・管理するために使用）
resource "aws_iam_role" "ecs_task_execution_role" {
  # ロール名
  name = "${var.app_name}-ecs-task-execution-role"

  # 信頼ポリシー（このロールを引き受けられるエンティティを定義）
  assume_role_policy = jsonencode({
    # IAMポリシー言語のバージョン
    Version = "2012-10-17"
    # ポリシーステートメント
    Statement = [
      {
        # ロール引き受けアクション
        Action = "sts:AssumeRole"
        # ポリシー効果
        # - Allow: アクションを許可（通常はこれを使用）
        # - Deny: アクションを明示的に拒否（Allowより優先される、セキュリティ強化時に使用）
        Effect = "Allow"
        # ECSタスクサービスがこのロールを引き受け可能
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# ECSタスク実行ロールのポリシー（具体的な権限を定義）
resource "aws_iam_role_policy" "ecs_task_execution_role_policy" {
  # ポリシー名
  name   = "${var.app_name}-ecs-task-execution-role-policy"
  # このポリシーをアタッチするロール
  role   = aws_iam_role.ecs_task_execution_role.id
  # ポリシードキュメント
  policy = jsonencode({
    # IAMポリシー言語のバージョン
    Version = "2012-10-17"
    # ポリシーステートメントの配列
    Statement = [
      {
        # 許可
        Effect = "Allow"
        # ECR（コンテナレジストリ）関連の権限
        Action = [
          # ECR認証トークンの取得
          "ecr:GetAuthorizationToken",
          # イメージの一括取得
          "ecr:BatchGetImage",
          # イメージレイヤーのダウンロードURL取得
          "ecr:GetDownloadUrlForLayer",
          # レイヤーの存在確認
          "ecr:BatchCheckLayerAvailability"
        ]
        # 全てのECRリポジトリに対して許可
        Resource = "*"
      },
      {
        # 許可
        Effect = "Allow"
        # CloudWatch Logs関連の権限
        Action = [
          # ログストリームの作成
          "logs:CreateLogStream",
          # ログイベントの送信
          "logs:PutLogEvents"
        ]
        # 作成したロググループにのみ許可
        Resource = "${aws_cloudwatch_log_group.ecs.arn}:*"
      },
      {
        # 許可
        Effect = "Allow"
        # Secrets Manager関連の権限
        Action = [
          # シークレット値の取得
          "secretsmanager:GetSecretValue"
        ]
        # 指定したシークレットのみ取得可能
        Resource = [
          # DBパスワード
          aws_secretsmanager_secret_version.db_password.arn,
          # Rails Master Key
          aws_secretsmanager_secret_version.rails_master_key.arn
        ]
      }
    ]
  })
}

# ========================================
# IAMロール（ECSタスク用）
# ========================================

# ECSタスクロール（コンテナ内のアプリケーションが使用）
resource "aws_iam_role" "ecs_task_role" {
  # ロール名
  name = "${var.app_name}-ecs-task-role"

  # 信頼ポリシー（このロールを引き受けられるエンティティを定義）
  assume_role_policy = jsonencode({
    # IAMポリシー言語のバージョン
    Version = "2012-10-17"
    # ポリシーステートメント
    Statement = [
      {
        # ロール引き受けアクション
        Action = "sts:AssumeRole"
        # ポリシー効果
        # - Allow: アクションを許可（通常はこれを使用）
        # - Deny: アクションを明示的に拒否（Allowより優先される、セキュリティ強化時に使用）
        Effect = "Allow"
        # ECSタスクサービスがこのロールを引き受け可能
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# ECSタスクロールのポリシー（ECS Exec用のSSMアクセス権限）
resource "aws_iam_role_policy" "ecs_task_role_policy" {
  # ポリシー名
  name = "${var.app_name}-ecs-task-role-policy"
  # このポリシーをアタッチするロール
  role = aws_iam_role.ecs_task_role.id

  # ポリシードキュメント
  policy = jsonencode({
    # IAMポリシー言語のバージョン
    Version = "2012-10-17"
    # ポリシーステートメント
    Statement = [
      {
        # 許可
        Effect = "Allow"
        # Systems Manager Messages関連の権限（ECS Execに必要）
        Action = [
          # コントロールチャネルの作成
          "ssmmessages:CreateControlChannel",
          # データチャネルの作成
          "ssmmessages:CreateDataChannel",
          # コントロールチャネルのオープン
          "ssmmessages:OpenControlChannel",
          # データチャネルのオープン
          "ssmmessages:OpenDataChannel"
        ]
        # 全てのリソースに対して許可
        Resource = "*"
      }
    ]
  })
}

# ========================================
# Secrets Manager（機密情報の安全な保管）
# ========================================

# データベースパスワード用のシークレット定義
resource "aws_secretsmanager_secret" "db_password" {
  # シークレット名（一意である必要がある）
  name = "${var.app_name}-db-password"
}

# データベースパスワードのバージョン（実際の値を保存）
resource "aws_secretsmanager_secret_version" "db_password" {
  # 紐付けるシークレットのID
  secret_id     = aws_secretsmanager_secret.db_password.id
  # ランダム生成されたパスワードを保存
  secret_string = random_password.db_password.result
}

# Rails Master Key用のシークレット定義
resource "aws_secretsmanager_secret" "rails_master_key" {
  # シークレット名（一意である必要がある）
  name = "${var.app_name}-rails-master-key"
}

# Rails Master Keyのバージョン（実際の値を保存）
resource "aws_secretsmanager_secret_version" "rails_master_key" {
  # 紐付けるシークレットのID
  secret_id     = aws_secretsmanager_secret.rails_master_key.id
  # 変数から取得したMaster Keyを保存
  secret_string = var.rails_master_key
}