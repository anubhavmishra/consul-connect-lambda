data "aws_caller_identity" "current" {}

resource "aws_api_gateway_rest_api" "consul_connect_example" {
  name        = "consul-connect-example"
  description = "Consul Connect example API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# define production deployment
resource "aws_api_gateway_deployment" "consul_connect_example" {
  depends_on = [
    "aws_api_gateway_method.consul_connect_example",
    "aws_api_gateway_integration.consul_connect_example",
  ]

  stage_name  = "test"
  rest_api_id = "${aws_api_gateway_rest_api.consul_connect_example.id}"
}

# IAM

# api gateway

# allow api gateway to invoke reindexer_dispatch function
resource "aws_lambda_permission" "consul_connect_example" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.consul_connect_lambda.function_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.consul_connect_example.id}/*/${aws_api_gateway_method.consul_connect_example.http_method}/"
}

# route method
resource "aws_api_gateway_method" "consul_connect_example" {
  rest_api_id      = "${aws_api_gateway_rest_api.consul_connect_example.id}"
  resource_id      = "${aws_api_gateway_rest_api.consul_connect_example.root_resource_id}"
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = false
}

# route reponse for "GET /reindex"
resource "aws_api_gateway_method_response" "consul_connect_example_success" {
  rest_api_id = "${aws_api_gateway_rest_api.consul_connect_example.id}"
  resource_id = "${aws_api_gateway_rest_api.consul_connect_example.root_resource_id}"
  http_method = "${aws_api_gateway_method.consul_connect_example.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Content-Type" = true
  }
}

# connect route above with our hello-world lambda function
resource "aws_api_gateway_integration" "consul_connect_example" {
  rest_api_id             = "${aws_api_gateway_rest_api.consul_connect_example.id}"
  resource_id             = "${aws_api_gateway_rest_api.consul_connect_example.root_resource_id}"
  http_method             = "${aws_api_gateway_method.consul_connect_example.http_method}"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.consul_connect_lambda.arn}/invocations"
  integration_http_method = "POST"
}

# connect response from lambda to route response
resource "aws_api_gateway_integration_response" "consul_connect_example" {
  rest_api_id = "${aws_api_gateway_rest_api.consul_connect_example.id}"
  resource_id = "${aws_api_gateway_rest_api.consul_connect_example.root_resource_id}"
  http_method = "${aws_api_gateway_method.consul_connect_example.http_method}"
  status_code = "${aws_api_gateway_method_response.consul_connect_example_success.status_code}"
  depends_on  = ["aws_api_gateway_integration.consul_connect_example"]

  response_parameters = {
    "method.response.header.Content-Type" = "'text/html'"
  }

  response_templates = {
    "text/html" = <<EOF
$input.path('$')EOF
  }
}

output "api_invoke_url" {
    value = "${aws_api_gateway_deployment.consul_connect_example.invoke_url}"
}