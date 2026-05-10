import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # database
    postgres_host: str = os.getenv("POSTGRES_HOST", "localhost")
    postgres_port: str = os.getenv("POSTGRES_PORT", "5432")
    postgres_db: str = os.getenv("POSTGRES_DB", "payment_db")
    postgres_user: str = os.getenv("POSTGRES_USER", "saga")
    postgres_password: str = os.getenv("POSTGRES_PASSWORD", "saga-password")
    
    # redis
    redis_host: str = os.getenv("REDIS_HOST", "localhost")
    redis_port: int = int(os.getenv("REDIS_PORT", "6379"))
    redis_password: str = os.getenv("REDIS_PASSWORD", "redis-password")
    
    # kafka
    kafka_bootstrap_servers: str = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
    
    # observability
    jaeger_endpoint: str = os.getenv("JAEGER_ENDPOINT", "http://localhost:14268/api/traces")
    
    # service
    service_name: str = "payment-service"
    
    @property
    def database_url(self) -> str:
        return f"postgresql://{self.postgres_user}:{self.postgres_password}@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
    
    class Config:
        case_sensitive = False


settings = Settings()
