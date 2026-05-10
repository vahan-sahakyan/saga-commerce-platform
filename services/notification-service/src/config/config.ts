export interface Config {
  serviceName: string;
  port: number;
  kafkaBootstrapServers: string;
  jaegerEndpoint: string;
}

export const config: Config = {
  serviceName: process.env.SERVICE_NAME || 'notification-service',
  port: parseInt(process.env.PORT || '8080', 10),
  kafkaBootstrapServers: process.env.KAFKA_BOOTSTRAP_SERVERS || 'localhost:9092',
  jaegerEndpoint: process.env.JAEGER_ENDPOINT || 'http://localhost:14268/api/traces',
};
