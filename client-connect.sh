#!/bin/bash
# client-connect.sh - Aplica bloqueio por perfil

BASE="/etc/vps_protecao"
DIR_CAT="$BASE/categorias"
DIR_PERF="$BASE/perfis"
DIR_CLIENT="$BASE/clientes"
DNSMASQ_DIR="/etc/dnsmasq.d"
OUT_FILE="$DNSMASQ_DIR/vpn-${common_name}.conf"

CLIENT_IP="$ifconfig_pool_remote_ip"

PROFILE_FILE="$DIR_CLIENT/${common_name}.profile"
[ ! -f "$PROFILE_FILE" ] && exit 0

PERFIL=$(cat "$PROFILE_FILE")

echo "# Cliente: $common_name ($CLIENT_IP)" > "$OUT_FILE"
echo "# Perfil: $PERFIL" >> "$OUT_FILE"

# Para cada categoria associada ao perfil
while read -r CAT; do
    [ -z "$CAT" ] && continue
    CAT_FILE="$DIR_CAT/$CAT.list"
    [ ! -f "$CAT_FILE" ] && continue

    while read -r DOM; do
        [[ -z "$DOM" || "$DOM" =~ ^# ]] && continue
        echo "address=/$DOM/$CLIENT_IP" >> "$OUT_FILE"
    done < "$CAT_FILE"

done < "$DIR_PERF/$PERFIL.conf"

# Recarrega dnsmasq sem derrubar clientes
systemctl reload dnsmasq 2>/dev/null || systemctl restart dnsmasq

exit 0

