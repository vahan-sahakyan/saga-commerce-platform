# namespaces for the platform

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace" "infra" {
  metadata {
    name = "infra"
  }
}

resource "kubernetes_namespace" "services" {
  metadata {
    name = "services"
  }
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
  }
}
