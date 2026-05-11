from sqlalchemy import Column, String, Float, Boolean, DateTime, Text
from sqlalchemy.sql import func
from app.db.database import Base
import uuid


class Payment(Base):
    __tablename__ = "payments"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id = Column(String, nullable=False, index=True)
    amount = Column(Float, nullable=False)
    currency = Column(String, nullable=False, default="USD")
    status = Column(String, nullable=False)  # PENDING, SUCCEEDED, FAILED
    failure_reason = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class OutboxEvent(Base):
    __tablename__ = "outbox_events"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    event_id = Column(String, nullable=False, unique=True)
    saga_id = Column(String, nullable=False, index=True)
    event_type = Column(String, nullable=False)
    producer = Column(String, nullable=False)
    payload = Column(Text, nullable=False)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    published = Column(Boolean, nullable=False, default=False)
    published_at = Column(DateTime(timezone=True), nullable=True)


class ProcessedEvent(Base):
    __tablename__ = "processed_events"
    
    event_id = Column(String, primary_key=True)
    event_type = Column(String, nullable=False)
    saga_id = Column(String, nullable=True, index=True)
    payload = Column(Text, nullable=True)
    processed_at = Column(DateTime(timezone=True), server_default=func.now())
