# AWS Fullstack App – Infrastructure & Deployment

Moderne Fullstack-App (React + Flask) mit Docker auf EC2, PostgreSQL in RDS und S3 für Datei-Uploads – vollständig mit Terraform bereitgestellt.

## Inhaltsverzeichnis
- [Überblick](#überblick)
- [Features](#features)
- [Architektur](#architektur)
- [Projektstruktur](#projektstruktur)
- [Voraussetzungen](#voraussetzungen)
- [Schnellstart](#schnellstart)
- [Konfiguration (.env)](#konfiguration-env)
- [Terraform-Variablen](#terraform-variablen)
- [S3-Hardening (aktiv)](#s3-hardening-aktiv)
- [IAM-Rolle für EC2 (aktiv)](#iam-rolle-für-ec2-aktiv)
- [Port 80 / Produktion (optional)](#port-80--produktion-optional)
- [Kosten: AWS Free Tier Tipps](#kosten-aws-free-tier-tipps)
- [Aufräumen](#aufräumen)
- [Mitwirken & Lizenz](#mitwirken--lizenz)

## Überblick
Die App trennt Frontend und Backend, läuft in Docker-Containern auf einer EC2-Instanz, nutzt Amazon RDS (PostgreSQL) als Datenbank und Amazon S3 für Datei-Uploads. Die komplette Infrastruktur wird per Terraform provisioniert und ist über Variablen portabel (VPC, KeyPair, Bucket-Name etc.).

## Features
- **Infrastructure as Code (Terraform)**: EC2, RDS, S3, IAM, Security Groups
- **Dockerized Deployment**: Container für das Backend (liefert auch das Frontend-Build aus)
- **RDS PostgreSQL**: persistente DB
- **S3 Storage**: Uploads/Assets
- **.env-Konfiguration**: saubere Trennung von Secrets (nicht versioniert)

## Architektur
```
User
  │
  ▼
[Frontend (React)]
  │
  ▼
[Backend (Flask)]
  │         │
  ▼         ▼
 RDS     ─  S3
(Postgres) (Storage)

 ↑
 │
Terraform (EC2, RDS, S3, IAM, SG)
```

## Projektstruktur
```
.
├── backend/                      # Flask-App (liefert auch Frontend-Build aus)
├── frontend/                     # (optional) Frontend-Quellcode
└── infrastructure/               # Terraform
    ├── main.tf                   # EC2, SGs, RDS, S3
    ├── variables.tf              # Variablen (inkl. vpc_id, key_name, ...)
    ├── iam.tf                    # EC2-Instance-Profile + S3-Policy + SSM
    ├── s3_hardening.tf           # Verschlüsselung, Versioning, PAB, TLS-only, Lifecycle
    └── terraform.tfvars.example  # Vorlage zum Ausfüllen (lokal eigene terraform.tfvars)
```

## Voraussetzungen
- **AWS CLI** mit gültigen Credentials/SSO
- **Terraform**
- **Docker**
- **SSH KeyPair** in deiner Region (Name später als `key_name` verwenden)

## Schnellstart

### 1) Repo klonen
```bash
git clone https://github.com/jesaja44/AWS_Fullstack_App-Infrastructure-Deployment.git
cd AWS_Fullstack_App-Infrastructure-Deployment
```

### 2) Terraform vorbereiten
```bash
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars mit DEINEN Werten füllen (siehe unten)
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file=terraform.tfvars -out=tfplan
terraform apply "tfplan"
```

**Outputs**: `ec2_public_ip`/DNS, `rds_endpoint`, `s3_bucket`.

### 3) Auf EC2 einloggen
```bash
ssh -i ~/.ssh/<dein-key>.pem ec2-user@<ec2_public_ip>
```

### 4) Docker installieren (falls AMI frisch)
```bash
sudo yum update -y
sudo amazon-linux-extras enable docker || true
sudo yum install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
newgrp docker || true
docker --version
```

### 5) Backend deployen
```bash
# Code holen (wenn Repo privat: SSH-Deploy-Key nutzen oder per scp hochladen)
git clone https://github.com/jesaja44/AWS_Fullstack_App-Infrastructure-Deployment.git app
cd app/backend

# .env anlegen (siehe nächster Abschnitt)
nano .env

# Container bauen & starten
docker build -t grocery-backend:latest .
docker run -d --name grocery-backend --env-file .env -p 5000:5000 --restart unless-stopped grocery-backend:latest

# Test
curl -I http://localhost:5000/
```

## Konfiguration (.env)
Diese Variablen werden vom Backend gelesen (RDS mit SSL, S3 via Instance-Rolle – keine Access Keys nötig):

```dotenv
FLASK_ENV=production

# Datenbank (RDS)
POSTGRES_URI=postgresql://<db_user>:<db_password>@<rds_endpoint>:5432/<db_name>?sslmode=require
SQLALCHEMY_DATABASE_URI=${POSTGRES_URI}
DATABASE_URL=${POSTGRES_URI}

# AWS
AWS_REGION=<deine-region>          # z. B. eu-central-1
AWS_S3_BUCKET=<dein-s3-bucket>     # aus Terraform-Output
```

> **Wichtig:** `backend/.env` niemals committen. `.gitignore` enthält einen Eintrag dafür.

## Terraform-Variablen
In `infrastructure/terraform.tfvars` z. B.:
```hcl
region      = "eu-central-1"
vpc_id      = "vpc-xxxxxxxx"         # deine (Default-)VPC
key_name    = "mein-keypair-name"    # vorhandenes KeyPair in der Region

db_username = "grocerymate"
db_password = "STRONG_PASSWORD"
db_name     = "grocery"

bucket_name = "global-eindeutiger-bucket-name-12345"
```

**Portabilität:** In `main.tf` ist die VPC nicht hart codiert; `vpc_id` und `key_name` kommen aus Variablen. Damit kann jeder das Projekt in der eigenen AWS-Umgebung ausrollen.

## S3-Hardening (aktiv)
Der Bucket wird bei `terraform apply` automatisch gehärtet:
- **Public Access Block** (blockt öffentliche ACLs/Policies)
- **Default-Encryption (SSE-S3/AES256)**
- **Versioning** + **Lifecycle** (abgebrochene Multipart-Uploads, Aufräumen alter Versionen)
- **TLS-only Bucket Policy** (HTTP wird abgewiesen)
- **Ownership Controls**: `BucketOwnerEnforced` (keine ACLs nötig/erlaubt)

> Falls dein Code ACLs wie `public-read` setzt, führt das zu Fehlern („ACLs are not supported“). Entferne solche ACLs – dank Public-Access-Block nicht mehr nötig.

## IAM-Rolle für EC2 (aktiv)
Die EC2-Instanz erhält per **Instance Profile** eine minimal gehaltene S3-Policy:
- **Objekt-Zugriff**: `GetObject`, `PutObject`, `DeleteObject` auf deinem Bucket
- **Bucket-Read-Checks** (optional): `GetBucketVersioning`, `GetEncryptionConfiguration`, `GetBucketPublicAccessBlock`, `GetBucketPolicyStatus`, `ListBucket`, `GetBucketLocation`
- **SSM-Core**: bequemer Zugriff via AWS Systems Manager möglich

**boto3** zieht die temporären Credentials automatisch aus der Instance-Rolle – keine `AWS_ACCESS_KEY_ID/SECRET` in `.env` nötig.

## Port 80 / Produktion (optional)
Schöner ohne `:5000`:
1. Security Group in Terraform um Port 80 ergänzen.
2. Container auf 80 mappen:
   ```bash
   docker rm -f grocery-backend
   docker run -d --name grocery-backend --env-file .env -p 80:5000 --restart unless-stopped grocery-backend:latest
   ```
**Empfehlung Produktion:** **Gunicorn** statt Flask-Dev-Server benutzen:
```dockerfile
# im Dockerfile:
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "app:app"]
```

## Kosten: AWS Free Tier Tipps
- **Kleine Instanzen** wählen (Micro), regionale Verfügbarkeit beachten.
- **RDS klein halten** und nur bei Bedarf laufen lassen; nach Tests Ressourcen **zerstören**.
- **S3 Versioning** erzeugt mehr Objekte – Lifecycle hilft beim Aufräumen.
- **Budgets/Alarme** im Billing aktivieren (z. B. E-Mail ab €-Schwelle).

> Free-Tier-Konditionen ändern sich. Prüfe vor Nutzung die aktuelle AWS Free Tier Seite.

## Aufräumen
Alles wieder entfernen (vermeidet Kosten):
```bash
cd infrastructure
terraform destroy
```

## Mitwirken & Lizenz
PRs willkommen!  
Lizenz: MIT (siehe `LICENSE`).

