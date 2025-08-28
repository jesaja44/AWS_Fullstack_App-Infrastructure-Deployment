resource "aws_security_group" "alb_sg" {
  name_prefix = "alb-sg-"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "grocery-alb-sg" }
}

resource "aws_lb" "app" {
  name               = "grocery-alb-${random_id.suffix.hex}"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = length(local.public_subnet_ids) > 0 ? local.public_subnet_ids : data.aws_subnets.selected.ids
}

resource "aws_lb_target_group" "app_tg" {
  name     = "grocery-tg-${random_id.suffix.hex}"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id
  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "app_instance" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web.id
  port             = 5000
}
