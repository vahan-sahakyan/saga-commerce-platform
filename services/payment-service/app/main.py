import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from app.core.config import settings
from app.db.database import init_db
from app.api.endpoints import router
from app.events.consumer import EventConsumer
from app.events.publisher import EventPublisher

# configure logging
logging.basicConfig(
    level=logging.INFO,
    format='{"timestamp":"%(asctime)s","level":"%(levelname)s","service":"%(name)s","message":"%(message)s"}'
)
logger = logging.getLogger(__name__)

# global instances
consumer = None
publisher = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown"""
    global consumer, publisher
    
    # startup
    logger.info("starting payment service...")
    
    # initialize database
    init_db()
    logger.info("database initialized")
    
    # start event consumer
    consumer = EventConsumer()
    consumer.start()
    
    # start event publisher
    publisher = EventPublisher()
    publisher.start()
    
    logger.info("payment service started successfully")
    
    yield
    
    # shutdown
    logger.info("shutting down payment service...")
    
    if consumer:
        consumer.stop()
    
    if publisher:
        publisher.stop()
    
    logger.info("payment service stopped")


# create FastAPI app
app = FastAPI(
    title="Payment Service",
    description="Payment processing service for Saga Commerce Platform",
    version="1.0.0",
    lifespan=lifespan
)

# include routers
app.include_router(router)


@app.get("/health")
def health():
    """Health check endpoint"""
    return {"status": "healthy", "service": settings.service_name}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=settings.port)
