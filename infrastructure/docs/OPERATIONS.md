# Operations Cheatsheet
Abkürzungen: ALB (Application Load Balancer), TG (Target Group), SG (Security Group), EC2 (virtueller Server), SSM (AWS Systems Manager), TF (Terraform)

## Nutzung
bash
make infra-apply # TF (Terraform): fmt → validate → plan → apply → refresh → Outputs
make health # TG (Target Group) + ALB (Application Load Balancer) prüfen
make restart-backend # Backend via SSM (AWS Systems Manager) neu starten (Port 5000 veröffentlicht)
make aws-login # AWS SSO Login (falls Credentials abgelaufen sind)


## Hinweise
- Für alle Befehle gilt: Variablen wie AWS_PROFILE / AWS_REGION können im Makefile angepasst werden.
- health zeigt TG-Health (Target Group) und HTTP-Antwort des ALB (Application Load Balancer).
- restart-backend startet den Docker-Container grocery-backend auf der EC2 (virtueller Server) neu und published Port 5000.
