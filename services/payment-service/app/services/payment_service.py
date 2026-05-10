import logging
import json
import uuid
import random
from datetime import datetime
from sqlalchemy.orm import Session
from app.models.models import Payment, OutboxEvent
from app.core.config import settings

logger = logging.getLogger(__name__)


class PaymentService:
    def __init__(self, db: Session):
        self.db = db
    
    def process_payment(self, order_id: str, amount: float) -> Payment:
        """
        Process payment for an order.
        Simulates payment processing with 80% success rate.
        """
        logger.info(f"processing payment for order: {order_id}, amount: {amount}")
        
        # create payment record
        payment = Payment(
            order_id=order_id,
            amount=amount,
            currency="USD",
            status="PENDING"
        )
        self.db.add(payment)
        self.db.flush()  # get the payment ID
        
        # simulate payment processing (80% success rate)
        success = random.random() < 0.8
        
        if success:
            payment.status = "SUCCEEDED"
            self.db.commit()
            logger.info(f"payment succeeded: {payment.id}")
            
            # create outbox event
            self._create_payment_succeeded_event(order_id, payment.id, amount)
        else:
            payment.status = "FAILED"
            payment.failure_reason = "Payment declined by payment gateway"
            self.db.commit()
            logger.warning(f"payment failed: {payment.id}")
            
            # create outbox event
            self._create_payment_failed_event(order_id, payment.failure_reason)
        
        return payment
    
    def _create_payment_succeeded_event(self, order_id: str, payment_id: str, amount: float):
        """Create PaymentSucceeded event in outbox"""
        event_id = str(uuid.uuid4())
        
        payload = {
            "orderId": order_id,
            "paymentId": payment_id,
            "amount": amount,
            "currency": "USD"
        }
        
        event = OutboxEvent(
            event_id=event_id,
            saga_id=order_id,
            event_type="PaymentSucceeded",
            producer=settings.service_name,
            payload=json.dumps(payload),
            published=False
        )
        
        self.db.add(event)
        self.db.commit()
        logger.info(f"outbox event created: {event_id}")
    
    def _create_payment_failed_event(self, order_id: str, reason: str):
        """Create PaymentFailed event in outbox"""
        event_id = str(uuid.uuid4())
        
        payload = {
            "orderId": order_id,
            "reason": reason
        }
        
        event = OutboxEvent(
            event_id=event_id,
            saga_id=order_id,
            event_type="PaymentFailed",
            producer=settings.service_name,
            payload=json.dumps(payload),
            published=False
        )
        
        self.db.add(event)
        self.db.commit()
        logger.info(f"outbox event created: {event_id}")
    
    def get_payment_by_order_id(self, order_id: str) -> Payment:
        """Get payment by order ID"""
        return self.db.query(Payment).filter(Payment.order_id == order_id).first()
