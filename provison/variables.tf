variable "aws_region" {
  default = "us-east-1"
}

variable "namespace" {
  default = "connect"
}

variable "username" {
  default = "ubuntu"
}

variable "datacenter" {
  default = "dc1"
}

variable "consul_version" {
  default = "1.2.3"
}

variable "consul_server_count" {
  default = "3"
}

variable "retry_join_tag" {
  default = "consul"
}

variable "webservice_server_count" {
  default = "1"
}
