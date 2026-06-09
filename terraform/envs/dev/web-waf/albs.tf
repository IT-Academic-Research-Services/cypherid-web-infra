data "aws_lb" "czid_web_service" {
  name = local.web_service_alb_name
}

locals {
  web_service_alb_name = "${var.project}-${var.env}-web"
  alb_arn              = data.aws_lb.czid_web_service.arn
}
