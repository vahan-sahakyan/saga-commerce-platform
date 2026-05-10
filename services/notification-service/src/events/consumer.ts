import { Kafka, Consumer, EachMessagePayload } from 'kafkajs';
import { config } from '../config/config';
import { BaseEvent, OrderCompletedPayload, OrderFailedPayload } from '../types/events';
import pino from 'pino';

const logger = pino();

export class EventConsumer {
  private kafka: Kafka;
  private consumer: Consumer;
  private processedEvents: Set<string> = new Set();

  constructor() {
    this.kafka = new Kafka({
      clientId: config.serviceName,
      brokers: config.kafkaBootstrapServers.split(','),
    });

    this.consumer = this.kafka.consumer({
      groupId: 'notification-service-group',
    });
  }

  async start(): Promise<void> {
    await this.consumer.connect();
    logger.info('event consumer connected');

    // subscribe to topics
    await this.consumer.subscribe({
      topics: ['order-events', 'payment-events', 'shipping-events'],
      fromBeginning: true,
    });

    await this.consumer.run({
      eachMessage: async (payload: EachMessagePayload) => {
        await this.handleMessage(payload);
      },
    });

    logger.info('event consumer started');
  }

  async stop(): Promise<void> {
    await this.consumer.disconnect();
    logger.info('event consumer stopped');
  }

  private async handleMessage(payload: EachMessagePayload): Promise<void> {
    const { topic, message } = payload;

    if (!message.value) {
      return;
    }

    try {
      const event: BaseEvent = JSON.parse(message.value.toString());

      logger.info({
        eventId: event.eventId,
        eventType: event.eventType,
        topic,
      }, 'received event');

      // check idempotency
      if (this.processedEvents.has(event.eventId)) {
        logger.info({ eventId: event.eventId }, 'event already processed');
        return;
      }

      // handle event based on type
      await this.handleEvent(event);

      // mark as processed
      this.processedEvents.add(event.eventId);

      logger.info({ eventId: event.eventId }, 'processed event');
    } catch (error) {
      logger.error({ error, topic }, 'error handling message');
    }
  }

  private async handleEvent(event: BaseEvent): Promise<void> {
    switch (event.eventType) {
      case 'OrderCompleted':
        await this.handleOrderCompleted(event);
        break;
      case 'OrderFailed':
        await this.handleOrderFailed(event);
        break;
      case 'ShippingInitiated':
        await this.handleShippingInitiated(event);
        break;
      case 'PaymentSucceeded':
        await this.handlePaymentSucceeded(event);
        break;
      default:
        logger.debug({ eventType: event.eventType }, 'ignoring event type');
    }
  }

  private async handleOrderCompleted(event: BaseEvent): Promise<void> {
    const payload = event.payload as OrderCompletedPayload;
    
    logger.info({
      orderId: payload.orderId,
      completedAt: payload.completedAt,
    }, '🎉 ORDER COMPLETED - Notification sent to customer');

    // simulate sending notification (email, SMS, push notification)
    await this.sendNotification({
      type: 'ORDER_COMPLETED',
      orderId: payload.orderId,
      message: `Your order ${payload.orderId} has been completed successfully!`,
    });
  }

  private async handleOrderFailed(event: BaseEvent): Promise<void> {
    const payload = event.payload as OrderFailedPayload;
    
    logger.warn({
      orderId: payload.orderId,
      reason: payload.reason,
      failedAt: payload.failedAt,
    }, '❌ ORDER FAILED - Notification sent to customer');

    // simulate sending notification
    await this.sendNotification({
      type: 'ORDER_FAILED',
      orderId: payload.orderId,
      message: `Your order ${payload.orderId} could not be completed. Reason: ${payload.reason}`,
    });
  }

  private async handleShippingInitiated(event: BaseEvent): Promise<void> {
    const payload = event.payload;
    
    logger.info({
      orderId: payload.orderId,
      shippingId: payload.shippingId,
      trackingNumber: payload.trackingNumber,
    }, '📦 SHIPPING INITIATED - Notification sent to customer');

    // simulate sending notification
    await this.sendNotification({
      type: 'SHIPPING_INITIATED',
      orderId: payload.orderId,
      message: `Your order ${payload.orderId} has been shipped! Tracking number: ${payload.trackingNumber}`,
    });
  }

  private async handlePaymentSucceeded(event: BaseEvent): Promise<void> {
    const payload = event.payload;
    
    logger.info({
      orderId: payload.orderId,
      paymentId: payload.paymentId,
      amount: payload.amount,
    }, '💰 PAYMENT SUCCEEDED - Notification sent to customer');

    // simulate sending notification
    await this.sendNotification({
      type: 'PAYMENT_SUCCEEDED',
      orderId: payload.orderId,
      message: `Payment for order ${payload.orderId} was successful. Amount: $${payload.amount}`,
    });
  }

  private async sendNotification(notification: {
    type: string;
    orderId: string;
    message: string;
  }): Promise<void> {
    // simulate async notification sending
    // in production, this would integrate with email service, SMS gateway, etc.
    logger.info({
      notificationType: notification.type,
      orderId: notification.orderId,
      message: notification.message,
    }, 'notification sent');
  }
}
