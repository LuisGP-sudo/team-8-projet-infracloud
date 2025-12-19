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

  user_data = base64encode(<<EOF
#!/bin/bash

dnf update -y

dnf install -y httpd

systemctl enable httpd.service
systemctl start httpd.service

cat <<EOT > /var/www/html/metadata.sh
#!/bin/bash
TOKEN=\$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: \$TOKEN" http://169.254.169.254/latest/meta-data/instance-id > /var/www/html/index.html
EOT

chmod +x /var/www/html/metadata.sh

/var/www/html/metadata.sh

EOF
)

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
resource "aws_lb_listener" "lgz-alb-rule" {
  load_balancer_arn = aws_lb.lgz-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lgz-alb-tg.arn
  }
}


#TEST Autoscaling Attachment

resource "aws_autoscaling_attachment" "lgz-autoscaling-attachment" {
  autoscaling_group_name = aws_autoscaling_group.lgz_as_group.id
  lb_target_group_arn = aws_lb_target_group.lgz-alb-tg.arn
}

# TEST CloudWatch metric policy
resource "aws_autoscaling_policy" "lgz-cpu-tracking" {
  name = "LGZ-scale-down-policy"
  autoscaling_group_name = aws_autoscaling_group.lgz_as_group.name
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
}
