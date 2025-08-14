[![Terraform CI](https://github.com/jesaja44/AWS_Fullstack_App-Infrastructure-Deployment/actions/workflows/terraform.yml/badge.svg)](https://github.com/jesaja44/AWS_Fullstack_App-Infrastructure-Deployment/actions/workflows/terraform.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

# AWS Fullstack App – Infrastructure & Deployment

Modern full‑stack app (React + Flask) running in Docker on EC2, PostgreSQL on Amazon RDS, and Amazon S3 for file uploads — fully provisioned with Terraform.

> Repository: https://github.com/jesaja44/AWS_Fullstack_App-Infrastructure-Deployment

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Configuration (.env)](#configuration-env)
- [Terraform Variables](#terraform-variables)
- [S3 Hardening (enabled)](#s3-hardening-enabled)
- [EC2 IAM Role (enabled)](#ec2-iam-role-enabled)
- [Port 80 / Production (optional)](#port-80--production-optional)
- [Costs: AWS Free Tier Tips](#costs-aws-free-tier-tips)
- [Cleanup](#cleanup)
- [Contributing & License](#contributing--license)

---

## Overview
The app separates frontend and backend, runs the backend as a Docker container on an EC2 instance, uses Amazon RDS (PostgreSQL) as the database, and Amazon S3 for uploads. All infrastructure is declared in Terraform and parameterized (VPC, key pair, bucket name, etc.).

## Features
- **Infrastructure as Code (Terraform):** EC2, RDS, S3, IAM, Security Groups
- **Dockerized backend:** serves the React build as static files
- **PostgreSQL on RDS:** managed database
- **S3 storage:** for avatars/uploads
- **.env‑based config:** secrets kept out of Git

## Architecture

![AWS Fullstack Application with Terraform](./aws_architecture_reversed_arrows.png)


## Project Structure
```
.
├── backend/                      # Flask app (also serves the frontend build)
├── frontend/                     # (optional) frontend source
└── infrastructure/               # Terraform
    ├── main.tf                   # EC2, SGs, RDS, S3
    ├── variables.tf              # variables (incl. vpc_id, key_name, ...)
    ├── iam.tf                    # EC2 instance profile + S3 policy + SSM
    ├── s3_hardening.tf           # encryption, versioning, PAB, TLS‑only, lifecycle
    └── terraform.tfvars.example  # template for your local terraform.tfvars
```

## Requirements
- **AWS CLI** with credentials/SSO
- **Terraform**
- **Docker**
- **An AWS EC2 Key Pair** in your target region (`key_name` variable)

## Quick Start

### 1) Clone
```bash
git clone https://github.com/jesaja44/AWS_Fullstack_App-Infrastructure-Deployment.git
cd AWS_Fullstack_App-Infrastructure-Deployment
```

### 2) Terraform
```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
# Fill terraform.tfvars with YOUR values (see next section)
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file=terraform.tfvars -out=tfplan
terraform apply "tfplan"
```

**Outputs** include:
- `ec2_public_ip` (or DNS)
- `rds_endpoint`
- `s3_bucket`

### 3) SSH to EC2
```bash
ssh -i ~/.ssh/<your-key>.pem ec2-user@<ec2_public_ip>
```

### 4) Install Docker (if the AMI is fresh)
```bash
sudo yum update -y
sudo amazon-linux-extras enable docker || true
sudo yum install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
newgrp docker || true
docker --version
```

### 5) Deploy backend
```bash
# If repo is private, use an SSH deploy key or upload the code via scp
git clone https://github.com/jesaja44/AWS_Fullstack_App-Infrastructure-Deployment.git app
cd app/backend

# Create .env (see below)
nano .env

# Build & run
docker build -t grocery-backend:latest .
docker run -d --name grocery-backend   --env-file .env   -p 5000:5000 --restart unless-stopped   grocery-backend:latest

# Health check
curl -I http://localhost:5000/
```

## Configuration (.env)
These variables are read by the backend (RDS with SSL; S3 via instance role — no access keys required):

```dotenv
FLASK_ENV=production

# Database (RDS)
POSTGRES_URI=postgresql://<db_user>:<db_password>@<rds_endpoint>:5432/<db_name>?sslmode=require
SQLALCHEMY_DATABASE_URI=${POSTGRES_URI}
DATABASE_URL=${POSTGRES_URI}

# AWS
AWS_REGION=<your-region>          # e.g. eu-central-1
AWS_S3_BUCKET=<your-s3-bucket>    # from Terraform output
```

> **Never commit** `backend/.env`. It is git‑ignored.

## Terraform Variables
Example `infrastructure/terraform.tfvars`:
```hcl
region      = "eu-central-1"
vpc_id      = "vpc-xxxxxxxx"         # your (default) VPC
key_name    = "my-keypair-name"      # existing key pair in the region

db_username = "grocerymate"
db_password = "STRONG_PASSWORD"
db_name     = "grocery"

bucket_name = "globally-unique-bucket-name-12345"
```

**Portability:** `main.tf` no longer hardcodes a VPC; `vpc_id` and `key_name` come from variables so anyone can deploy in their own AWS account.

## S3 Hardening (enabled)
The bucket is automatically hardened by Terraform:
- **Public Access Block**: blocks public ACLs/policies
- **Default encryption (SSE‑S3/AES256)**
- **Versioning** + **Lifecycle** (cleanup aborted multipart uploads, expire older versions)
- **TLS‑only bucket policy**: denies non‑HTTPS requests
- **Ownership controls**: `BucketOwnerEnforced` (no ACLs required/allowed)

> If your code sets ACLs like `public-read` the upload will fail with “ACLs are not supported”. Remove such ACLs — not needed anymore.

## EC2 IAM Role (enabled)
The EC2 instance uses an **instance profile** with a minimal S3 policy:
- **Object access**: `GetObject`, `PutObject`, `DeleteObject` on your bucket prefix
- **Bucket read checks** (optional): `GetBucketVersioning`, `GetEncryptionConfiguration`, `GetBucketPublicAccessBlock`, `GetBucketPolicyStatus`, `ListBucket`, `GetBucketLocation`
- **AmazonSSMManagedInstanceCore** attached for Session Manager access

**boto3** automatically picks up temporary credentials from the instance role — no `AWS_ACCESS_KEY_ID/SECRET` in `.env`.

## Port 80 / Production (optional)
Run without `:5000`:
1. Add an **ingress rule for port 80** to the EC2 security group in Terraform.
2. Map container to 80 on EC2:
   ```bash
   docker rm -f grocery-backend
   docker run -d --name grocery-backend      --env-file .env      -p 80:5000 --restart unless-stopped      grocery-backend:latest
   ```

**Recommended for production:** use **Gunicorn** instead of the Flask dev server:
```dockerfile
# in backend/Dockerfile
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "app:app"]
```

## Costs: AWS Free Tier Tips
- Choose **small instance types** (Micro) where applicable; check availability per region.
- Keep **RDS small** and stop/tear down when not needed; destroy resources after testing.
- **Versioning** stores multiple object versions — the lifecycle policy helps control cost.
- Create **Budgets/Alerts** in Billing (e.g., email when exceeding a threshold).

> Free tier conditions can change. Always review AWS’ current Free Tier page.

## Cleanup
Destroy everything (avoid costs):
```bash
cd infrastructure
terraform destroy
```

## Contributing & License
PRs welcome!  
License: MIT (see `LICENSE`).

