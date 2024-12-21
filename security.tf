#This is establishing a VPC with a resouce name of app_vpc
resource "aws_vpc" "AppVPC" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "AppVPC"
  }
}
#Creating 2 subnets connections to aws_vpc named app_subnet_1 & 2
resource "aws_subnet" "AppSubnet1" {
  vpc_id            = aws_vpc.AppVPC.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "AppSubnet1"
  }
}

resource "aws_subnet" "AppSubnet2" {
  vpc_id            = aws_vpc.AppVPC.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "AppSubnet2"
  }
}
# Creating a Security group that acts as a firewall for our instance within our VPC
resource "aws_security_group" "WebTrafficSG" {
  name        = "WebTrafficSG"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.AppVPC.id

#Inbound traffic rules
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Inbound traffic rules
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Inbound traffic rules
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Inbound traffic rules
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
#Outbound traffic rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WebTrafficSG"
  }
}

#Creating a network interface within our subnet
resource "aws_network_interface" "nw-interface1" {
  subnet_id = aws_subnet.AppSubnet1.id
  security_groups = [aws_security_group.WebTrafficSG.id]
  tags = {
    Name        = "nw-interface1"
  }  
}

#Creating a network interface within our subnet
resource "aws_network_interface" "nw-interface2" {
  subnet_id = aws_subnet.AppSubnet2.id
  security_groups = [aws_security_group.WebTrafficSG.id]
  tags = {
    Name        = "nw-interface2"
  }  
}

#Creating an internet gateway within our VPC
resource "aws_internet_gateway" "AppIGW" {
  vpc_id = aws_vpc.AppVPC.id

  tags = {
    Name = "AppInternetGateway"
  }
}

#Creating a route table within our VPC
resource "aws_route_table" "AppRouteTable" {
  vpc_id = aws_vpc.AppVPC.id
  tags = {
    Name = "AppRouteTable"
  }
}


#Creating a route within our route table
output "route_table_ID" {
  value = aws_route_table.AppRouteTable.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.AppRouteTable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.AppIGW.id
}

#Creating a route table subnet association
resource "aws_eip" "public_ip1" {
  domain = "vpc"
  network_interface = aws_network_interface.nw-interface1.id
}

resource "aws_eip" "public_ip2" {
  domain = "vpc"
  network_interface = aws_network_interface.nw-interface2.id
}