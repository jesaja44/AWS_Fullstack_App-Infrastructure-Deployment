AWS_PROFILE ?= default
AWS_REGION  ?= eu-central-1
INFRA_DIR   ?= infrastructure

export AWS_PROFILE
export AWS_REGION

# Tab-Probleme vermeiden: Befehle beginnen mit ">" statt Tab
.RECIPEPREFIX := >

.PHONY: infra-apply health restart-backend aws-login outputs

infra-apply:
> cd $(INFRA_DIR) && rm -f tfplan
> cd $(INFRA_DIR) && terraform fmt -recursive
> cd $(INFRA_DIR) && terraform validate
> cd $(INFRA_DIR) && terraform plan -var-file=terraform.tfvars -out=tfplan
> cd $(INFRA_DIR) && terraform apply -auto-approve tfplan
> cd $(INFRA_DIR) && terraform apply -refresh-only -auto-approve || true
> $(MAKE) outputs

outputs:
> cd $(INFRA_DIR) && echo && echo "Terraform Outputs:" && terraform output

health:
> cd $(INFRA_DIR) && \
  TG_ARN="$$(terraform output -raw alb_tg_arn)"; \
  ALB_DNS="$$(terraform output -raw alb_dns)"; \
  aws --no-cli-pager elbv2 describe-target-health \
    --target-group-arn "$$TG_ARN" \
    --query 'TargetHealthDescriptions[].{Target:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}' \
    --output table; \
  echo; echo "URL: http://$$ALB_DNS"; curl -sI "http://$$ALB_DNS/" | head -n1

restart-backend:
> cd $(INFRA_DIR) && \
  TG_ARN="$$(terraform output -raw alb_tg_arn)"; \
  EC2_ID="$$(aws elbv2 describe-target-health --target-group-arn "$$TG_ARN" --query 'TargetHealthDescriptions[0].Target.Id' --output text)"; \
  aws ec2 start-instances --instance-ids "$$EC2_ID" >/dev/null 2>&1 || true; \
  aws ec2 wait instance-running --instance-ids "$$EC2_ID" 2>/dev/null || true; \
  aws ec2 wait instance-status-ok --instance-ids "$$EC2_ID" 2>/dev/null || true; \
  CMD_ID="$$(aws ssm send-command --instance-ids "$$EC2_ID" \
    --document-name "AWS-RunShellScript" \
    --comment "restart grocery-backend (publish 5000)" \
    --parameters commands='["sudo systemctl start docker || true","docker rm -f grocery-backend || true","docker run -d --name grocery-backend --restart unless-stopped -p 5000:5000 grocery-backend:latest","sleep 2","curl -sI http://127.0.0.1:5000/ | head -n1 || true","ss -ltnp | grep :5000 || true"]' \
    --query 'Command.CommandId' --output text)"; \
  sleep 3; \
  aws ssm list-command-invocations --command-id "$$CMD_ID" --details \
    --query 'CommandInvocations[0].CommandPlugins[-1].{Status:Status,Output:Output}' --output table || true; \
  $(MAKE) health

aws-login:
> aws sso login --profile "$(AWS_PROFILE)"
