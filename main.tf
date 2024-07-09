provider "aws" {
  region = "eu-west-1" # Avrupa (Londra) bölgesi için
}

# IAM rolü
resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda_exec_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

# Lambda fonksiyonu
resource "aws_lambda_function" "example_lambda" {
  filename         = "example_lambda.zip"
  function_name    = "example_lambda_function"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "example_lambda.handler"
  source_code_hash = filebase64sha256("example_lambda.zip")
  runtime          = "nodejs14.x"
}

# API Gateway
resource "aws_api_gateway_rest_api" "example_api" {
  name        = "example_api"
  description = "An example API created with Terraform"
}

resource "aws_api_gateway_resource" "example_resource" {
  rest_api_id = aws_api_gateway_rest_api.example_api.id
  parent_id   = aws_api_gateway_rest_api.example_api.root_resource_id
  path_part   = "example"
}

resource "aws_api_gateway_method" "example_method" {
  rest_api_id   = aws_api_gateway_rest_api.example_api.id
  resource_id   = aws_api_gateway_resource.example_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "example_integration" {
  rest_api_id             = aws_api_gateway_rest_api.example_api.id
  resource_id             = aws_api_gateway_resource.example_resource.id
  http_method             = aws_api_gateway_method.example_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.example_lambda.invoke_arn
}

resource "aws_lambda_permission" "example_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = aws_api_gateway_rest_api.example_api.execution_arn
}

# VPC oluşturma
resource "aws_vpc" "example_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.example_vpc.id
}

# Subnet oluşturma
resource "aws_subnet" "example_subnet" {
  vpc_id            = aws_vpc.example_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
}

# Security group oluşturma
resource "aws_security_group" "example_sg" {
  vpc_id = aws_vpc.example_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Örnek olarak, gelen HTTP isteklerini kabul etme
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Lambda fonksiyonunu VPC'ye bağlama
resource "aws_lambda_function" "example_lambda_vpc" {
  filename         = "example_lambda.zip"
  function_name    = "example_lambda_function_vpc"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "example_lambda.handler"
  source_code_hash = filebase64sha256("example_lambda.zip")
  runtime          = "nodejs14.x"

  vpc_config {
    subnet_ids         = [aws_subnet.example_subnet.id]
    security_group_ids = [aws_security_group.example_sg.id]
  }
}
