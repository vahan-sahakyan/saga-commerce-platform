package config

import "os"

type Config struct {
	Port             string
	PostgresHost     string
	PostgresPort     string
	PostgresDB       string
	PostgresUser     string
	PostgresPassword string
	RedisHost        string
	RedisPort        string
	RedisPassword    string
	KafkaBootstrap   string
	JaegerEndpoint   string
}

func Load() *Config {
	return &Config{
		Port:             getEnv("PORT", "8080"),
		PostgresHost:     getEnv("POSTGRES_HOST", "localhost"),
		PostgresPort:     getEnv("POSTGRES_PORT", "5432"),
		PostgresDB:       getEnv("POSTGRES_DB", "inventory_db"),
		PostgresUser:     getEnv("POSTGRES_USER", "saga"),
		PostgresPassword: getEnv("POSTGRES_PASSWORD", "saga-password"),
		RedisHost:        getEnv("REDIS_HOST", "localhost"),
		RedisPort:        getEnv("REDIS_PORT", "6379"),
		RedisPassword:    getEnv("REDIS_PASSWORD", "redis-password"),
		KafkaBootstrap:   getEnv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"),
		JaegerEndpoint:   getEnv("JAEGER_ENDPOINT", "http://localhost:14268/api/traces"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
