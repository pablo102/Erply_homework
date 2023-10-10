provider "aws" {
  region = "eu-west-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_b" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1b"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "nginx_sg" {
  name        = "nginx-sg"
  description = "Security group for Nginx"

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
}

resource "aws_launch_configuration" "nginx_launch_config" {
  name_prefix          = "nginx-launch-config-"
  image_id             = "ami-0c55b159cbfafe1f0"
  instance_type        = "t2.micro"
  security_groups      = [aws_security_group.nginx_sg.id]
  key_name             = "your-key-pair-name"  # Replace with your SSH key pair name/location
  user_data            = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install -y nginx
    sudo amazon-linux-extras install -y php7.4
    sudo systemctl start nginx
    sudo systemctl enable nginx
    sudo systemctl start php-fpm
    sudo systemctl enable php-fpm
    sudo chown -R nginx:nginx /usr/share/nginx/html
    sudo chmod -R 755 /usr/share/nginx/html
    sudo rm -rf /usr/share/nginx/html/*
    sudo git clone https://github.com/maxsite/albireo.git /usr/share/nginx/html

    sudo sed -i '/access_log/s/# //' /etc/nginx/nginx.conf
    sudo sed -i 's/access_log \/var\/log\/nginx\/access.log/access_log

    sudo sed -i '/error_log/s/# //' /etc/nginx/nginx.conf
    sudo sed -i 's/error_log \/var\/log\/nginx\/error.log/error_log

    sudo systemctl restart nginx

    sudo yum install -y awslogs
    sudo systemctl start awslogsd
    sudo systemctl enable awslogsd
  EOF
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nginx_autoscaling" {
  name                 = "nginx-autoscaling-group"
  launch_configuration = aws_launch_configuration.nginx_launch_config.name
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  vpc_zone_identifier  = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  tag {
    key                 = "Name"
    value               = "nginx-instance"
    propagate_at_launch = true
  }

  termination_policies = ["OldestLaunchConfiguration"]
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "nginx-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Scale up if CPU utilization is greater than or equal to 80%"
  alarm_actions       = [aws_autoscaling_policy.scale_up_policy.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.nginx_autoscaling.name
  }
}

resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "scale-up-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.nginx_autoscaling.name
}

resource "aws_cloudwatch_log_group" "nginx_access_logs" {
  name = "/var/log/nginx/access.log"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "nginx_error_logs" {
  name = "/var/log/nginx/error.log"
  retention_in_days = 7
}

output "nginx_instance_public_ip" {
  value = aws_autoscaling_group.nginx_autoscaling.id
}

