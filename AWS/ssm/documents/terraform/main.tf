provider "aws" {
  region     = "us-east-1"
}

resource "aws_ssm_parameter" "hello" {
  name  = "hello"
  type  = "String"
  value = "World"
}
