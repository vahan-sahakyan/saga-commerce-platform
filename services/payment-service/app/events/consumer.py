import json
import logging
import threading
from kafka import KafkaConsumer
from sqlalchemy.orm import Session
from app.core.config import settings
from app.db.database import SessionLocal
from app.models.models import ProcessedEvent
from app.services.payment_service import PaymentService

logger = logging.getLogger(__name__)


class EventConsumer:
    def __init__(self):
        self.consumer = KafkaConsumer(
            'inventory-events',
            bootstrap_servers=settings.kafka_bootstrap_servers.split(','),
            group_id='payment-service-group',
            auto_offset_reset='earliest',
            enable_auto_commit=False,
            value_deserializer=lambda m: json.loads(m.decode('utf-8'))
        )
        self.running = False
    
    def start(self):
        """Start consuming events in a background thread"""
        self.running = True
        thread = threading.Thread(target=self._consume_loop, daemon=True)
        thread.start()
        logger.info("event consumer started")
    
    def stop(self):
        """Stop consuming events"""
        self.running = False
        self.consumer.close()
        logger.info("event consumer stopped")
    
    def _consume_loop(self):
        """Main consumption loop"""
        while self.running:
            try:
                messages = self.consumer.poll(timeout_ms=1000)
                
                for topic_partition, records in messages.items():
                    for record in records:
                        self._handle_event(record.value)
                        self.consumer.commit()
            
            except Exception as e:
                logger.error(f"error consuming events: {e}", exc_info=True)
    
    def _handle_event(self, event: dict):
        """Handle a single event"""
        event_id = event.get('eventId')
        event_type = event.get('eventType')
        
        logger.info(f"received event: {event_id} type: {event_type}")
        
        db = SessionLocal()
        try:
            # check idempotency
            existing = db.query(ProcessedEvent).filter(ProcessedEvent.event_id == event_id).first()
            if existing:
                logger.info(f"event already processed: {event_id}")
                return
            
            # handle event
            if event_type == "InventoryReserved":
                self._handle_inventory_reserved(event, db)
            else:
                logger.warning(f"unknown event type: {event_type}")
                return
            
            # mark as processed
            processed = ProcessedEvent(
                event_id=event_id,
                event_type=event_type
            )
            db.add(processed)
            db.commit()
            
            logger.info(f"processed event: {event_id}")
        
        except Exception as e:
            logger.error(f"error handling event {event_id}: {e}", exc_info=True)
            db.rollback()
            raise
        
        finally:
            db.close()
    
    def _handle_inventory_reserved(self, event: dict, db: Session):
        """Handle InventoryReserved event"""
        payload = event.get('payload', {})
        order_id = payload.get('orderId')
        
        if not order_id:
            logger.error("missing orderId in InventoryReserved event")
            return
        
        # extract amount from event context or use default
        # in real implementation, this would come from the event or order lookup
        amount = 100.0  # placeholder - would normally look up order total
        
        # process payment
        payment_service = PaymentService(db)
        payment_service.process_payment(order_id, amount)
