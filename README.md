# 🚀 ECS Terraform Deployment

This project deploys a containerized web application on **AWS ECS (EC2 launch type)** using **Terraform** for infrastructure and **GitHub Actions** for CI/CD. It includes a **MariaDB RDS database**, **S3** for static files, **EFS** for shared storage, and **CloudFront** for content delivery.

---

## 📌 Project Overview

The goal is to create a **scalable**, **secure**, and **automated deployment pipeline** for a Dockerized application.

* Infrastructure as Code: **Terraform**
* CI/CD: **GitHub Actions**
* Container Image: Built and pushed to **Amazon ECR**
* Application deployed on **ECS EC2**

---

## 🧱 Infrastructure Components

* **ECS Cluster**: Runs app containers on EC2
* **EC2 Instances**: ECS worker nodes with user data scripts
* **RDS (MariaDB)**: Relational database backend
* **S3 Bucket**: For static file storage
* **EFS**: Shared storage mounted in ECS tasks
* **CloudFront**: CDN for S3 content
* **VPC & Networking**: Custom VPC, subnets, IGW, route tables
* **Security Groups**: For ECS, RDS, and EFS

---

## 📂 Repository Structure

```plaintext
main.tf                        # Terraform configuration for AWS resources
.github/workflows/deployment.yml  # GitHub Actions CI/CD pipeline
Dockerfile                    # Defines Docker image (assumed)
README.md                     # Project documentation
```

---

## ⚙️ Prerequisites

* AWS account with access to ECS, EC2, RDS, S3, EFS, CloudFront, and ECR
* AWS CLI configured (`aws configure`)
* Terraform ≥ 1.9.0
* Docker installed
* GitHub repository with Secrets configured (see below)
* Amazon ECR repository (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app`)

---

## 🛠️ Setup Instructions

### 1️⃣ Configure GitHub Secrets

Go to: `GitHub Repo → Settings → Secrets and Variables → Actions`

Add:

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `DB_PASSWORD` *(optional if not hardcoded)*

---

### 2️⃣ Clone the Repository

```bash
git clone https://github.com/mnsh37/ecs-terraform-deployment.git
cd ecs-terraform-deployment
```

---

### 3️⃣ Update Terraform Configuration

* In `main.tf`, update:

  * AWS region (`us-east-1`)
  * ECR repo URL

If using a variable for DB password:

```hcl
# variables.tf
variable "db_password" {
  type      = string
  sensitive = true
}
```

And in `main.tf`, reference it with `var.db_password`.

---

### 4️⃣ Initialize Terraform

```bash
terraform init
```

---

### 5️⃣ Test Locally

**Docker Build:**

```bash
docker build -t my-app:latest .
docker run -p 80:80 my-app:latest
```

**Terraform Plan:**

```bash
terraform plan -var="db_password=your_db_password"
```

(Optional) Apply in sandbox:

```bash
terraform apply -var="db_password=your_db_password"
```

---

### 6️⃣ Push to GitHub

```bash
git add .
git commit -m "Initial setup for ECS deployment"
git push origin main
```

This will trigger the GitHub Actions workflow.

---

## 🔄 Deployment Workflow

**Trigger**: On push to `main`
**Steps**:

1. Builds Docker image and pushes to ECR
2. Applies Terraform using AWS credentials from GitHub Secrets

**Monitor**:
GitHub → Actions → Select workflow run

---

## ✅ Verification

* **ECS Service**: Check status in AWS Console
* **App Access**: Visit EC2 Public IP on port 80
* **Static Files**: Access CloudFront URL
* **Database**: Connect to RDS with credentials
* **EFS**: View mount logs in ECS tasks

---

## 🧹 Cleanup

To destroy the infrastructure and avoid charges:

```bash
terraform destroy -var="db_password=your_db_password"
```

---

## 📝 Notes

* RDS is **publicly accessible for demo**; restrict access in production
* S3 bucket name includes a **random suffix** for uniqueness
* Docker image is expected to expose **port 80** (update if different)
* For better security, use **Secrets Manager** or **SSM Parameter Store**

---

## 🤝 Contributing

PRs and issues are welcome for bug fixes or improvements.
This project is licensed under the **MIT License**.

---

Let me know if you'd like a badge (Terraform, GitHub Actions, AWS) or a screenshot/banner for a more polished README.
