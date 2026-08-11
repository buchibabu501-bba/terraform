terraform {
  backend "s3" {
    bucket         = "amzn-terraform-bucket-babu "
    key            = "terraform/state.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terrafrom-babu"
    encrypt        = true
  }
}
