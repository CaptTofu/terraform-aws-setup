provider "aws" {
  access_key              = "${var.aws_access_key}"
  secret_key              = "${var.aws_secret_key}"
  shared_credentials_file = "${var.aws_shared_credentials_file}"
  profile                 = "${var.aws_profile}"
  region                  = "${var.aws_region}"
  max_retries             = "${var.max_retries}"
}

resource "aws_key_pair" "keypair" {
  key_name   = "${var.aws_user_prefix}_key"
  public_key = "${file(var.aws_local_public_key)}"
}

# top level VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = false

  tags {
    Name = "${var.aws_user_prefix}-vpc"
  }
}

# DHCP options set
resource "aws_vpc_dhcp_options" "vpc_dhcp" {
  domain_name         = "${var.aws_cluster_domain}"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags {
    Name = "${var.aws_user_prefix}-dopt"
  }
}

resource "aws_vpc_dhcp_options_association" "vpc_dhcp_association" {
  vpc_id          = "${aws_vpc.vpc.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.vpc_dhcp.id}"
}

# IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.aws_user_prefix}-igw"
  }
}

# Elastic IP for the NAT GW
resource "aws_eip" "nat_eip" {
  vpc                = true
}

# NAT GW
resource "aws_nat_gateway" "nat_gw" {
  allocation_id    = "${aws_eip.nat_eip.id}"
  subnet_id        = "${aws_subnet.vpc_subnet_pub.id}"
  depends_on       = ["aws_internet_gateway.igw"]
}

# Public route table (via IGW)
resource "aws_route_table" "pub_rt" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags {
    Name = "pub-rt"
  }
}

# Private route table (via NAT)
resource "aws_route_table" "priv_rt" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat_gw.id}"
  }

  tags {
    Name = "priv-rt"
  }
}

# public subnet
resource "aws_subnet" "vpc_subnet_pub" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.vpc_subnet0_cidr}" 
  availability_zone       = "${element(split(",", lookup(var.aws_region_azs, var.aws_region)), 0)}" 
  map_public_ip_on_launch = true

  tags {
    Name = "${format("pub-%s", element(split(",", lookup(var.aws_region_azs, var.aws_region)), 0))}"
  }
}
# route for public subnet
resource "aws_route_table_association" "vpc_subnet_pub_rt_association" {
  subnet_id      = "${aws_subnet.vpc_subnet_pub.id}"
  route_table_id = "${aws_route_table.pub_rt.id}"
}

# private subnet 1
resource "aws_subnet" "vpc_subnet_priv_1" {
  availability_zone       = "${element(split(",", lookup(var.aws_region_azs, var.aws_region)), 1)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.vpc_subnet1_cidr}"
  map_public_ip_on_launch = false

  tags {
    Name = "${format("priv-%s", element(split(",", lookup(var.aws_region_azs, var.aws_region)), 1))}"
  }
}

# private subnet 1 route 
resource "aws_route_table_association" "vpc_subnet_priv_1_rt_association" {
  subnet_id      = "${aws_subnet.vpc_subnet_priv_1.id}"
  route_table_id = "${aws_route_table.priv_rt.id}"
}

# private subnet 2
resource "aws_subnet" "vpc_subnet_priv_2" {
  availability_zone       = "${element(split(",", lookup(var.aws_region_azs, var.aws_region)), 2)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.vpc_subnet2_cidr}"
  map_public_ip_on_launch = false

  tags {
    Name = "${format("priv-%s", element(split(",", lookup(var.aws_region_azs, var.aws_region)), 2))}"
  }
}

# private subnet 2 route 
resource "aws_route_table_association" "vpc_subnet_priv_2_rt_association" {
  subnet_id      = "${aws_subnet.vpc_subnet_priv_2.id}"
  route_table_id = "${aws_route_table.priv_rt.id}"
}

# private subnet 3
resource "aws_subnet" "vpc_subnet_priv_3" {
  availability_zone       = "${element(split(",", lookup(var.aws_region_azs, var.aws_region)), 0)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.vpc_subnet3_cidr}"
  map_public_ip_on_launch = false

  tags {
    Name = "${format("priv-%s", element(split(",", lookup(var.aws_region_azs, var.aws_region)), 0))}"
  }
}

# private subnet 3 route
resource "aws_route_table_association" "vpc_subnet_priv_3_rt_association" {
  subnet_id      = "${aws_subnet.vpc_subnet_priv_3.id}"
  route_table_id = "${aws_route_table.priv_rt.id}"
}

# acl/secgroups

resource "aws_network_acl" "vpc_acl" {
  vpc_id = "${aws_vpc.vpc.id}"

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags {
    Name = "${var.aws_user_prefix}-acl"
  }
}

resource "aws_security_group" "restricted_ssh" {
  name        = "restricted-ssh"
  description = "Restricted ssh"
  vpc_id      = "${aws_vpc.vpc.id}"

  # inbound ssh access from the world
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # icmp (outbound)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "restricted-ssh"
  }
}

resource "aws_instance" "jumphost" {
    ami             = "ami-c8bda8a2"
    instance_type   = "t2.micro"
    key_name        = "${aws_key_pair.keypair.key_name}"
    #security_groups = ["default", "restricted-ssh"]
    subnet_id       = "${aws_subnet.vpc_subnet_pub.id}"
    user_data =     "${file("./user-data.txt")}"
    tags {
        Name = "jumphost"
    }
}
# TODO
# 
# resource "aws_route53_record" "jumphost_record" {
#   zone_id = "${var.aws_zone_id}"
#   name    = "${replace(var.aws_user_prefix,"_","-")}-jumphost.${var.aws_cluster_domain}"
#   type    = "A"
#   ttl     = "30"
#   records = ["${aws_instance.jumphost.public_ip}"]
# }
