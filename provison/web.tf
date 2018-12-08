# Get the list of official Canonical Ubuntu 16.04 AMIs
data "aws_ami" "ubuntu-1604" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_file" "web" {
  count = "${var.webservice_server_count}"

  template = <<EOF
${file("${path.module}/templates/webserver.sh")}
EOF

  vars {
    consul_version = "${var.consul_version}"
    datacenter     = "${var.datacenter}"
    retry_join_tag = "${var.retry_join_tag}"
    hostname       = "web-${var.namespace}-${count.index+1}"
  }
}

resource "aws_security_group" "web" {
  name        = "${var.namespace}-web"
  description = "webserver security group, allows consul lan gossip."
  vpc_id      = "${module.vpc.vpc_id}"
}

resource "aws_security_group_rule" "allow_ssh_access" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.web.id}"
}

resource "aws_security_group_rule" "allow_consul_all_traffic" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = "${aws_security_group.consul.id}"

  security_group_id = "${aws_security_group.web.id}"
}

resource "aws_security_group_rule" "allow_egress_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.web.id}"
}

# Create an IAM role for the web server
resource "aws_iam_role" "web" {
  name = "${var.namespace}-web"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

# Create the policy
resource "aws_iam_policy" "web" {
  name        = "${var.namespace}-web"
  description = "Allows web server to describe instances."

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    }
  ]
}
POLICY
}

# Attach the policy
resource "aws_iam_policy_attachment" "web" {
  name       = "${var.namespace}-web"
  roles      = ["${aws_iam_role.web.name}"]
  policy_arn = "${aws_iam_policy.web.arn}"
}

# Create the instance profile
resource "aws_iam_instance_profile" "web" {
  name = "${var.namespace}-web"
  role = "${aws_iam_role.web.name}"
}

resource "aws_instance" "web" {
  count         = "${var.webservice_server_count}"
  ami           = "${data.aws_ami.ubuntu-1604.id}"
  instance_type = "t2.medium"
  key_name      = "${aws_key_pair.consul.key_name}"

  iam_instance_profile   = "${aws_iam_instance_profile.web.name}"
  subnet_id              = "${element(module.vpc.public_subnets, count.index)}"
  vpc_security_group_ids = ["${aws_security_group.web.id}"]

  tags {
    Name = "web-${var.namespace}-${count.index+1}"
  }

  user_data = "${element(data.template_file.web.*.rendered, count.index)}"
}

# Outputs

output "web_server_ssh" {
  value = "ssh -q -i ${path.module}/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o CheckHostIP=no -o StrictHostKeyChecking=no ${var.username}@${aws_instance.web.0.public_ip}"
}

output "web_server_ip" {
  value = "${aws_instance.web.*.public_ip}"
}
