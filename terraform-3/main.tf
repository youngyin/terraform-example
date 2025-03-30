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

resource "aws_vpc" "MyVPC06" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true

    tags = {
        Name = "MyVPC06"
    }
}

resource "aws_internet_gateway" "MyIGW" {
    vpc_id = aws_vpc.MyVPC06.id
    tags = {
        Name = "MyIGW"
    }
}

resource "aws_subnet" "MyPublicSubnet" {
    vpc_id = aws_vpc.MyVPC06.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-northeast-2a"
    map_public_ip_on_launch = true # 공인IP 할당

    tags = {
        Name = "MyPublicSubnet"
    }
}

resource "aws_route_table" "MyPublicRouting" {
  depends_on = [aws_internet_gateway.MyIGW]
  vpc_id = aws_vpc.MyVPC06.id

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
  vpc_id      = aws_vpc.MyVPC06.id

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

resource "aws_network_interface" "MyWeb1PrivateAddressest" {
  subnet_id       = aws_subnet.MyPublicSubnet.id
  private_ips     = ["10.0.1.101"]
  security_groups = [aws_security_group.MyPublicSecugroup.id]

   tags = {
    Name = "MyWeb1PrivateAddressest"
  }
}

resource "aws_instance" "MyWeb1" {
  depends_on = [aws_internet_gateway.MyIGW]
  ami                         = data.aws_ami.latest_amazon_linux2.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.tf_keypair.key_name

  network_interface {
    network_interface_id = aws_network_interface.MyWeb1PrivateAddressest.id
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

# NatGateway
resource "aws_eip" "MyNatEIP" {
  domain = "vpc"  
  tags = {
    Name = "MyNatEIP"
  }
}

resource "aws_nat_gateway" "MyNatGW" {
  allocation_id = aws_eip.MyNatEIP.id
  subnet_id     = aws_subnet.MyPublicSubnet.id

  tags = {
    Name = "MyNatGW"
  }

  depends_on = [aws_internet_gateway.MyIGW]
}

# private
resource "aws_subnet" "MyPrivateSubnet" {
    vpc_id = aws_vpc.MyVPC06.id
    cidr_block = "10.0.100.0/24"
    availability_zone = "ap-northeast-2a"
    map_public_ip_on_launch = false # 공인IP 할당

    tags = {
        Name = "MyPrivateSubnet"
    }
}

resource "aws_route_table" "MyPrivateRouting" {
  vpc_id = aws_vpc.MyVPC06.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.MyNatGW.id
  }

  tags = {
    Name = "MyPrivateRouting"
  }

  depends_on = [aws_nat_gateway.MyNatGW]
}

resource "aws_route_table_association" "MyPrivateRouteTableAssociation" {
  subnet_id      = aws_subnet.MyPrivateSubnet.id
  route_table_id = aws_route_table.MyPrivateRouting.id
}

resource "aws_security_group" "MyPrivateSecugroup" {
  name        = "MyPrivateSecugroup"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.MyVPC06.id

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
    Name = "MyPrivateSecugroup"
  }
}

resource "aws_network_interface" "MyWeb11PrivateAddress" {
  subnet_id       = aws_subnet.MyPrivateSubnet.id
  private_ips     = ["10.0.100.101"]
  security_groups = [aws_security_group.MyPrivateSecugroup.id]

   tags = {
    Name = "MyWeb11PrivateAddress"
  }
}

resource "aws_instance" "MyWeb11" {
  depends_on = [aws_nat_gateway.MyNatGW]
  ami                         = data.aws_ami.latest_amazon_linux2.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.tf_keypair.key_name

  network_interface {
    network_interface_id = aws_network_interface.MyWeb11PrivateAddress.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl --static set-hostname MyWeb11
              echo "toor1234." | passwd --stdin root
              sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
              sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/" /etc/ssh/sshd_config
              systemctl restart sshd

              yum install -y httpd
              systemctl enable --now httpd

              echo "<h1>MyWeb11 test web page</h1>" > /var/www/html/index.html
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "MyWeb11"
  }
}



resource "aws_vpc" "MyVPC07" {
  cidr_block = "172.16.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
      Name = "MyVPC07"
  }
}

resource "aws_internet_gateway" "MyIGW2" {
  vpc_id = aws_vpc.MyVPC07.id
  tags = {
      Name = "MyIGW2"
  }
}

resource "aws_subnet" "MyPublic2Subnet" {
  vpc_id = aws_vpc.MyVPC07.id
  cidr_block = "172.16.1.0/24"
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = true # 공인IP 할당

  tags = {
      Name = "MyPublic2Subnet"
  }
}

resource "aws_route_table" "MyPublic2Routing" {
depends_on = [aws_internet_gateway.MyIGW2]
vpc_id = aws_vpc.MyVPC07.id

route {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.MyIGW2.id
}

tags = {
  Name = "MyPublic2Routing"
}
}

resource "aws_route_table_association" "MyPublic2RouteTableAssociation" {
subnet_id      = aws_subnet.MyPublic2Subnet.id
route_table_id = aws_route_table.MyPublic2Routing.id
}

resource "aws_security_group" "MyPublic2Secugroup" {
name        = "MyPublic2Secugroup"
description = "Allow TLS inbound traffic and all outbound traffic"
vpc_id      = aws_vpc.MyVPC07.id

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
  Name = "MyPublic2Secugroup"
}
}

resource "aws_network_interface" "MyWeb2PrivateAddress" {
subnet_id       = aws_subnet.MyPublic2Subnet.id
private_ips     = ["172.16.1.102"]
security_groups = [aws_security_group.MyPublic2Secugroup.id]

 tags = {
  Name = "MyWeb2PrivateAddress"
}
}

resource "aws_instance" "MyWeb2" {
ami                         = data.aws_ami.latest_amazon_linux2.id
instance_type               = "t3.micro"
key_name                    = aws_key_pair.tf_keypair.key_name

network_interface {
  network_interface_id = aws_network_interface.MyWeb2PrivateAddress.id
  device_index         = 0
}

user_data = <<-EOF
            #!/bin/bash
            hostnamectl --static set-hostname MyWeb2
            echo "toor1234." | passwd --stdin root
            sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
            sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/" /etc/ssh/sshd_config
            systemctl restart sshd

            yum install -y httpd
            systemctl enable --now httpd

            echo "<h1>MyWeb2 test web page</h1>" > /var/www/html/index.html
            EOF

user_data_replace_on_change = true

tags = {
  Name = "MyWeb2"
}
}

# NatGateway
resource "aws_eip" "MyNatEIP2" {
domain = "vpc"  
tags = {
  Name = "MyNatEIP2"
}
}

resource "aws_nat_gateway" "MyNatGW2" {
allocation_id = aws_eip.MyNatEIP2.id
subnet_id     = aws_subnet.MyPublic2Subnet.id

tags = {
  Name = "MyNatGW2"
}

depends_on = [aws_internet_gateway.MyIGW2]
}

# private
resource "aws_subnet" "MyPrivate2Subnet" {
  vpc_id = aws_vpc.MyVPC07.id
  cidr_block = "172.16.100.0/24"
  availability_zone = "ap-northeast-2a"
  map_public_ip_on_launch = false # 공인IP 할당

  tags = {
      Name = "MyPrivate2Subnet"
  }
}

resource "aws_route_table" "MyPrivate2Routing" {
vpc_id = aws_vpc.MyVPC07.id

route {
  cidr_block     = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.MyNatGW2.id
}

tags = {
  Name = "MyPrivate2Routing"
}

depends_on = [aws_nat_gateway.MyNatGW2]
}

resource "aws_route_table_association" "MyPrivate2RouteTableAssociation" {
subnet_id      = aws_subnet.MyPrivate2Subnet.id
route_table_id = aws_route_table.MyPrivate2Routing.id
}

resource "aws_security_group" "MyPrivate2Secugroup" {
name        = "MyPrivate2Secugroup"
description = "Allow TLS inbound traffic and all outbound traffic"
vpc_id      = aws_vpc.MyVPC07.id

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
  Name = "MyPrivate2Secugroup"
}
}

resource "aws_network_interface" "MyWeb21PrivateAddress" {
  subnet_id       = aws_subnet.MyPrivate2Subnet.id
  private_ips     = ["172.16.100.101"]
  security_groups = [aws_security_group.MyPrivate2Secugroup.id]

  tags = {
    Name = "MyWeb21PrivateAddress"
  }
}

resource "aws_instance" "MyWeb21" {
  ami                         = data.aws_ami.latest_amazon_linux2.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.tf_keypair.key_name

  network_interface {
    network_interface_id = aws_network_interface.MyWeb21PrivateAddress.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl --static set-hostname MyWeb21
              echo "toor1234." | passwd --stdin root
              sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
              sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/" /etc/ssh/sshd_config
              systemctl restart sshd

              yum install -y httpd
              systemctl enable --now httpd

              echo "<h1>MyWeb21 test web page</h1>" > /var/www/html/index.html
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "MyWeb21"
  }
}
