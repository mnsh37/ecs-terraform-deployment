terraform {
  backend "s3" {
    bucket         = "ecs-terraform-state-mnshkumr" 
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ecs-terraform-locks"
    encrypt        = true
  }
}
