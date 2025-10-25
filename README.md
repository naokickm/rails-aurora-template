# Deploy Test

Rails 7.2アプリケーション with Docker

## 技術スタック

- **Ruby**: 3.2.9
- **Rails**: 7.2.2
- **Database**: MySQL 8.4
- **Testing**: RSpec, FactoryBot, Faker
- **Authentication**: Devise
- **Container**: Docker, Docker Compose

## 必要な環境

- Docker
- Docker Compose

## セットアップ手順

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd deploy-test
```

### 2. Dockerイメージのビルド

```bash
docker-compose build
```

### 3. データベースのセットアップ

```bash
# コンテナを起動
docker-compose up -d

# データベース作成
docker-compose exec web rails db:create

# マイグレーション実行
docker-compose exec web rails db:migrate

# テスト用データベースのセットアップ
docker-compose exec web rails db:create RAILS_ENV=test
docker-compose exec web rails db:migrate RAILS_ENV=test
```

### 4. 開発サーバーの起動

```bash
docker-compose up
```

アプリケーションは http://localhost:3000 でアクセスできます。

## よく使うコマンド

### コンテナ操作

```bash
# コンテナ起動
docker-compose up

# バックグラウンドで起動
docker-compose up -d

# コンテナ停止
docker-compose down

# コンテナの状態確認
docker-compose ps

# コンテナ再起動
docker-compose restart web
```

### Rails コマンド

```bash
# Railsコンソール
docker-compose exec web rails console

# マイグレーション作成
docker-compose exec web rails generate migration MigrationName

# マイグレーション実行
docker-compose exec web rails db:migrate

# マイグレーションロールバック
docker-compose exec web rails db:rollback

# ルーティング確認
docker-compose exec web rails routes

# Gemのインストール
docker-compose exec web bundle install
```

### テスト

```bash
# 全テスト実行
docker-compose exec web bundle exec rspec

# 特定のファイルのテスト実行
docker-compose exec web bundle exec rspec spec/models/user_spec.rb

# 特定の行のテスト実行
docker-compose exec web bundle exec rspec spec/models/user_spec.rb:10
```

### データベース操作

```bash
# データベースに接続
docker-compose exec db mysql -uroot -ppassword myapp_development

# データベースリセット（開発環境）
docker-compose exec web rails db:reset

# シードデータ投入
docker-compose exec web rails db:seed

# rails runnerでユーザー作成
docker-compose exec web rails runner "User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')"
```

## データベース接続情報

### 開発環境 (development)

- **Host**: localhost
- **Port**: 3306
- **Database**: myapp_development
- **Username**: root
- **Password**: password

### テスト環境 (test)

- **Host**: localhost
- **Port**: 3306
- **Database**: myapp_test
- **Username**: root
- **Password**: password

TablePlusなどのDBクライアントから接続可能です。

## 認証機能（Devise）

### 主要なURL

- ユーザー登録: http://localhost:3000/users/sign_up
- ログイン: http://localhost:3000/users/sign_in
- パスワードリセット: http://localhost:3000/users/password/new
- アカウント編集: http://localhost:3000/users/edit

### コントローラーで認証を必須にする

```ruby
class YourController < ApplicationController
  before_action :authenticate_user!

  def index
    @current_user = current_user
  end
end
```

### Deviseビューのカスタマイズ

```bash
docker-compose exec web rails generate devise:views
```

## トラブルシューティング

### ポート競合エラー

ポート3000や3306が既に使用されている場合：

```bash
# 使用中のプロセスを確認
lsof -i :3000
lsof -i :3306

# または docker-compose.yml のポート設定を変更
```

### データベース接続エラー

```bash
# データベースコンテナが起動しているか確認
docker-compose ps

# データベースコンテナを再起動
docker-compose restart db

# ログを確認
docker-compose logs db
```

### Gemの依存関係エラー

```bash
# bundle install を実行
docker-compose exec web bundle install

# コンテナを再ビルド
docker-compose build --no-cache
docker-compose up
```

### マイグレーションエラー

```bash
# マイグレーション状態を確認
docker-compose exec web rails db:migrate:status

# データベースをリセット（注意: データが消えます）
docker-compose exec web rails db:drop db:create db:migrate
```

## AWSへのデプロイ

このアプリケーションはTerraformを使ってAWSにデプロイできます。

### クイックスタート

```bash
# 1. 設定ファイルの作成
cd terraform
cp terraform.tfvars.example terraform.tfvars

# 2. RAILS_MASTER_KEYを設定
nano terraform.tfvars
# rails_master_key に config/master.key の内容を貼り付ける

# 3. デプロイ実行
./deploy.sh
```

詳細は [terraform/README.md](terraform/README.md) を参照してください。

### デプロイされる構成

- **ECS Fargate**: コンテナ化されたRailsアプリケーション
- **RDS MySQL 8.0**: マネージドデータベース
- **ALB**: ロードバランサー
- **VPC**: プライベートネットワーク環境

## ディレクトリ構造

```
.
├── app/              # アプリケーションコード
├── config/           # 設定ファイル
├── db/               # データベース関連
├── spec/             # RSpecテスト
├── terraform/        # インフラコード（Terraform）
├── Dockerfile        # Dockerイメージ定義
├── docker-compose.yml # Docker Compose設定
└── Gemfile           # Gem依存関係
```

## 開発フロー

1. 新しいブランチを作成
2. 機能開発・バグ修正
3. テストを書く
4. RSpecでテスト実行
5. コミット・プッシュ
6. プルリクエスト作成

## ライセンス

(ライセンス情報を追加してください)