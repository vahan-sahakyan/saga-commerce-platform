#!/bin/bash

# test the saga flow by creating an order

ORDER_SERVICE_URL="http://localhost:8080"

echo "🧪 Testing Saga Flow..."
echo ""

# create order
echo "📝 Creating order..."
RESPONSE=$(curl -s -X POST ${ORDER_SERVICE_URL}/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-123",
    "items": [
      {
        "productId": "product-1",
        "quantity": 2
      },
      {
        "productId": "product-2",
        "quantity": 1
      }
    ]
  }')

ORDER_ID=$(echo $RESPONSE | jq -r '.id')

if [ "$ORDER_ID" == "null" ] || [ -z "$ORDER_ID" ]; then
    echo "❌ Failed to create order"
    echo $RESPONSE
    exit 1
fi

echo "✅ Order created: $ORDER_ID"
echo ""

# wait for saga to complete
echo "⏳ Waiting for saga to complete (this may take 15-20 seconds)..."
sleep 20

# check order status
echo ""
echo "📊 Checking order status..."
curl -s ${ORDER_SERVICE_URL}/api/orders/${ORDER_ID} | jq '.'

echo ""
echo "🎉 Test complete!"
echo ""
echo "To view logs:"
echo "  Order Service:        kubectl logs -l app=order-service -n services --tail=50"
echo "  Inventory Service:    kubectl logs -l app=inventory-service -n services --tail=50"
echo "  Payment Service:      kubectl logs -l app=payment-service -n services --tail=50"
echo "  Notification Service: kubectl logs -l app=notification-service -n services --tail=50"
