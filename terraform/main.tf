provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Create a second public subnet in a different availability zone
#RDS requires subnets in at least two Availability Zones (AZs) for high availability.
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}


#Security Group for ECS EC2 Instance
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 👈 safer to use your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "ecs-ec2-cluster"
}

#IAM Role for ECS EC2 Instance
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

#IAM Instance Profile
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

#Fetch ECS-Optimized AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

#EC2 Instance (Worker Node)
resource "aws_instance" "ecs_instance" {
  ami                         = data.aws_ssm_parameter.ecs_ami.value
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ecs_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ecs_instance_profile.name
  associate_public_ip_address = true
  key_name                    = "ecs-key"

  user_data = <<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
EOF

  tags = {
    Name = "ECS-Worker-Node"
  }
}

#Define ECS Task Definition
resource "aws_ecs_task_definition" "my_task" {
  family                   = "ecs-static-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = "257"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

container_definitions = jsonencode([
  {
    name      = "ecs-static-container",
    image     = "566849586552.dkr.ecr.us-east-1.amazonaws.com/ecs-static-site:latest",
    essential = true,
    memory    = 512,
    cpu       = 257,
    portMappings = [
      {
        containerPort = 80,
        hostPort      = 80,
        protocol      = "tcp"
      }
    ],
    mountPoints = [
      {
        sourceVolume  = "shared-efs-volume",
        containerPath = "/mnt/efs",
        readOnly      = false
      }
    ],
    command = ["/bin/sh", "-c", "mkdir -p /mnt/efs && exec nginx -g 'daemon off;'"]
  }
])

  volume {
    name = "shared-efs-volume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.ecs_efs.id
      root_directory     = "/"
      transit_encryption = "ENABLED"
    }
  }
}


#ECS Service
# This service will run the task definition on the ECS cluster
resource "aws_ecs_service" "static_site_service" {
  name            = "ecs-static-site-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.my_task.arn
  desired_count   = 1
  launch_type     = "EC2"

#   network_configuration {
#     subnets          = [aws_subnet.public.id]
#     security_groups  = [aws_security_group.ecs_sg.id]
#     assign_public_ip = true
#   }

  depends_on = [
    aws_instance.ecs_instance,
    aws_iam_role_policy_attachment.ecs_policy_attach
  ]
}


resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

#ECS Execution Role (for pulling image from ECR)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# S3 Bucket for Static Assets
# This bucket will store static assets for the ECS static site
#Create S3 Bucket with Unique Name
resource "aws_s3_bucket" "static_assets" {
  bucket = "ecs-static-assets-${random_id.suffix.hex}"

  force_destroy = true  # Optional: lets you delete non-empty bucket

  tags = {
    Name        = "ECS Static Site Assets"
    Environment = "Dev"
  }
}
#Set Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
#Block Public Access (Recommended by AWS)
resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
# Generate a random suffix for bucket name uniqueness
resource "random_id" "suffix" {
  byte_length = 4
}

# RDS MariaDB Instance
# This instance will be used by the ECS backend
resource "aws_db_subnet_group" "rds_subnet_group" {
  name_prefix = "rds-subnet-"  # Terraform will generate the full name
  subnet_ids = [
    aws_subnet.public.id,
    aws_subnet.public_2.id
  ]

  tags = {
    Name = "RDS Subnet Group"
  }
}

# Security Group for RDS - Allows ECS instances to connect to MariaDB
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow DB access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]  # Allow ECS -> RDS
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS MariaDB Instance - Free Tier eligible, ready for ECS backend usage
resource "aws_db_instance" "mariadb" {
  identifier              = "ecs-mariadb"
  engine                  = "mariadb"
  engine_version          = "10.6.14"                 # ✅ Free-tier eligible and stable
  instance_class          = "db.t3.micro"             # ✅ Free Tier eligible
  allocated_storage       = 20
  username                = var.rds_username
  password                = var.rds_password          
  publicly_accessible     = true
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]

  tags = {
    Name = "ECS MariaDB"
  }
}

# EFS File System for shared storage
# This EFS will be used for shared storage between ECS tasks
resource "aws_efs_file_system" "ecs_efs" {
  creation_token   = "ecs-efs-token"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "ecs-shared-efs"
  }
}

# EFS Security Group (allows NFS port 2049 from ECS EC2)

resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Allow NFS from ECS EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id] # ECS EC2 to EFS
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create Mount Targets for EFS (one per subnet)
resource "aws_efs_mount_target" "efs_mt_1" {
  file_system_id  = aws_efs_file_system.ecs_efs.id
  subnet_id       = aws_subnet.public.id
  security_groups = [aws_security_group.efs_sg.id]
}
resource "aws_efs_mount_target" "efs_mt_2" {
  file_system_id  = aws_efs_file_system.ecs_efs.id
  subnet_id       = aws_subnet.public_2.id
  security_groups = [aws_security_group.efs_sg.id]
}

# Make S3 Bucket Accessible to CloudFront
# Public access is blocked (recommended); use a CloudFront Origin Access Control (OAC) to grant CloudFront permission to fetch from S3.
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "cf-oac-s3"
  description                       = "OAC for CloudFront to access S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution for Static Assets
# This distribution will serve static assets from the S3 bucket
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_id   = "s3-origin"
    
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  price_class = "PriceClass_100" # US/EU only (Free tier)
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "ECS Static Site CDN"
  }
}

# S3 Bucket Policy to Allow CloudFront Access
# This policy allows CloudFront to access the S3 bucket using the OAC
data "aws_iam_policy_document" "s3_oac_access" {
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_assets.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cdn_access" {
  bucket = aws_s3_bucket.static_assets.id
  policy = data.aws_iam_policy_document.s3_oac_access.json
}
