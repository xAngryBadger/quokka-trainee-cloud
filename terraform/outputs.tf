output "alb_dns_name" {
  description = "DNS do Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Nome do service ECS"
  value       = aws_ecs_service.app.name
}
