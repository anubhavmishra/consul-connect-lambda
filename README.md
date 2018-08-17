# consul-connect-lambda
This repository contains Terraform configuration and Golang source code for showcasing [Consul Connect](https://www.consul.io/docs/connect/index.html)
and [AWS Lambda](https://aws.amazon.com/lambda/) integration.

## Background

The goal of this project is to showcase that Consul Connect feature can be used to connect AWS Lambda
functions to services running inside a datacenter (EC2 instances, RDS databases etc).

## Prerequisites

* An [AWS Account](https://aws.amazon.com/)
* Install [Terraform](https://terraform.io/downloads.html)

## Usage

Clone the repository

```bash
git clone https://github.com/anubhavmishra/consul-connect-lambda.git
```

Change into the `consul-connect-lambda` directory

```bash
cd consul-connect-lambda
```

### Build Golang Function for AWS Lambda

Build the Go function that will be deployed on AWS Lambda

```bash
make build-service
```

This will build the Golang project and create a zip file that is ready to be uploaded to AWS Lambda.

### Deploy AWS Infrastructure

Set AWS environment variables

```bash
export AWS_ACCESS_KEY_ID=AKIAxxxxxxxxxxx
export AWS_SECRET_ACCESS_KEY=secreTxxxxxxxxxxxxxxxxxx
```

Initialize Terraform

```bash
cd provision
terraform init
```

```bash
Initializing modules...
- module.consul
- module.vpc

Initializing provider plugins...

The following providers do not have any version constraints in configuration,
so the latest version was installed.

To prevent automatic upgrades to new major versions that may contain breaking
changes, it is recommended to add version = "..." constraints to the
corresponding provider blocks in configuration, with the constraint strings
suggested below.

* provider.aws: version = "~> 1.30"
* provider.null: version = "~> 1.0"
* provider.template: version = "~> 1.0"
* provider.tls: version = "~> 1.1"

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

Apply Terraform configuration

```bash
terraform apply
```

```bash
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.

data.template_file.consul_server[2]: Refreshing state...
data.template_file.consul_server[1]: Refreshing state...
data.template_file.web: Refreshing state...
data.template_file.consul_server[0]: Refreshing state...
data.aws_caller_identity.current: Refreshing state...
data.aws_iam_policy_document.consul_connect_lambda_assume_role_policy: Refreshing state...
data.aws_iam_policy_document.consul_connect_lambda: Refreshing state...
data.aws_ami.ubuntu-1604: Refreshing state...
data.aws_availability_zones.available: Refreshing state...
data.aws_ami.ubuntu-1604: Refreshing state...

------------------------------------------------------------------------
.....
Plan: 72 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
.....
tls_private_key.key: Creating...
  algorithm:          "" => "RSA"
  ecdsa_curve:        "" => "P224"
  private_key_pem:    "" => "<computed>"
  public_key_openssh: "" => "<computed>"
  public_key_pem:     "" => "<computed>"
  rsa_bits:           "" => "2048"
tls_private_key.key: Creation complete after 0s (ID: 32341c736d04b1c11df13faea9ac355d605f42ea)
null_resource.save-key: Creating...
  triggers.%:   "" => "1"
.....

Apply complete! Resources: 72 added, 0 changed, 0 destroyed.

Outputs:

Outputs:

api_invoke_url = https://gwzp1le6u9.execute-api.us-east-1.amazonaws.com/test
consul-lb = internal-connect-consul-1177654261.us-east-1.elb.amazonaws.com
consul_server_instance_ids = [
    i-072a113aa5effd6ed,
    i-07153c706df78f16f,
    i-0f311817ae5705147
]
consul_server_ips = [
    18.232.66.119,
    34.203.205.234,
    52.86.6.160
]
consul_server_ssh = ssh -q -i /Users/username/consul-connect-lambda/provison/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o CheckHostIP=no -o StrictHostKeyChecking=no ubuntu@18.232.66.119 -L 8500:localhost:8500
web_server_ip = [
    34.204.77.229
]
```

### Consul Cluster

SSH into one Consul server.

```bash
$(terraform output consul_server_ssh)
```

Make sure the Consul cluster is setup and working

```bash
ubuntu@consul-dc1-1 $ consul members
```

```bash
Node           Address            Status  Type    Build  Protocol  DC   Segment
consul-dc1-1   10.0.101.24:8301   alive   server  1.2.2  2         dc1  <all>
consul-dc1-2   10.0.102.182:8301  alive   server  1.2.2  2         dc1  <all>
consul-dc1-3   10.0.103.247:8301  alive   server  1.2.2  2         dc1  <all>
web-connect-1  10.0.101.251:8301  alive   client  1.2.2  2         dc1  <default>
```

Open Consul UI

```bash
terraform output consul_ui
```

Go to http://localhost:8500 in your browser.

### AWS Lambda & API Gateway

Try out the Lambda function in the browser.

```bash
terraform output api_invoke_url
https://gwzp1le6u9.execute-api.us-east-1.amazonaws.com/test
```

Or if open in the browser directly.

```bash
open $(terraform output api_invoke_url)
```

### Clean up

Run Terraform destroy.

```bash
terraform destroy
```

# Useful Links

* https://kennbrodhagen.net/2016/01/31/how-to-return-html-from-aws-api-gateway-lambda/