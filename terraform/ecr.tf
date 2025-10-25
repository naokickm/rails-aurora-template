# ECRリポジトリリソースの定義
resource "aws_ecr_repository" "app" {
  # リポジトリ名を変数から取得
  name                 = var.app_name
  # イメージタグの変更を許可（MUTABLE: 同じタグで上書き可能、IMMUTABLE: 同じタグで上書き不可）
  image_tag_mutability = "MUTABLE"
  # terraform destroy実行時にリポジトリ内のイメージも含めて削除する
  force_delete         = true

  # イメージスキャンの設定
  image_scanning_configuration {
    # プッシュ時の自動脆弱性スキャンを無効化（コスト削減のため）
    scan_on_push = false
  }

  # リソースにタグを付与
  tags = {
    # リポジトリの識別用タグ
    Name = "${var.app_name}-ecr"
  }
}

# ECRリポジトリのURLを出力（他のリソースから参照可能にする）
output "ecr_repository_url" {
  # リポジトリのフルURLを出力（docker pushで使用）
  value = aws_ecr_repository.app.repository_url
}