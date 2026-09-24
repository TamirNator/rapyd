resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id
  auto_accept = true

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_route" "requester_to_accepter" {
  for_each = toset(var.requester_route_table_ids)

  route_table_id            = each.value
  destination_cidr_block    = var.accepter_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

resource "aws_route" "accepter_to_requester" {
  for_each = toset(var.accepter_route_table_ids)

  route_table_id            = each.value
  destination_cidr_block    = var.requester_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

# Restricts the accepter side's nodes to only accept the specific port the
# cross-VPC app traffic needs, from the requester side's actual EKS nodes
# specifically — not the requester VPC's whole CIDR block, and not the
# whole internet. AWS supports referencing a security group from a peer VPC
# directly for same-region peering (both VPCs here are in the same
# region), so this scopes access to the real source rather than "anything
# in that VPC."
resource "aws_security_group_rule" "allow_peer_ingress" {
  type                     = "ingress"
  from_port                = var.allowed_port
  to_port                  = var.allowed_port
  protocol                 = "tcp"
  source_security_group_id = var.requester_node_security_group_id
  security_group_id        = var.accepter_node_security_group_id
  # AWS security group rule descriptions reject apostrophes (confirmed by
  # testing: "requester's" alone was enough to fail plan), so this is
  # phrased to avoid one rather than relying on getting the allowed
  # character set right from memory.
  description = "Cross-VPC app traffic from the ${var.name} requester EKS nodes"

  # Real apply confirmed this is necessary, not just theoretical: this
  # resource's arguments never reference aws_vpc_peering_connection.this,
  # so Terraform had no implicit ordering guarantee and could try to
  # authorize the cross-VPC reference before the peering connection
  # actually existed/was active, failing with "you have specified two
  # resources that belong to different networks."
  depends_on = [aws_vpc_peering_connection.this]
}
