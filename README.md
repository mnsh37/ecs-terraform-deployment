# 🚀 ECS EC2 Deployment with Terraform & GitHub Actions

This project demonstrates how to deploy a containerized static website using **Amazon ECS (EC2 launch type)**, **Terraform**, and **GitHub Actions** for CI/CD. Everything is fully automated, from infrastructure provisioning to Docker image deployment — built from scratch by a solo DevOps engineer (me!).

---
```bash
## 📁 What’s Inside

- **Terraform IaC** for:
  - VPC, Subnets, Security Groups
  - ECS Cluster + EC2 Worker Node
  - ECS Task Definition + Service
  - EFS (shared volume)
  - RDS MariaDB
  - S3 + CloudFront
- **Dockerized Web App** (`index.html`) served via Nginx
- **CI/CD Pipeline** using GitHub Actions:
  - Automatically builds and pushes Docker image to ECR
  - Runs Terraform to update infrastructure on every commit

---

## 🌐 Live Demo

Access the live app:

**[CloudFront URL →](https://d2hy8u0n1pqzob.cloudfront.net/)**  
(Changes reflect automatically when you push to `main`)

---

## 🛠 How It Works

### 🏗 Infrastructure
- A custom **VPC** with public subnets
- An **EC2 instance** registered as an ECS worker node
- An **ECS cluster** running your containerized app
- **EFS** attached to the ECS container at `/mnt/efs`
- **RDS MariaDB** for future dynamic functionality
- Static assets served from **S3**, cached via **CloudFront**

### ⚙️ CI/CD Pipeline
Every push to the `main` branch triggers:
1. **Docker Build**: Builds the latest app with changes in `index.html`
2. **ECR Push**: Tags and pushes image using Git commit SHA
3. **Terraform Apply**: Updates ECS service to pull the new image tag

---

## 🧪 How to Test Locally


# Build the Docker image
docker build -t ecs-static-site .

# Run locally
docker run -p 8080:80 ecs-static-site

# Then visit: http://localhost:8080

🧾 Secrets Setup (GitHub Actions)

Make sure to add the following secrets in your GitHub repo:

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION (e.g. us-east-1)
ECR_REPOSITORY (e.g. 566849586552.dkr.ecr.us-east-1.amazonaws.com/ecs-static-site)
RDS_USERNAME
RDS_PASSWORD

```
🧠 Lessons Learned
ECR + ECS works great for tightly controlled deployments
EC2 launch type gives more control than Fargate (useful for EFS setup)
Terraform remote state is a must for consistent CI/CD
GitHub Actions makes it dead-simple to create a deploy pipeline

🙋‍♂️ Built By
Manish Kumar
DevOps Engineer | AWS & Terraform Certified
Open to roles, collaborations, or just tech talk.
