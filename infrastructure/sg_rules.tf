# ALB-SG (Security Group des Application Load Balancers) -> EC2-SG : tcp/5000
resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb_5000" {
  security_group_id            = aws_security_group.ec2_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
  description                  = "ALB to EC2 on 5000"
}
