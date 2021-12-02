

## Variables

# lets set up a good sized RFC 1918 address space
# but avoid the usual 10. or 192.168. spaces
# 172.22.0.0/20 will give us 16 - /24 spaces or 
# 8 - /23 spaces for growth
# This works out to 172.22.0.0 -> 172.22.15.255
variable "qra_address_space" {
  default = "172.22.0.0/20"
}

variable "qra_node_subnet_1" {
  default = "172.22.0.0/24"
}

variable "key_name" {
  default = "mtg_test01"
}

variable "master_nodes" {
  default = 1
}

variable "worker_nodes" {
  default = 3

}

## Providers
provider "aws" {
  region = "us-west-2"
}

## Data
data "aws_availability_zones" "available" {}
data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

## AWS Resource creation

## AWS Network
resource "aws_vpc" "qra_vpc" {
  cidr_block           = var.qra_address_space
  enable_dns_hostnames = true
  tags = {
    "Name"        = "qra-vpc"
    "Environment" = "test"
  }
}

resource "aws_internet_gateway" "qra_gw" {
  vpc_id = aws_vpc.qra_vpc.id
  tags = {
    "Name"        = "qra-gw"
    "Environment" = "test"
  }
}

resource "aws_subnet" "qra_node_subnet_1" {
  cidr_block              = var.qra_node_subnet_1
  vpc_id                  = aws_vpc.qra_vpc.id
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
    "Name"        = "qra-node-subnet1"
    "Environment" = "test"
  }
}

## Routing
resource "aws_route_table" "qra_route_table" {
  vpc_id = aws_vpc.qra_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.qra_gw.id
  }
  tags = {
    "Name"        = "qra-route-table"
    "Environment" = "test"
  }
}

resource "aws_route_table_association" "qra-rta-subnet1" {
  subnet_id      = aws_subnet.qra_node_subnet_1.id
  route_table_id = aws_route_table.qra_route_table.id
}

## Security groups
resource "aws_security_group" "qra_k8s_nodes" {
  name   = "qra_k8s_nodes"
  vpc_id = aws_vpc.qra_vpc.id

  # SSH access
  ingress = [{
    description      = "inbound ssh access to qra k8s nodes"
    cidr_blocks      = ["0.0.0.0/0"]
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "outbound internet"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]
}

## EC2 k8s nodes

resource "aws_instance" "qra_k8s_master" {
  count                  = var.master_nodes
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.qra_node_subnet_1.id
  vpc_security_group_ids = [aws_security_group.qra_k8s_nodes.id]
  key_name               = var.key_name
  tags = {
    Name        = "qra-k8s-master-${count.index}"
    Role        = "k8s Master Node"
    Environment = "test"
  }
}

resource "aws_instance" "qra_k8s_worker" {
  count                  = var.worker_nodes
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.qra_node_subnet_1.id
  vpc_security_group_ids = [aws_security_group.qra_k8s_nodes.id]
  key_name               = var.key_name
  tags = {
    Name        = "qra-k8s-worker-${count.index}"
    Role        = "k8s Worker Node"
    Environment = "test"
  }
}
