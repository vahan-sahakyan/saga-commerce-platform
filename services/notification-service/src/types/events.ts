export interface BaseEvent {
  eventId: string;
  sagaId: string;
  eventType: string;
  producer: string;
  timestamp: string;
  payload: any;
}

export interface OrderCompletedPayload {
  orderId: string;
  completedAt: string;
}

export interface OrderFailedPayload {
  orderId: string;
  reason: string;
  failedAt: string;
}

export interface ShippingInitiatedPayload {
  orderId: string;
  shippingId: string;
  trackingNumber: string;
  estimatedDelivery: string;
}
