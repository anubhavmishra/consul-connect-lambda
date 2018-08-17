resource "aws_security_group" "consul" {
  name        = "${var.namespace}-default"
  description = "Allow consul and ssh externally, everything on internal VPC"
  vpc_id      = "${module.vpc.vpc_id}"

  lifecycle = {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_ssh_access_consul" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.consul.id}"
}

resource "aws_security_group_rule" "allow_all_self_access_consul" {
  type        = "ingress"
  from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = "true"

  security_group_id = "${aws_security_group.consul.id}"
}

resource "aws_security_group_rule" "allow_gossip_from_web_tcp_consul" {
  type        = "ingress"
  from_port   = 8300
  to_port     = 8301
  protocol    = "tcp"
  source_security_group_id = "${aws_security_group.web.id}"

  security_group_id = "${aws_security_group.consul.id}"
}

resource "aws_security_group_rule" "allow_gossip_from_web_udp_consul" {
  type        = "ingress"
  from_port   = 8300
  to_port     = 8301
  protocol    = "udp"
  source_security_group_id = "${aws_security_group.web.id}"

  security_group_id = "${aws_security_group.consul.id}"
}

resource "aws_security_group_rule" "allow_egress_all_consul" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.consul.id}"
}

module "consul" {
  source                 = "git@github.com:anubhavmishra/consul-aws.git"
  consul_server_count    = "${var.consul_server_count}"
  namespace              = "${var.namespace}"
  subnet_ids             = "${module.vpc.public_subnets}"
  key_name               = "${aws_key_pair.consul.key_name}"
  username               = "${var.username}"
  vpc_security_group_ids = "${aws_security_group.consul.id}"
  consul_version         = "${var.consul_version}"
}

# Create ALB to expose to Consul HTTP API

resource "aws_alb" "consul" {
  name = "${var.namespace}-consul"

  internal = "true"

  security_groups = ["${aws_security_group.consul.id}"]
  subnets         = ["${module.vpc.public_subnets}"]

  tags {
    Name = "${var.namespace}-consul"
  }
}

resource "aws_alb_target_group" "consul-ui" {
  name_prefix = "consul"
  port        = "8500"
  vpc_id      = "${module.vpc.vpc_id}"
  protocol    = "HTTP"

  health_check {
    interval          = "5"
    timeout           = "2"
    path              = "/v1/agent/self"
    port              = "8500"
    protocol          = "HTTP"
    healthy_threshold = 2
    matcher           = 200
  }

  lifecycle = {
    create_before_destroy = true
  }
}

resource "aws_alb_listener" "consul-ui" {
  load_balancer_arn = "${aws_alb.consul.arn}"

  port     = "8500"
  protocol = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.consul-ui.arn}"
    type             = "forward"
  }
}

resource "aws_alb_target_group_attachment" "consul-ui" {
  count            = "${var.consul_server_count}"
  target_group_arn = "${aws_alb_target_group.consul-ui.arn}"
  target_id        = "${element(module.consul.server_instance_ids, count.index)}"
  port             = "8500"
}

# Outputs

output "consul_lb" {
  value = "${aws_alb.consul.dns_name}"
}

output "consul_server_ssh" {
  value = "ssh -q -i ${path.module}/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o CheckHostIP=no -o StrictHostKeyChecking=no ${var.username}@${element(module.consul.server_ips, 0)} -L 8500:localhost:8500"
}

output "consul_server_ips" {
  value = "${module.consul.server_ips}"
}

output "consul_server_instance_ids" {
  value = "${module.consul.server_instance_ids}"
}

output "consul_ui" {
  value = "http://localhost:8500"
}

// SSH wrapper script
//output "ssh" {
//  value = "#!/bin/bash\n\nif [[ $2 != '--tunnel' ]]; then\n    ssh -q -i ${path.module}/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o CheckHostIP=no -o StrictHostKeyChecking=no ${var.username}@$1\nelse\n    ssh -q -i ${path.module}/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o CheckHostIP=no -o StrictHostKeyChecking=no ${var.username}@$1 -L $3:localhost:$3\nfi"
//}
