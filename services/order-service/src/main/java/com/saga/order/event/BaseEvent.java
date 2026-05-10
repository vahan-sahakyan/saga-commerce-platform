package com.saga.order.event;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BaseEvent {
    private String eventId;
    private String sagaId;
    private String eventType;
    private String producer;
    private LocalDateTime timestamp;
    private Object payload;
}
