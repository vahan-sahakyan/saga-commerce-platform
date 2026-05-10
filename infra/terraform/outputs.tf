# outputs for easy access to connection strings and endpoints

output "argocd_server" {
  description = "ArgoCD server endpoint"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

output "argocd_password_command" {
  description = "command to retrieve ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "grafana_endpoint" {
  description = "Grafana endpoint"
  value       = "kubectl port-forward svc/prometheus-grafana -n observability 3000:80"
}

output "jaeger_endpoint" {
  description = "Jaeger UI endpoint"
  value       = "kubectl port-forward svc/jaeger-query -n observability 16686:16686"
}

output "redpanda_console" {
  description = "Redpanda console endpoint"
  value       = "kubectl port-forward svc/redpanda-console -n infra 8080:8080"
}

output "postgresql_connection" {
  description = "PostgreSQL connection string"
  value       = "postgresql://saga:saga-password@postgresql.infra.svc.cluster.local:5432/saga"
  sensitive   = true
}

output "redis_connection" {
  description = "Redis connection string"
  value       = "redis://:redis-password@redis-master.infra.svc.cluster.local:6379"
  sensitive   = true
}
