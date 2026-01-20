#         VPC 
resource "aws_vpc" "main" {
 cidr_block = "10.8.0.0/16"
 instance_tenancy = "default"
 tags = {
   Name = "LGZ-VPC1"
 }
}

resource "aws_eip" "lgz-nat_eip" {
  domain = "vpc" 
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.lgz-nat_eip.id
  subnet_id     = aws_subnet.public1.id
}

resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}


#         Public 
resource "aws_subnet" "public1" {
vpc_id = aws_vpc.main.id
cidr_block = "10.8.1.0/24"
map_public_ip_on_launch = true
availability_zone = "us-east-1a"

tags = {
  Name = "Public-Subnet-1"
}
}

resource "aws_subnet" "public2" {
vpc_id = aws_vpc.main.id
cidr_block = "10.8.2.0/24"
map_public_ip_on_launch = true
availability_zone = "us-east-1b"

tags = {
  Name = "Public-Subnet-2"
}
}

resource "aws_internet_gateway" "igw" {
 vpc_id = aws_vpc.main.id
 tags = {
   Name = "Internet-Gateway"
 }
}

resource "aws_route_table" "public_rt" {
 vpc_id = aws_vpc.main.id
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.igw.id
 }
 tags = {
   Name = "Public-Route-Table"
 }
}

resource "aws_route_table_association" "lgz-rt-public1" {
 subnet_id = aws_subnet.public1.id
 route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "lgz-rt-public2" {
 subnet_id = aws_subnet.public2.id
 route_table_id = aws_route_table.public_rt.id
}

#               Private 
resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.8.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private-Subnet-1"
    Tier = "private"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.8.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private-Subnet-2"
    Tier = "private"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Private-Route-Table"
  }
}

resource "aws_route_table_association" "lgz-rt-private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "lgz-rt-private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private_rt.id
}



# Launch template
resource "aws_launch_template" "lt_webservers" {
  name_prefix            = "LGZ-WebServer-"
  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = "vockey"

  vpc_security_group_ids = [aws_security_group.lgz-ec2-sg.id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 10
      volume_type           = "gp2"
      delete_on_termination = true
      encrypted             = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/instance_config.sh", {
    env = "prod"
  }))

}


# AMI AWS Linux 2023 
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  owners = ["137112412989"]
}


#Application Load Balancer
resource "aws_lb" "lgz-alb" {
  name               = "lgz-loadbalancer"
  load_balancer_type = "application"
  internal           = false
  subnets = [
    aws_subnet.public1.id,
    aws_subnet.public2.id 
  ]
  security_groups = [aws_security_group.lgz-alb-sg.id]

  tags = {
    Name = "LGZ-App-LoadBalancer"
  }
  
}

#Load balancer listenner rule
resource "aws_lb_listener" "lgz-alb-listener" {
  load_balancer_arn = aws_lb.lgz-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lgz-alb-tg.arn
  }
}


# TEST CloudWatch metric policy
resource "aws_autoscaling_policy" "lgz-cpu-tracking" {
  name = "LGZ-scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.lgz_as_group.name
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
}
