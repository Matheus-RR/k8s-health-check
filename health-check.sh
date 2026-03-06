#!/bin/bash
# k8s-health-check.sh - Quick cluster health overview
# Usage: ./health-check.sh [--json]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

JSON_OUTPUT=false
[[ "${1:-}" == "--json" ]] && JSON_OUTPUT=true

echo "=== K8s Health Check ==="
echo ""

# Node status
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready' || true)

if [[ "$READY_NODES" -eq "$TOTAL_NODES" ]]; then
    echo -e "Nodes:           ${GREEN}${READY_NODES}/${TOTAL_NODES} Ready${NC}"
else
    echo -e "Nodes:           ${RED}${READY_NODES}/${TOTAL_NODES} Ready${NC}"
    kubectl get nodes --no-headers | grep -v ' Ready' | awk '{print "  WARNING: " $1 " is " $2}'
fi

# Check for resource pressure
PRESSURE=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.conditions[] | select(.type | test("Pressure")) | .status == "True") | .metadata.name' 2>/dev/null)
if [[ -n "$PRESSURE" ]]; then
    echo -e "Pressure:        ${RED}Detected${NC}"
    echo "$PRESSURE" | while read node; do
        echo "  WARNING: $node has resource pressure"
    done
else
    echo -e "Pressure:        ${GREEN}None${NC}"
fi

# Pod issues
CRASHLOOP=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -c 'CrashLoopBackOff' || true)
PENDING=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -c 'Pending' || true)
ISSUES=$((CRASHLOOP + PENDING))

if [[ "$ISSUES" -eq 0 ]]; then
    echo -e "Pod Issues:      ${GREEN}None${NC}"
else
    echo -e "Pod Issues:      ${YELLOW}${ISSUES} (${CRASHLOOP} CrashLoopBackOff, ${PENDING} Pending)${NC}"
fi

# High restart counts (>10)
HIGH_RESTARTS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | awk '{split($5,a,/[[:space:]]/); if (a[1]+0 > 10) print $1"/"$2": "$5" restarts"}')
if [[ -n "$HIGH_RESTARTS" ]]; then
    echo -e "High Restarts:   ${YELLOW}Found${NC}"
    echo "$HIGH_RESTARTS" | head -5 | while read line; do echo "  $line"; done
fi

# Unbound PVCs
UNBOUND=$(kubectl get pvc --all-namespaces --no-headers 2>/dev/null | grep -cv 'Bound' || true)
if [[ "$UNBOUND" -eq 0 ]]; then
    echo -e "Unbound PVCs:    ${GREEN}0${NC}"
else
    echo -e "Unbound PVCs:    ${RED}${UNBOUND}${NC}"
fi

# Unavailable deployments
UNAVAIL=$(kubectl get deployments --all-namespaces --no-headers 2>/dev/null | awk '$3+0 < $2+0 {print $1"/"$2}' | wc -l | tr -d ' ')
if [[ "$UNAVAIL" -eq 0 ]]; then
    echo -e "Unavailable:     ${GREEN}All deployments healthy${NC}"
else
    echo -e "Unavailable:     ${RED}${UNAVAIL} deployment(s)${NC}"
fi

echo ""
echo "Checked at $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
