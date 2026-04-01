#!/usr/bin/env bash
set -euo pipefail

BASE_FILE="docker-compose.yml"
TEST_FILE="compose.test.yaml"

if [[ ! -f "$BASE_FILE" ]]; then
  echo "ERROR: $BASE_FILE not found"
  exit 1
fi
if [[ ! -f "$TEST_FILE" ]]; then
  echo "ERROR: $TEST_FILE not found"
  exit 1
fi

failures=0

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    failures=$((failures + 1))
  fi
}

service_has() {
  local service_name="$1"
  local pattern="$2"
  local file="$3"

  awk -v svc="$service_name" '
    $0 ~ "^  " svc ":$" { in_service=1; next }
    in_service && $0 ~ "^  [A-Za-z0-9_.-]+:$" { in_service=0 }
    in_service { print }
  ' "$file" | grep -Eq "$pattern"
}

check "TODO 1 depends_on uses service_healthy" "grep -Eq 'condition:\s*service_healthy' '$BASE_FILE'"
check "TODO 2 db uses secret-based password" "! service_has db 'POSTGRES_PASSWORD:\\s*insecure_password' '$BASE_FILE' && service_has db 'POSTGRES_PASSWORD_FILE:\\s*/run/secrets/db_password' '$BASE_FILE' && service_has db '^\\s*secrets:' '$BASE_FILE' && service_has db 'db_password' '$BASE_FILE'"
check "TODO 3 db healthcheck exists" "grep -Eq '^\s*healthcheck:' '$BASE_FILE' && grep -Eq 'pg_isready\s+-U\s+app' '$BASE_FILE'"
check "TODO 4 named volume mount used for db" "grep -Eq 'postgres_data:/var/lib/postgresql/data' '$BASE_FILE'"
check "TODO 5 frontend profile set" "service_has frontend 'profiles:.*frontend|profiles:\\s*\\[.*frontend.*\\]' '$BASE_FILE'"
check "TODO 6 debug profile set" "service_has phpmyadmin 'profiles:.*debug|profiles:\\s*\\[.*debug.*\\]' '$BASE_FILE'"
check "TODO 7 private network is internal" "awk '/private:/{f=1} f&&/internal:/{print; exit}' '$BASE_FILE' | grep -Eq 'true'"
check "TODO 8 secret db_password defined" "grep -Eq '^\s*secrets:' '$BASE_FILE' && grep -Eq '^\s*db_password:' '$BASE_FILE' && grep -Eq 'file:\s*\./secrets/db_password.txt' '$BASE_FILE'"
check "TODO 9 named volume postgres_data defined" "grep -Eq '^\s*volumes:' '$BASE_FILE' && grep -Eq '^\s*postgres_data:' '$BASE_FILE'"
check "TODO 10 test override changes backend command" "grep -Eq '^\s*command:' '$TEST_FILE' && ! grep -Eq 'echo app mode' '$TEST_FILE'"
check "TODO 11 test override uses tmpfs" "grep -Eq '^\s*tmpfs:' '$TEST_FILE' && grep -Eq '/var/lib/postgresql/data' '$TEST_FILE' && ! grep -Eq 'tmp-db-test:/var/lib/postgresql/data' '$TEST_FILE'"

if [[ "$failures" -eq 0 ]]; then
  echo
  echo "All checks passed. Great job!"
  exit 0
fi

echo
echo "$failures check(s) failed. Fix TODOs and run again."
exit 1
