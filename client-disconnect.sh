#!/bin/bash
# client-disconnect.sh - Remove regras do cliente

DNSMASQ_FILE="/etc/dnsmasq.d/vpn-${common_name}.conf"

[ -f "$DNSMASQ_FILE" ] && rm -f "$DNSMASQ_FILE"

systemctl reload dnsmasq 2>/dev/null || systemctl restart dnsmasq

exit 0

