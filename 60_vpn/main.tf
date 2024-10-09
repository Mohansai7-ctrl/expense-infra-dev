#Here the AMI OpenVPN Access Server Community Image fe8020b*
resource "aws_key_pair" "vpn_key" {
  key_name   = "openvpn"
  public_key = file("~/.ssh/openvpn.pub")
}


module "vpn" {
    source = "terraform-aws-modules/ec2-instance/aws"

    name = "${local.resource_name}-vpn"

    ami = local.ami
    key_name = aws_key_pair.vpn_key.key_name
    instance_type = "t3.micro"
    vpc_security_group_ids = [local.vpn_sg_id]
    subnet_id = local.public_subnet_ids

    tags = merge(
        var.common_tags,
        var.vpn_tags,
        {
            Name = "${local.resource_name}-vpn"
        }
    )
}