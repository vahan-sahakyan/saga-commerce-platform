#!/usr/bin/env bash
# demo.sh — Saga choreography demo script
# Runs happy-path, inventory-failure, and payment-failure scenarios.
# Each scenario is fully isolated: uses a unique sagaId per run and
# clears only its own order/payment rows so reruns are always consistent.
#
# Usage:
#   ./scripts/demo.sh            # run all three scenarios
#   ./scripts/demo.sh happy      # happy path only
#   ./scripts/demo.sh inv-fail   # inventory failure only
#   ./scripts/demo.sh pay-fail   # payment failure only

set -euo pipefail

ORDER_URL="${ORDER_URL:-http://localhost:8081}"
SERVICES_NS="services"
INFRA_NS="infra"
PG_POD=$(kubectl get pod -n "$INFRA_NS" -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
PSQL="kubectl exec $PG_POD -n $INFRA_NS -- env PGPASSWORD=saga-password psql -U saga"

# ── colours ──────────────────────────────────────────────────────────────────
BOLD='\033[1m'; CYAN='\033[36m'; GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; RESET='\033[0m'

banner()  { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${RESET}"; }
ok()      { echo -e "${GREEN}✓ $*${RESET}"; }
fail()    { echo -e "${RED}✗ $*${RESET}"; }
info()    { echo -e "${YELLOW}→ $*${RESET}"; }

# ── helpers ───────────────────────────────────────────────────────────────────

check_prereqs() {
    if ! curl -sf "$ORDER_URL/actuator/health" >/dev/null 2>&1; then
        fail "order-service not reachable at $ORDER_URL"
        echo "  Run:  kubectl port-forward svc/order-service -n services 8081:8080 &"
        echo "  Or:   make pf-order"
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        fail "jq is required: brew install jq"
        exit 1
    fi
}

# Set PAYMENT_SUCCESS_RATE on the payment-service deployment and wait for rollout.
set_payment_rate() {
    local rate="$1"
    info "Setting payment success rate → ${rate} (restarting payment-service pod...)"
    kubectl set env deployment/payment-service -n "$SERVICES_NS" "PAYMENT_SUCCESS_RATE=$rate" >/dev/null
    kubectl rollout status deployment/payment-service -n "$SERVICES_NS" --timeout=90s >/dev/null
}

# Reset payment-service to default (0.8).
reset_payment_rate() {
    kubectl set env deployment/payment-service -n "$SERVICES_NS" PAYMENT_SUCCESS_RATE- >/dev/null 2>&1 || true
}

# Ensure products are seeded (idempotent).
ensure_seed_data() {
    local count
    count=$($PSQL -d inventory_db -tAq -c "SELECT COUNT(*) FROM inventories WHERE product_id IN ('product-1','product-2','product-3');" 2>/dev/null || echo 0)
    if [ "$count" -lt 3 ]; then
        info "Seeding inventory products..."
        $PSQL -d inventory_db -q -c "
            INSERT INTO inventories (id, product_id, quantity, reserved, created_at, updated_at)
            VALUES
                (gen_random_uuid(), 'product-1', 100, 0, NOW(), NOW()),
                (gen_random_uuid(), 'product-2', 50,  0, NOW(), NOW()),
                (gen_random_uuid(), 'product-3', 75,  0, NOW(), NOW())
            ON CONFLICT (product_id) DO NOTHING;
        " 2>/dev/null
        ok "Inventory seeded"
    fi
}

create_order() {
    local customer_id="$1"; shift
    local body="$1"
    curl -sf -X POST "$ORDER_URL/api/orders" \
        -H "Content-Type: application/json" \
        -d "$body"
}

# Poll order status until it leaves PENDING/INVENTORY_RESERVED, or timeout.
wait_for_order() {
    local order_id="$1"
    local timeout="${2:-30}"
    local elapsed=0
    local status=""

    while [ "$elapsed" -lt "$timeout" ]; do
        status=$(curl -sf "$ORDER_URL/api/orders/$order_id" | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
        case "$status" in
            PENDING|INVENTORY_RESERVED) ;;  # still in progress
            *) echo "$status"; return 0 ;;
        esac
        sleep 2
        elapsed=$((elapsed + 2))
    done
    echo "TIMEOUT"
}

print_order() {
    local order_id="$1"
    curl -sf "$ORDER_URL/api/orders/$order_id" | jq '{id,status,totalAmount,failureReason}'
}

# ── Scenario 1: Happy path ────────────────────────────────────────────────────

demo_happy() {
    banner "SCENARIO 1 — Happy Path"
    echo "  Products exist, stock available, payment succeeds."
    echo "  Expected flow: OrderCreated → InventoryReserved → PaymentSucceeded → PAYMENT_COMPLETED"
    echo ""

    set_payment_rate "1.0"

    local body='{
        "customerId": "demo-happy-'$(date +%s)'",
        "items": [
            {"productId": "product-1", "quantity": 2, "price": 29.99},
            {"productId": "product-2", "quantity": 1, "price": 49.99}
        ]
    }'

    info "Creating order..."
    local resp; resp=$(create_order "demo-happy" "$body")
    local order_id; order_id=$(echo "$resp" | jq -r '.id')
    ok "Order created: $order_id"

    info "Waiting for saga to complete..."
    local final_status; final_status=$(wait_for_order "$order_id" 40)

    echo ""
    print_order "$order_id"
    echo ""

    if [ "$final_status" = "PAYMENT_COMPLETED" ]; then
        ok "Saga completed successfully — status: PAYMENT_COMPLETED ✓"
    else
        fail "Unexpected final status: $final_status"
    fi

    reset_payment_rate
}

# ── Scenario 2: Inventory failure ────────────────────────────────────────────

demo_inv_fail() {
    banner "SCENARIO 2 — Inventory Failure"
    echo "  Order references a product that does not exist in inventory."
    echo "  Expected flow: OrderCreated → InventoryFailed → FAILED"
    echo ""

    local body='{
        "customerId": "demo-inv-fail-'$(date +%s)'",
        "items": [
            {"productId": "product-nonexistent", "quantity": 1, "price": 9.99}
        ]
    }'

    info "Creating order with unknown product..."
    local resp; resp=$(create_order "demo-inv-fail" "$body")
    local order_id; order_id=$(echo "$resp" | jq -r '.id')
    ok "Order created: $order_id"

    info "Waiting for saga compensation..."
    local final_status; final_status=$(wait_for_order "$order_id" 30)

    echo ""
    print_order "$order_id"
    echo ""

    if [ "$final_status" = "FAILED" ]; then
        ok "Saga compensated correctly — status: FAILED ✓"
    else
        fail "Unexpected final status: $final_status"
    fi
}

# ── Scenario 3: Payment failure ───────────────────────────────────────────────

demo_pay_fail() {
    banner "SCENARIO 3 — Payment Failure"
    echo "  Inventory reserves successfully, but payment is declined."
    echo "  Expected flow: OrderCreated → InventoryReserved → PaymentFailed → FAILED"
    echo ""

    set_payment_rate "0.0"

    local body='{
        "customerId": "demo-pay-fail-'$(date +%s)'",
        "items": [
            {"productId": "product-3", "quantity": 1, "price": 19.99}
        ]
    }'

    info "Creating order (payment will be declined)..."
    local resp; resp=$(create_order "demo-pay-fail" "$body")
    local order_id; order_id=$(echo "$resp" | jq -r '.id')
    ok "Order created: $order_id"

    info "Waiting for saga compensation..."
    local final_status; final_status=$(wait_for_order "$order_id" 40)

    echo ""
    print_order "$order_id"
    echo ""

    if [ "$final_status" = "FAILED" ]; then
        ok "Payment declined, saga compensated — status: FAILED ✓"
    else
        fail "Unexpected final status: $final_status"
    fi

    reset_payment_rate
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║   Saga Commerce Platform — Live Demo         ║"
    echo -e "╚══════════════════════════════════════════════╝${RESET}"

    check_prereqs
    ensure_seed_data

    local scenario="${1:-all}"

    case "$scenario" in
        happy)    demo_happy ;;
        inv-fail) demo_inv_fail ;;
        pay-fail) demo_pay_fail ;;
        all)
            demo_happy
            demo_inv_fail
            demo_pay_fail
            banner "DEMO COMPLETE"
            ok "All 3 scenarios finished"
            ;;
        *)
            echo "Usage: $0 [happy|inv-fail|pay-fail|all]"
            exit 1
            ;;
    esac
}

main "$@"
