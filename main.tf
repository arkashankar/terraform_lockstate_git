provider "aws" {
  
  region     = "us-east-2"
}
variable "server_port" {
  description = "The port the web server will be listening"
  type        = number
  default     = 8080
}

variable "elb_port" {
  description = "The port the elb will be listening"
  type        = number
  default     = 8080
}

#################### TARGET GROUP ################################################################################################################################################

resource "aws_lb_target_group" "my-target-group-backend" {
  name        = "neptune-tf-lb-tg-backend"
  #target_type = "alb"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = "vpc-0d67d7932cab587a3"
  health_check {
    port = 8080
  }
} 
resource "aws_lb_target_group" "my-target-group-react" {
  name        = "neptune-tf-lb-tg-react"
  #target_type = "alb"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = "vpc-0d67d7932cab587a3"
  health_check {
    port = 3000
  }
}

######################## LAUNCH TEMPLATE ############################################################################################################################################

resource "aws_launch_template" "asg-launch-backend" {
  image_id        = "ami-0fa49cc9dc8d62c84"
  instance_type   = "t2.micro"
  name = "neptune-lt-backend"
  #vpc_security_group_ids = [aws_security_group.busybox.id]
  iam_instance_profile {
    name = "cloudwatch"
  }
  monitoring {
    enabled = true
  }
  user_data = filebase64("${path.module}/install.sh")
  network_interfaces {
    associate_public_ip_address = true
    security_groups = ["${aws_security_group.busybox.id}"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
      Name = "test"
    }
}

resource "aws_launch_template" "asg-launch-react" {
  image_id        = "ami-0fa49cc9dc8d62c84"
  instance_type   = "t2.micro"
  name = "neptune-lt-react"
  iam_instance_profile {
    name = "cloudwatch"
  }
  monitoring {
    enabled = true
  }
  #vpc_security_group_ids = [aws_security_group.busybox.id]

  user_data = filebase64("${path.module}/react-install.sh")
  network_interfaces {
    associate_public_ip_address = true
    security_groups = ["${aws_security_group.busybox.id}"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
      Name = "test"
    }
}

########################################### SECURITY GROUP #######################################################################################################

resource "aws_security_group" "busybox" {
  name = "terraform-busybox-sg-1"
  vpc_id      = "vpc-0d67d7932cab587a3"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elb-sg" {
  name = "terraform-neptune-sg"
  vpc_id      = "vpc-0d67d7932cab587a3"
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Inbound HTTP from anywhere
    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################### ASG #############################################################################################################################################

resource "aws_autoscaling_group" "asg-sample-backend" {
  #launch_configuration = aws_launch_configuration.asg-launch-config-sample.id
  #availability_zones   = ["us-east-2a"]
  min_size             = 2
  max_size             = 5
  #desired_capacity     = 3 
  name = "neptune-asg-backend-tf"
  vpc_zone_identifier = ["subnet-0c985f032b10b102b", "subnet-0016d22d25426f81a"]
  target_group_arns = ["${aws_lb_target_group.my-target-group-backend.arn}"]
  #health_check_type = "ELB"
  launch_template {
    id = aws_launch_template.asg-launch-backend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "neptune-terraform-asg-sample"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "asg-sample-react" {
  #launch_configuration = aws_launch_configuration.asg-launch-config-sample.id
  #availability_zones   = ["us-east-2a"]
  name                 = "neptune-asg-react-tf"
  min_size             = 2
  max_size             = 5
  vpc_zone_identifier = ["subnet-0c985f032b10b102b", "subnet-0016d22d25426f81a"]
  target_group_arns = ["${aws_lb_target_group.my-target-group-react.arn}"]
  #health_check_type = "ELB"
  launch_template {
    id = aws_launch_template.asg-launch-react.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "neptune-terraform-asg-sample"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "backend-policy" {
  name = "neptune-backend-policy"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = "${aws_autoscaling_group.asg-sample-backend.name}"
  estimated_instance_warmup = 100

  target_tracking_configuration {
    predefined_metric_specification{
      predefined_metric_type = "ASGAverageCPUUtilization"

    }
    target_value = "60"
  }
}
  resource "aws_autoscaling_policy" "frontend-policy" {
  name = "neptune-frontend-policy"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = "${aws_autoscaling_group.asg-sample-react.name}"
  estimated_instance_warmup = 100

  target_tracking_configuration {
    predefined_metric_specification{
      predefined_metric_type = "ASGAverageNetworkIn"

    }
    target_value = "60"
  }
}

############################ APPLICATION LOAD BALANCER ###########################################################################################################

resource "aws_lb" "my-aws-alb" {
  name     = "neptune-alb"
  internal = false

  security_groups = [
    "${aws_security_group.elb-sg.id}",
  ]

  subnets = ["subnet-0128ce9f0240a5cd6", "subnet-0260e24d5d42bba3b"]

  tags = {
    Name = "neptune-alb"
  }

  ip_address_type    = "ipv4"
  load_balancer_type = "application"

  enable_deletion_protection = true
}


##################################### ALB LISTENER ###############################################################################################

resource "aws_lb_listener" "my-test-alb-listner" {
  load_balancer_arn = "${aws_lb.my-aws-alb.arn}"
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.my-target-group-backend.arn}"
  }
}

resource "aws_lb_listener" "my-test-alb-frontend" {
  load_balancer_arn = "${aws_lb.my-aws-alb.arn}"
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.my-target-group-react.arn}"
  }
}

# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "terraform-state-arka-1"

#   lifecycle {
#     prevent_destroy = true 
#   }
# }

# resource "aws_s3_bucket_versioning" "versioning_example" {
#   bucket = aws_s3_bucket.terraform_state.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
#   bucket = aws_s3_bucket.terraform_state.bucket

#   rule {
#     apply_server_side_encryption_by_default {
      
#       sse_algorithm     = "AES256"
#     }
#   }
# }
# resource "aws_dynamodb_table" "terraform_locks" {
#   name = "terraform_state_locking"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# }

terraform {
  backend "s3" {
    bucket  = "terraform-state-arka-1"
    key     = "global/terraform/remote/s3/terraform.tfstate"
    region = "us-east-2"
    dynamodb_table = "terraform_state_locking"
  }
}