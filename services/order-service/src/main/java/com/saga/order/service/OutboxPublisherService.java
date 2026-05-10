package com.saga.order.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.saga.order.entity.OutboxEvent;
import com.saga.order.event.BaseEvent;
import com.saga.order.repository.OutboxEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class OutboxPublisherService {
    
    private final OutboxEventRepository outboxEventRepository;
    private final KafkaTemplate<String, BaseEvent> kafkaTemplate;
    private final ObjectMapper objectMapper;
    
    @Scheduled(fixedDelay = 5000)
    @Transactional
    public void publishEvents() {
        List<OutboxEvent> unpublishedEvents = outboxEventRepository.findTop10ByPublishedFalseOrderByTimestampAsc();
        
        if (unpublishedEvents.isEmpty()) {
            return;
        }
        
        log.info("publishing {} events from outbox", unpublishedEvents.size());
        
        for (OutboxEvent event : unpublishedEvents) {
            try {
                BaseEvent baseEvent = BaseEvent.builder()
                    .eventId(event.getEventId())
                    .sagaId(event.getSagaId())
                    .eventType(event.getEventType())
                    .producer(event.getProducer())
                    .timestamp(event.getTimestamp())
                    .payload(objectMapper.readValue(event.getPayload(), Object.class))
                    .build();
                
                kafkaTemplate.send("order-events", event.getSagaId(), baseEvent);
                
                event.setPublished(true);
                event.setPublishedAt(LocalDateTime.now());
                outboxEventRepository.save(event);
                
                log.info("published event: {} for saga: {}", event.getEventId(), event.getSagaId());
            } catch (Exception e) {
                log.error("failed to publish event: {}", event.getEventId(), e);
            }
        }
    }
}
