# Redpanda - Kafka-compatible message broker (simpler than Kafka)

resource "helm_release" "redpanda" {
  name       = "redpanda"
  repository = "https://charts.redpanda.com"
  chart      = "redpanda"
  version    = "5.7.23"
  namespace  = kubernetes_namespace.infra.metadata[0].name

  set {
    name  = "statefulset.replicas"
    value = "1"
  }

  set {
    name  = "resources.cpu.cores"
    value = "1"
  }

  set {
    name  = "resources.memory.container.max"
    value = "2Gi"
  }

  set {
    name  = "storage.persistentVolume.enabled"
    value = "true"
  }

  set {
    name  = "storage.persistentVolume.size"
    value = "10Gi"
  }

  set {
    name  = "tls.enabled"
    value = "false"
  }

  set {
    name  = "auth.sasl.enabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.infra]
}

# PostgreSQL - Database

resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  namespace  = kubernetes_namespace.infra.metadata[0].name

  set {
    name  = "auth.username"
    value = "saga"
  }

  set {
    name  = "auth.password"
    value = "saga-password"
  }

  set {
    name  = "auth.database"
    value = "saga"
  }

  set {
    name  = "primary.persistence.size"
    value = "8Gi"
  }

  depends_on = [kubernetes_namespace.infra]
}

# Redis - Cache

resource "helm_release" "redis" {
  name       = "redis"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "redis"
  namespace  = kubernetes_namespace.infra.metadata[0].name

  set {
    name  = "auth.password"
    value = "redis-password"
  }

  set {
    name  = "master.persistence.size"
    value = "4Gi"
  }

  set {
    name  = "replica.replicaCount"
    value = "1"
  }

  depends_on = [kubernetes_namespace.infra]
}

# Prometheus - Metrics

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.5.0"
  namespace  = kubernetes_namespace.observability.metadata[0].name

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }

  set {
    name  = "grafana.adminPassword"
    value = "admin"
  }

  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  set {
    name  = "grafana.persistence.size"
    value = "4Gi"
  }

  depends_on = [kubernetes_namespace.observability]
}

# Jaeger - Distributed Tracing

resource "helm_release" "jaeger" {
  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  version    = "0.71.14"
  namespace  = kubernetes_namespace.observability.metadata[0].name

  set {
    name  = "allInOne.enabled"
    value = "true"
  }

  set {
    name  = "storage.type"
    value = "memory"
  }

  set {
    name  = "agent.enabled"
    value = "false"
  }

  set {
    name  = "collector.enabled"
    value = "false"
  }

  set {
    name  = "query.enabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.observability]
}
