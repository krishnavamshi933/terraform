provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "myvpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "myvpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "private"
  }
}

resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "myigw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "private"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
resource "aws_security_group" "instance_sg" {
  name        = "instance_sg"
  description = "Security group for instances allowing ports 22 and 80"
  vpc_id      = aws_vpc.myvpc.id 

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allows all traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "my_key_pair" {
  key_name   = "my_key_pair"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "public_instance" {
  ami           = "ami-0a3c3a20c09d6f377"  
  instance_type = "t2.micro"             
  key_name      = aws_key_pair.my_key_pair.key_name
  subnet_id     = aws_subnet.public.id  

  security_groups = [aws_security_group.instance_sg.id]

  tags = {
    Name = "my_instance"
  }
}
resource "aws_security_group" "private_instance_sg" {
  name        = "private_instance_sg"
  description = "Security group for private instance allowing SSH from public instance"
  vpc_id      = aws_vpc.myvpc.id 

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_instance.public_instance.private_ip]  # Allow SSH only from the public instance
  }
}

resource "aws_instance" "private_instance" {
  ami           = "ami-0a3c3a20c09d6f377" 
  instance_type = "t2.micro"                
  key_name      = aws_key_pair.my_key_pair.key_name
  subnet_id     = aws_subnet.private.id     

  vpc_security_group_ids = [aws_security_group.private_instance_sg.id]

  tags = {
    Name = "private_instance"
  }
}
resource "aws_eip" "nat" {
  instance = null  
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}
