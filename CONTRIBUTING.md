# Contributing

PRs welcome!

## How to propose changes
1. Fork and create a feature branch: `git checkout -b feat/your-topic`
2. Keep commits focused (Conventional Commits style is appreciated).
3. Run local checks before opening a PR.

## Local checks
- Terraform:
  cd infrastructure
  terraform init -backend=false
  terraform fmt -recursive
  terraform validate

- Backend:
  docker build -t grocery-backend:dev ./backend
  docker run --rm --env-file backend/.env.example -p 5000:5000 grocery-backend:dev
