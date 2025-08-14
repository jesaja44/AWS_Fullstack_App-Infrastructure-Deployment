data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ssm_role" {
  name               = "ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# SSM (für Session Manager)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3: Bucket-Config READ + Objekt RW (nur dein Bucket)
data "aws_iam_policy_document" "s3_limited" {
  # Bucket-scope (nur lesen)
  statement {
    sid = "BucketReadChecks"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketPolicyStatus"
    ]
    resources = [aws_s3_bucket.avatars.arn]
  }

  # Objekt-scope (lesen/schreiben/löschen)
  statement {
    sid       = "ObjectRW"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.avatars.arn}/*"]
  }
}

resource "aws_iam_policy" "s3_limited" {
  name   = "ec2-s3-avatars-limited"
  policy = data.aws_iam_policy_document.s3_limited.json
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.s3_limited.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
