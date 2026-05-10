package com.saga.order.event;

import com.fasterxml.jackson.databind.JsonNode;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BaseEvent {
    private String eventId;
    private String sagaId;
    private String eventType;
    private String producer;
    private JsonNode timestamp;
    private Object payload;
}
