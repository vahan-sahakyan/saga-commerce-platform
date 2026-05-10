import json
import logging
import time
import threading
from datetime import datetime
from kafka import KafkaProducer
from app.core.config import settings
from app.db.database import SessionLocal
from app.models.models import OutboxEvent

logger = logging.getLogger(__name__)


class EventPublisher:
    def __init__(self):
        self.producer = KafkaProducer(
            bootstrap_servers=settings.kafka_bootstrap_servers.split(','),
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            acks='all',
            retries=3
        )
        self.running = False
    
    def start(self):
        """Start publishing events in a background thread"""
        self.running = True
        thread = threading.Thread(target=self._publish_loop, daemon=True)
        thread.start()
        logger.info("event publisher started")
    
    def stop(self):
        """Stop publishing events"""
        self.running = False
        self.producer.close()
        logger.info("event publisher stopped")
    
    def _publish_loop(self):
        """Poll outbox and publish events every 5 seconds"""
        while self.running:
            try:
                self._publish_pending_events()
                time.sleep(5)
            except Exception as e:
                logger.error(f"error in publish loop: {e}", exc_info=True)
    
    def _publish_pending_events(self):
        """Publish all pending events from outbox"""
        db = SessionLocal()
        try:
            # get unpublished events
            events = db.query(OutboxEvent).filter(
                OutboxEvent.published == False
            ).order_by(OutboxEvent.timestamp).limit(10).all()
            
            if not events:
                return
            
            logger.info(f"publishing {len(events)} events from outbox")
            
            for event in events:
                try:
                    # construct kafka message
                    message = {
                        'eventId': event.event_id,
                        'sagaId': event.saga_id,
                        'eventType': event.event_type,
                        'producer': event.producer,
                        'timestamp': event.timestamp.isoformat(),
                        'payload': json.loads(event.payload)
                    }
                    
                    # send to kafka
                    future = self.producer.send(
                        'payment-events',
                        key=event.saga_id.encode('utf-8'),
                        value=message
                    )
                    
                    # wait for send to complete
                    future.get(timeout=10)
                    
                    # mark as published
                    event.published = True
                    event.published_at = datetime.now()
                    db.commit()
                    
                    logger.info(f"published event: {event.event_id} for saga: {event.saga_id}")
                
                except Exception as e:
                    logger.error(f"error publishing event {event.event_id}: {e}", exc_info=True)
                    db.rollback()
        
        finally:
            db.close()
