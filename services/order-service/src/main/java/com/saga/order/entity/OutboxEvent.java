package com.saga.order.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "outbox_events")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OutboxEvent {
    
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;
    
    @Column(nullable = false)
    private String eventId;
    
    @Column(nullable = false)
    private String sagaId;
    
    @Column(nullable = false)
    private String eventType;
    
    @Column(nullable = false)
    private String producer;
    
    @Column(nullable = false, columnDefinition = "TEXT")
    private String payload;
    
    @Column(nullable = false)
    private LocalDateTime timestamp;
    
    @Column(nullable = false)
    private Boolean published;
    
    private LocalDateTime publishedAt;
    
    @PrePersist
    protected void onCreate() {
        timestamp = LocalDateTime.now();
        published = false;
    }
}
