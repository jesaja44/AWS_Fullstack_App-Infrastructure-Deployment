data "aws_subnet" "by_id" {
  for_each = toset(data.aws_subnets.selected.ids)
  id       = each.value
}
locals {
  public_subnet_ids  = [for s in data.aws_subnet.by_id : s.id if s.map_public_ip_on_launch]
  private_subnet_ids = [for s in data.aws_subnet.by_id : s.id if !s.map_public_ip_on_launch]
}
