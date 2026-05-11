package com.saga.order.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.saga.order.dto.CreateOrderRequest;
import com.saga.order.dto.OrderItemDto;
import com.saga.order.dto.OrderResponse;
import com.saga.order.entity.Order;
import com.saga.order.entity.OrderItem;
import com.saga.order.entity.OrderStatus;
import com.saga.order.entity.OutboxEvent;
import com.saga.order.event.OrderCreatedPayload;
import com.saga.order.event.OrderItemPayload;
import com.saga.order.repository.OrderRepository;
import com.saga.order.repository.OutboxEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {
    
    private final OrderRepository orderRepository;
    private final OutboxEventRepository outboxEventRepository;
    private final ObjectMapper objectMapper;
    
    @Transactional
    public OrderResponse createOrder(CreateOrderRequest request) {
        log.info("creating order for customer: {}", request.getCustomerId());

        // static product price map (in real app, fetch from product service)
        java.util.Map<String, BigDecimal> productPrices = java.util.Map.of(
            "product-1", new BigDecimal("29.99"),
            "product-2", new BigDecimal("49.99")
        );

        // convert items and calculate total
        List<OrderItem> orderItems = request.getItems().stream()
            .map(dto -> {
                BigDecimal price = productPrices.getOrDefault(dto.getProductId(), BigDecimal.ZERO);
                return OrderItem.builder()
                    .productId(dto.getProductId())
                    .quantity(dto.getQuantity())
                    .price(price)
                    .build();
            })
            .collect(Collectors.toList());

        BigDecimal total = orderItems.stream()
            .map(item -> item.getPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
            .reduce(BigDecimal.ZERO, BigDecimal::add);

        // create order
        Order order = Order.builder()
            .customerId(request.getCustomerId())
            .status(OrderStatus.PENDING)
            .totalAmount(total)
            .items(orderItems)
            .build();
        
        order = orderRepository.save(order);
        log.info("order created with id: {}", order.getId());
        
        // create outbox event
        createOrderCreatedEvent(order);
        
        return toResponse(order);
    }
    
    @Transactional
    public void handleInventoryReserved(String orderId) {
        log.info("handling inventory reserved for order: {}", orderId);
        orderRepository.findById(orderId).ifPresent(order -> {
            order.setStatus(OrderStatus.INVENTORY_RESERVED);
            orderRepository.save(order);
        });
    }
    
    @Transactional
    public void handlePaymentSucceeded(String orderId) {
        log.info("handling payment succeeded for order: {}", orderId);
        orderRepository.findById(orderId).ifPresent(order -> {
            order.setStatus(OrderStatus.PAYMENT_COMPLETED);
            orderRepository.save(order);
        });
    }
    
    @Transactional
    public void handleSagaCompleted(String orderId) {
        log.info("handling saga completed for order: {}", orderId);
        orderRepository.findById(orderId).ifPresent(order -> {
            order.setStatus(OrderStatus.COMPLETED);
            orderRepository.save(order);
        });
    }
    
    @Transactional
    public void handleSagaFailed(String orderId, String reason) {
        log.info("handling saga failed for order: {}, reason: {}", orderId, reason);
        orderRepository.findById(orderId).ifPresent(order -> {
            order.setStatus(OrderStatus.FAILED);
            order.setFailureReason(reason);
            orderRepository.save(order);
        });
    }
    
    public OrderResponse getOrder(String id) {
        return orderRepository.findById(id)
            .map(this::toResponse)
            .orElseThrow(() -> new RuntimeException("order not found: " + id));
    }
    
    public List<OrderResponse> getAllOrders() {
        return orderRepository.findAll().stream()
            .map(this::toResponse)
            .collect(Collectors.toList());
    }
    
    private void createOrderCreatedEvent(Order order) {
        try {
            String eventId = UUID.randomUUID().toString();
            
            OrderCreatedPayload payload = OrderCreatedPayload.builder()
                .orderId(order.getId())
                .customerId(order.getCustomerId())
                .totalAmount(order.getTotalAmount())
                .items(order.getItems().stream()
                    .map(item -> OrderItemPayload.builder()
                        .productId(item.getProductId())
                        .quantity(item.getQuantity())
                        .price(item.getPrice())
                        .build())
                    .collect(Collectors.toList()))
                .build();
            
            OutboxEvent event = OutboxEvent.builder()
                .eventId(eventId)
                .sagaId(order.getId())
                .eventType("OrderCreated")
                .producer("order-service")
                .payload(objectMapper.writeValueAsString(payload))
                .build();
            
            outboxEventRepository.save(event);
            log.info("outbox event created: {}", eventId);
        } catch (JsonProcessingException e) {
            log.error("failed to create outbox event", e);
            throw new RuntimeException("failed to create event", e);
        }
    }
    
    private OrderResponse toResponse(Order order) {
        return OrderResponse.builder()
            .id(order.getId())
            .customerId(order.getCustomerId())
            .status(order.getStatus())
            .totalAmount(order.getTotalAmount())
            .items(order.getItems().stream()
                .map(item -> OrderItemDto.builder()
                    .productId(item.getProductId())
                    .quantity(item.getQuantity())
                    .build())
                .collect(Collectors.toList()))
            .createdAt(order.getCreatedAt())
            .updatedAt(order.getUpdatedAt())
            .failureReason(order.getFailureReason())
            .build();
    }
}
