resource "aws_lb_target_group" "MyNLBtargetGroup" {
    depends_on = [aws_instance.MyWeb2, aws_instance.MyWeb21]
    name        = "MyNLBtargetGroup"
    port        = 80
    protocol    = "TCP"
    vpc_id      = aws_vpc.MyVPC07.id
}

resource "aws_lb_target_group_attachment" "MyALBattachMyWeb2" {
  target_group_arn = aws_lb_target_group.MyNLBtargetGroup.arn
  target_id        = aws_instance.MyWeb2.id
  depends_on       = [aws_instance.MyWeb2]
}

resource "aws_lb_target_group_attachment" "MyNLBAttachMyWeb3" {
  target_group_arn = aws_lb_target_group.MyNLBtargetGroup.arn
  target_id        = aws_instance.MyWeb21.id
  depends_on       = [aws_instance.MyWeb21]
}

resource "aws_lb" "MyNLB" {
  name               = "MyNLB"
  internal           = false
  load_balancer_type = "network"
  #security_groups    = [aws_security_group.MyPublic2Secugroup.id]
  subnets = [aws_subnet.MyPublic2Subnet.id]
  enable_deletion_protection = false
}

resource "aws_lb_listener" "MyNLBListener" {
  load_balancer_arn = aws_lb.MyNLB.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.MyNLBtargetGroup.arn
  }
}