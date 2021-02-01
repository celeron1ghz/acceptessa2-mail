locals {
  appid = "acceptessa2"
}

provider "aws" {
  region = "ap-northeast-1"
}

# terraform {
#   required_version = ">= 0.14.0"

#   backend "s3" {
#     bucket = "xxxxxx"
#     key    = "xxxxxx.tfstate"
#     region = "ap-northeast-1"
#   }
# }
