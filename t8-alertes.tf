
#            TEST

# Alarm para CPU alto
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "LGZ-CPU-High"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Escalar hacia arriba si CPU > 70%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.lgz_as_group.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_up_policy.arn
  ]
}

# Policy de escalado hacia arriba
resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "LGZ-scale-up-policy"
  autoscaling_group_name  = aws_autoscaling_group.lgz_as_group.name
  adjustment_type         = "ChangeInCapacity"
  scaling_adjustment      = 1
  cooldown                = 300
}

# Alarm para CPU bajo
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "LGZ-CPU-Low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Escalar hacia abajo si CPU < 30%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.lgz_as_group.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_down_policy.arn
  ]
}

# Policy de escalado hacia abajo
resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "LGZ-scale-down-policy"
  autoscaling_group_name  = aws_autoscaling_group.lgz_as_group.name
  adjustment_type         = "ChangeInCapacity"
  scaling_adjustment      = -1
  cooldown                = 300
}


# Alarm basada en el ALB (RequestCount per Target)
resource "aws_cloudwatch_metric_alarm" "alb_requests_high" {
  alarm_name          = "LGZ-ALB-HighTraffic"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Escalar hacia arriba si ALB recibe >100 requests por target"

  dimensions = {
    TargetGroup = aws_lb_target_group.lgz-alb-tg.name
    LoadBalancer = aws_lb.lgz-alb.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_up_policy.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "alb_requests_low" {
  alarm_name          = "LGZ-ALB-LowTraffic"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "Escalar hacia abajo si ALB recibe <10 requests por target"

  dimensions = {
    TargetGroup = aws_lb_target_group.lgz-alb-tg.name
    LoadBalancer = aws_lb.lgz-alb.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_down_policy.arn
  ]
}
