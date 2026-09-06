# Just for show -- do not apply. We hit the ALB DNS name instead of creating
# a custom domain in Route 53.
/*
data "aws_route53_zone" "mcp" {
  name = var.mcp_hosted_zone_name
}

resource "aws_acm_certificate" "mcp" {
  domain_name       = var.mcp_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "mcp_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.mcp.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.mcp.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "mcp" {
  certificate_arn         = aws_acm_certificate.mcp.arn
  validation_record_fqdns = [for r in aws_route53_record.mcp_cert_validation : r.fqdn]
}

resource "aws_route53_record" "mcp" {
  zone_id = data.aws_route53_zone.mcp.zone_id
  name    = var.mcp_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.mcp.dns_name
    zone_id                = aws_lb.mcp.zone_id
    evaluate_target_health = true
  }
}
*/
