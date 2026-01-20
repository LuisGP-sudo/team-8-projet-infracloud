# Alarm para CPU alto
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "LGZ-CPU-High"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Escalar hacia arriba si CPU > 70%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.lgz_as_group.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_up_policy.arn
  ]
}

# Alarm basada en ALB: tráfico ALTO
resource "aws_cloudwatch_metric_alarm" "alb_requests_high" {
  alarm_name          = "LGZ-ALB-HighTraffic"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Escalar hacia arriba si ALB recibe >100 requests por target"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.lgz-alb-tg.arn_suffix
    LoadBalancer = aws_lb.lgz-alb.arn_suffix
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_up_policy.arn
  ]
}

# Alarm basada en ALB: tráfico BAJO
resource "aws_cloudwatch_metric_alarm" "alb_requests_low" {
  alarm_name          = "LGZ-ALB-LowTraffic"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Escalar hacia abajo si ALB recibe <10 requests por target"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.lgz-alb-tg.arn_suffix
    LoadBalancer = aws_lb.lgz-alb.arn_suffix
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_down_policy.arn
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
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "Escalar hacia abajo si CPU < 20%"
  treat_missing_data  = "notBreaching"

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


resource "aws_cloudwatch_dashboard" "lgz_dashboard" {
  dashboard_name = "LGZ-Infrastructure-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      #Alarm Status Widget
      {
        type = "alarm"
        x = 0
        y = 0
        width = 12
        height = 6
        properties = {
          alarms = [
            aws_cloudwatch_metric_alarm.cpu_high.arn,
            aws_cloudwatch_metric_alarm.cpu_low.arn,
            aws_cloudwatch_metric_alarm.alb_requests_high.arn,
            aws_cloudwatch_metric_alarm.alb_requests_low.arn
          ]
          title = "Alarm Satus"
        }
      },

      #CPU Utilization Line Chart
      {
        type = "metric"
        x = 12
        y = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.lgz_as_group.name]
          ]
          view = "timeSeries"
          stacked = false
          region = "us-east-1"
          title = "CPU Utilization"
          period = 60
        }
      },

      #Network Metrics Table
      {
        type = "metric"
        x = 0
        y = 6
        width = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", aws_autoscaling_group.lgz_as_group.name],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", aws_autoscaling_group.lgz_as_group.name],
            ["AWS/EC2", "NetworkPacketsIn", "AutoScalingGroupName", aws_autoscaling_group.lgz_as_group.name],
            ["AWS/EC2", "NetworkPacketsOut", "AutoScalingGroupName", aws_autoscaling_group.lgz_as_group.name]
          ]
          view = "timeSeries"
          stacked = false
          region = "us-east-1"
          title = "Network Metrics"
          period = 60
        }
      }
    ]
  })
}

