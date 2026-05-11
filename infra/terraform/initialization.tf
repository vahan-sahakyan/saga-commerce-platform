# Database and Kafka initialization
# This ensures all required databases and topics are created before services start

# Job to create service databases in PostgreSQL
resource "kubernetes_job" "init_databases" {
  metadata {
    name      = "init-databases"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }

  spec {
    backoff_limit            = 3
    ttl_seconds_after_finished = 3600  # keep job for 1 hour for debugging
    template {
      metadata {
        labels = {
          app = "init-databases"
        }
      }
      spec {
        restart_policy = "Never"
        container {
          name  = "init-databases"
          image = "postgres:16"
          env {
            name  = "PGPASSWORD"
            value = "saga-password"
          }
          command = [
            "sh",
            "-c",
            <<-EOT
              # wait for postgresql to be ready
              echo "Waiting for PostgreSQL to be ready..."
              until pg_isready -h postgresql.infra.svc.cluster.local -U saga; do
                echo "PostgreSQL is unavailable - sleeping"
                sleep 2
              done
              echo "PostgreSQL is up!"

              # create databases
              echo "Creating service databases..."
              psql -h postgresql.infra.svc.cluster.local -U saga -d saga -c "CREATE DATABASE order_db;" 2>&1 || echo "order_db may already exist"
              psql -h postgresql.infra.svc.cluster.local -U saga -d saga -c "CREATE DATABASE inventory_db;" 2>&1 || echo "inventory_db may already exist"
              psql -h postgresql.infra.svc.cluster.local -U saga -d saga -c "CREATE DATABASE payment_db;" 2>&1 || echo "payment_db may already exist"

              echo "Databases initialized successfully!"
            EOT
          ]
        }
      }
    }
  }

  depends_on = [helm_release.postgresql]
}

# Job to create Kafka topics in Redpanda
resource "kubernetes_job" "init_kafka_topics" {
  metadata {
    name      = "init-kafka-topics"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }

  spec {
    backoff_limit            = 3
    ttl_seconds_after_finished = 3600  # keep job for 1 hour for debugging
    template {
      metadata {
        labels = {
          app = "init-kafka-topics"
        }
      }
      spec {
        restart_policy = "Never"
        container {
          name  = "init-kafka-topics"
          image = "redpandadata/redpanda:v23.3.6"
          command = [
            "bash",
            "-c",
            <<-EOT
              # wait for redpanda to be ready
              echo "Waiting for Redpanda to be ready..."
              REDPANDA_BROKER="redpanda.infra.svc.cluster.local:9093"
              
              until rpk cluster info -X brokers="$$REDPANDA_BROKER" &>/dev/null; do
                echo "Redpanda is unavailable - sleeping"
                sleep 2
              done
              echo "Redpanda is up!"

              # create topics
              echo "Creating Kafka topics..."
              rpk topic create order-events --brokers "$$REDPANDA_BROKER" -p 1 -r 1 || echo "order-events may already exist"
              rpk topic create inventory-events --brokers "$$REDPANDA_BROKER" -p 1 -r 1 || echo "inventory-events may already exist"
              rpk topic create payment-events --brokers "$$REDPANDA_BROKER" -p 1 -r 1 || echo "payment-events may already exist"
              rpk topic create notification-events --brokers "$$REDPANDA_BROKER" -p 1 -r 1 || echo "notification-events may already exist"

              echo "Kafka topics initialized successfully!"
            EOT
          ]
        }
      }
    }
  }

  depends_on = [helm_release.redpanda]
}
