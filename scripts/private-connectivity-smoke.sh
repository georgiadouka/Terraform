#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 11 || "$#" -gt 14 ]]; then
  echo "Expected eleven service hostnames plus optional SQL Managed Instance, Cosmos DB, and NAT Gateway values, received $#." >&2
  exit 1
fi

SQL_HOST="$1"
POSTGRESQL_HOST="$2"
MYSQL_HOST="$3"
KEY_VAULT_HOST="$4"
STORAGE_BLOB_HOST="$5"
PREMIUM_FILES_HOST="$6"
FUNCTION_STORAGE_BLOB_HOST="$7"
FUNCTION_APP_HOST="$8"
WEB_APP_HOST="$9"
CONTAINER_REGISTRY_HOST="${10}"
CONTAINER_APP_HOST="${11}"
SQL_MANAGED_INSTANCE_HOST="${12:-}"
COSMOS_DB_HOST="${13:-}"
NAT_GATEWAY_PUBLIC_IP="${14:-}"

check_private_dns() {
  local host="$1"
  local ip

  ip="$(getent ahostsv4 "$host" | head -n 1 | tr -s " " | cut -d" " -f1)"
  if [[ "$ip" != 10.* ]]; then
    echo "FAIL ${host} -> ${ip:-unresolved}" >&2
    exit 1
  fi

  echo "PASS ${host} -> ${ip}"
}

check_private_dns "$SQL_HOST"
check_private_dns "$POSTGRESQL_HOST"
check_private_dns "$MYSQL_HOST"
check_private_dns "$KEY_VAULT_HOST"
check_private_dns "$STORAGE_BLOB_HOST"
check_private_dns "$PREMIUM_FILES_HOST"
check_private_dns "$FUNCTION_STORAGE_BLOB_HOST"
check_private_dns "$FUNCTION_APP_HOST"
check_private_dns "$WEB_APP_HOST"
check_private_dns "$CONTAINER_REGISTRY_HOST"
check_private_dns "$CONTAINER_APP_HOST"
if [[ -n "$SQL_MANAGED_INSTANCE_HOST" ]]; then
  check_private_dns "$SQL_MANAGED_INSTANCE_HOST"
fi
if [[ -n "$COSMOS_DB_HOST" ]]; then
  check_private_dns "$COSMOS_DB_HOST"
fi
if [[ -n "$NAT_GATEWAY_PUBLIC_IP" ]]; then
  observed_egress_ip="$(curl -fsS --max-time 30 https://api.ipify.org)"
  if [[ "$observed_egress_ip" != "$NAT_GATEWAY_PUBLIC_IP" ]]; then
    echo "FAIL outbound IP ${observed_egress_ip:-unavailable}; expected ${NAT_GATEWAY_PUBLIC_IP}" >&2
    exit 1
  fi
  echo "PASS outbound IP ${observed_egress_ip}"
fi

web_app_status="$(curl -k -sS -o /dev/null -w "%{http_code}" --max-time 30 "https://${WEB_APP_HOST}/")"
echo "Web App HTTPS status: ${web_app_status}"
test "$web_app_status" = "200"

container_app_status="$(curl -k -sS -o /dev/null -w "%{http_code}" --max-time 30 "https://${CONTAINER_APP_HOST}/")"
echo "Container App HTTPS status: ${container_app_status}"
test "$container_app_status" = "200"
