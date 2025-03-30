provider "aws" {
  region = "ap-northeast-2"
  profile = "youngyin" # 필요 시 profile 지정
}

resource "aws_key_pair" "tf_keypair" {
  key_name   = "tf_keypair"
  public_key = file("/Users/youngyinjeon/terraform-key/youngyin-key.pub")

  tags = {
    Name = "tf_keypair"
  }
}

data "aws_ami" "latest_amazon_linux2" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  owners = ["137112412989"] # Amazon 공식 계정
}

resource "aws_vpc" "MyVPC04" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "MyVPC04"
    }
}

resource "aws_internet_gateway" "MyIGW" {
    vpc_id = aws_vpc.MyVPC04.id
    tags = {
        Name = "MyIGW"
    }
}

resource "aws_subnet" "MyPublicSubnet" {
    vpc_id = aws_vpc.MyVPC04.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-northeast-2a"
    map_public_ip_on_launch = true # 공인IP 할당

    tags = {
        Name = "MyPublicSubnet"
    }
}

resource "aws_route_table" "MyPublicRouting" {
  depends_on = [aws_internet_gateway.MyIGW]
  vpc_id = aws_vpc.MyVPC04.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.MyIGW.id
  }

  tags = {
    Name = "MyPublicRouting"
  }
}

resource "aws_route_table_association" "MyPublicRouteTableAssociation" {
  subnet_id      = aws_subnet.MyPublicSubnet.id
  route_table_id = aws_route_table.MyPublicRouting.id
}

resource "aws_security_group" "MyPublicSecugroup" {
  name        = "MyPublicSecugroup"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.MyVPC04.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "MyPublicSecugroup"
  }
}

resource "aws_network_interface" "MyWeb1PrivateAddress" {
  subnet_id       = aws_subnet.MyPublicSubnet.id
  private_ips     = ["10.0.1.101"]
  security_groups = [aws_security_group.MyPublicSecugroup.id]

   tags = {
    Name = "MyWeb1PrivateAddress"
  }
}

resource "aws_instance" "MyWeb1" {
  ami                         = data.aws_ami.latest_amazon_linux2.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.tf_keypair.key_name

  network_interface {
    network_interface_id = aws_network_interface.MyWeb1PrivateAddress.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl --static set-hostname MyWeb1
              echo "toor1234." | passwd --stdin root
              sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
              sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/" /etc/ssh/sshd_config
              systemctl restart sshd

              yum install -y httpd
              systemctl enable --now httpd

              echo "<h1>MyWeb1 test web page</h1>" > /var/www/html/index.html
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "MyWeb1"
  }
}

