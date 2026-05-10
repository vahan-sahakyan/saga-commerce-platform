package com.saga.order.event;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrderCreatedPayload {
    private String orderId;
    private String customerId;
    private List<OrderItemPayload> items;
    private BigDecimal totalAmount;
}
