# EC2: 5000 nur ALB->EC2
resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb_5000" {
  security_group_id            = aws_security_group.ec2_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = 5000
  to_port                      = 5000
  ip_protocol                  = "tcp"
  description                  = "App traffic from ALB only"
}

# EC2: SSH nur von eigener IP
resource "aws_vpc_security_group_ingress_rule" "ssh_from_me" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from my IP only"
}
