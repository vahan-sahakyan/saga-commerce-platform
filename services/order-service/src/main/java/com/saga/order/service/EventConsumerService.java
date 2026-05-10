package com.saga.order.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.saga.order.entity.ProcessedEvent;
import com.saga.order.event.BaseEvent;
import com.saga.order.event.FailurePayload;
import com.saga.order.event.InventoryReservedPayload;
import com.saga.order.event.PaymentSucceededPayload;
import com.saga.order.repository.ProcessedEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class EventConsumerService {
    
    private final ProcessedEventRepository processedEventRepository;
    private final OrderService orderService;
    private final ObjectMapper objectMapper;
    
    @KafkaListener(topics = "inventory-events", groupId = "order-service-group")
    @Transactional
    public void consumeInventoryEvents(BaseEvent event, Acknowledgment ack) {
        log.info("received inventory event: {} type: {}", event.getEventId(), event.getEventType());
        
        // check idempotency
        if (processedEventRepository.existsById(event.getEventId())) {
            log.info("event already processed: {}", event.getEventId());
            ack.acknowledge();
            return;
        }
        
        try {
            switch (event.getEventType()) {
                case "InventoryReserved" -> {
                    InventoryReservedPayload payload = objectMapper.convertValue(
                        event.getPayload(), InventoryReservedPayload.class);
                    orderService.handleInventoryReserved(payload.getOrderId());
                }
                case "InventoryFailed" -> {
                    FailurePayload payload = objectMapper.convertValue(
                        event.getPayload(), FailurePayload.class);
                    orderService.handleSagaFailed(payload.getOrderId(), payload.getReason());
                }
            }
            
            // mark as processed
            ProcessedEvent processedEvent = ProcessedEvent.builder()
                .eventId(event.getEventId())
                .eventType(event.getEventType())
                .build();
            processedEventRepository.save(processedEvent);
            
            ack.acknowledge();
            log.info("processed event: {}", event.getEventId());
        } catch (Exception e) {
            log.error("failed to process event: {}", event.getEventId(), e);
            // do not acknowledge - will be retried
        }
    }
    
    @KafkaListener(topics = "payment-events", groupId = "order-service-group")
    @Transactional
    public void consumePaymentEvents(BaseEvent event, Acknowledgment ack) {
        log.info("received payment event: {} type: {}", event.getEventId(), event.getEventType());
        
        // check idempotency
        if (processedEventRepository.existsById(event.getEventId())) {
            log.info("event already processed: {}", event.getEventId());
            ack.acknowledge();
            return;
        }
        
        try {
            switch (event.getEventType()) {
                case "PaymentSucceeded" -> {
                    PaymentSucceededPayload payload = objectMapper.convertValue(
                        event.getPayload(), PaymentSucceededPayload.class);
                    orderService.handlePaymentSucceeded(payload.getOrderId());
                }
                case "PaymentFailed" -> {
                    FailurePayload payload = objectMapper.convertValue(
                        event.getPayload(), FailurePayload.class);
                    orderService.handleSagaFailed(payload.getOrderId(), payload.getReason());
                }
            }
            
            // mark as processed
            ProcessedEvent processedEvent = ProcessedEvent.builder()
                .eventId(event.getEventId())
                .eventType(event.getEventType())
                .build();
            processedEventRepository.save(processedEvent);
            
            ack.acknowledge();
            log.info("processed event: {}", event.getEventId());
        } catch (Exception e) {
            log.error("failed to process event: {}", event.getEventId(), e);
            // do not acknowledge - will be retried
        }
    }
    
    @KafkaListener(topics = "shipping-events", groupId = "order-service-group")
    @Transactional
    public void consumeShippingEvents(BaseEvent event, Acknowledgment ack) {
        log.info("received shipping event: {} type: {}", event.getEventId(), event.getEventType());
        
        // check idempotency
        if (processedEventRepository.existsById(event.getEventId())) {
            log.info("event already processed: {}", event.getEventId());
            ack.acknowledge();
            return;
        }
        
        try {
            if ("ShippingInitiated".equals(event.getEventType())) {
                String orderId = event.getSagaId();
                orderService.handleSagaCompleted(orderId);
            }
            
            // mark as processed
            ProcessedEvent processedEvent = ProcessedEvent.builder()
                .eventId(event.getEventId())
                .eventType(event.getEventType())
                .build();
            processedEventRepository.save(processedEvent);
            
            ack.acknowledge();
            log.info("processed event: {}", event.getEventId());
        } catch (Exception e) {
            log.error("failed to process event: {}", event.getEventId(), e);
            // do not acknowledge - will be retried
        }
    }
}
