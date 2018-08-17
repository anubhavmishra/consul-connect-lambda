resource "aws_lambda_function" "consul_connect_lambda" {
  filename                       = "../build/linux/amd64/consul-connect-lambda.zip"
  function_name                  = "consulConnectLambda"
  role                           = "${aws_iam_role.consul_connect_lambda.arn}"
  handler                        = "consul-connect-lambda"
  source_code_hash               = "${base64sha256(file("../build/linux/amd64/consul-connect-lambda.zip"))}"
  runtime                        = "go1.x"
  memory_size                    = 128
  timeout                        = 10
  reserved_concurrent_executions = 50
  publish                        = true

  vpc_config {
    subnet_ids         = ["${module.vpc.public_subnets}"]
    security_group_ids = ["${aws_security_group.consul.id}"]
  }

  environment {
    variables = {
      CONSUL_ADDRESS = "${aws_alb.consul.dns_name}:8500"
    }
  }
}

resource "aws_iam_role" "consul_connect_lambda" {
  name = "consul_connect_example_lambda"

  assume_role_policy = "${data.aws_iam_policy_document.consul_connect_lambda_assume_role_policy.json}"
}

# define assume role policy for above role
data "aws_iam_policy_document" "consul_connect_lambda_assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com", "lambda.amazonaws.com"]
    }
  }
}

## Lambda permissions

# IAM policy for lambda function to create, describe, and delete network interfaces

# Create the policy
resource "aws_iam_policy" "consul_connect_lambda" {
  name        = "consul-connect-lambda-vpc"
  description = "Allows the lambda function to work with ec2 network resources, instances and autoscaling."

  policy = "${data.aws_iam_policy_document.consul_connect_lambda.json}"
}

# policy definition for above policy
data "aws_iam_policy_document" "consul_connect_lambda" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ec2:DescribeInstances",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:AttachNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "autoscaling:CompleteLifecycleAction",
    ]

    effect = "Allow"

    resources = ["*"]
  }
}

# Attach the policy
resource "aws_iam_policy_attachment" "consul_connect_lambda" {
  name       = "consul-connect-lambda-vpc-attachment"
  roles      = ["${aws_iam_role.consul_connect_lambda.name}"]
  policy_arn = "${aws_iam_policy.consul_connect_lambda.arn}"
}
