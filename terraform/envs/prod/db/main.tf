resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.env}-rds"
  description = "Allow MySQL traffic inbound"

  vpc_id = data.terraform_remote_state.cloud-env.outputs.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block]
  }

  tags = {
    terraform = true
    Name      = "${var.project}-${var.env}-rds"
  }
}
