from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.db.database import get_db
from app.services.payment_service import PaymentService
from app.models.models import Payment

router = APIRouter(prefix="/api/payments", tags=["payments"])


class PaymentRequest(BaseModel):
    order_id: str
    amount: float


class PaymentResponse(BaseModel):
    id: str
    order_id: str
    amount: float
    currency: str
    status: str
    failure_reason: str | None = None
    
    class Config:
        from_attributes = True


@router.post("/process", response_model=PaymentResponse)
def process_payment(request: PaymentRequest, db: Session = Depends(get_db)):
    """Process a payment (manual endpoint, normally triggered by events)"""
    payment_service = PaymentService(db)
    payment = payment_service.process_payment(request.order_id, request.amount)
    return payment


@router.get("/{order_id}", response_model=PaymentResponse)
def get_payment(order_id: str, db: Session = Depends(get_db)):
    """Get payment by order ID"""
    payment_service = PaymentService(db)
    payment = payment_service.get_payment_by_order_id(order_id)
    
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    
    return payment


@router.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "payment-service"}
