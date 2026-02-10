# ALB Security Group 
resource "aws_security_group" "lgz-alb-sg" {
  name        = "LGZ-LoadBalancer-SecurityGroup"
  description = "Security Group for Loadbalancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
    description = "from anywhere to alb http"
  }

  #ANY
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "from web server to any"
  }
}

# EC2 Security Group
resource "aws_security_group" "lgz-ec2-sg" {
  name        = "LGZ-EC2-SecurityGroup"
  description = "Security Group for Loadbalancer"
  vpc_id      = aws_vpc.main.id

  #HTTP YNOV
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.lgz-alb-sg.id]
    description = "from alb to http"
  }


  #SSH YNOV
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["85.169.101.162/32"]
    description = "from ynov to ssh"

  }

  #SSH MY HOUSE
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["46.193.56.170/32"]
    description = "from house to ssh"

  }

  #ANY
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "from web server to any"
  }

}

#Target Group 
resource "aws_lb_target_group" "lgz-alb-tg" {
  name        = "LGZ-TargetGroup"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

}

# Autoscaling group
resource "aws_autoscaling_group" "lgz_as_group" {
  name = "LGZ-AutoscalingGroup"
  desired_capacity   = 2
  max_size           = 5
  min_size           = 1
  
  vpc_zone_identifier = [
    aws_subnet.private1.id,   
    aws_subnet.private2.id
]


  launch_template {
    id      = aws_launch_template.lt_webservers.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  target_group_arns = [aws_lb_target_group.lgz-alb-tg.arn]

  tag {
    key                 = "Name"
    value               = "LGZ-WebServer"
    propagate_at_launch = true
  }
}


