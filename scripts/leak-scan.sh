#!/usr/bin/env bash
# leak-scan.sh — deny-list scanner for public-repo hygiene.
#
# Blocks project-specific leak classes that generic secret scanners (gitleaks,
# semgrep) do not catch, because these are not secrets — they are internal
# topology and identity-linking data the public pattern repo must never carry
# (see CLAUDE.md guardrails and the platform SPEC's leak controls):
#
#   - internal RFC1918 IP addresses
#   - VLAN numbers (network topology)
#   - reference hardware SKUs
#   - private planning/overlay repo slugs
#   - known identity handles
#   - MAC addresses
#
# Scope: the working tree, not git history (gitleaks already scans history for
# secrets). With filename arguments (as pre-commit passes) it scans only those;
# with none, it scans every tracked file.
#
# False positives: append the marker `leak-scan:allow` to the offending line.
# This script self-excludes so its own pattern definitions never match.
set -euo pipefail

SELF="scripts/leak-scan.sh"

# name<TAB>extended-regex — keep names kebab-case, one class per line.
RULES=$(cat <<'EOF'
rfc1918-ip	\b(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})\b
vlan-number	\bVLAN[ _-]?[0-9]{1,4}\b
hardware-sku	\b(R650|SG-1100|iDRAC|Netgate|PowerEdge)\b
private-repo-slug	homelab_(planning|overlay)
identity-handle	\bk7rmg\b
mac-address	\b([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b
EOF
)

# Build the file list: explicit args (pre-commit) or all tracked files.
if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  FILES=()
  while IFS= read -r f; do FILES+=("$f"); done < <(git ls-files)
fi

status=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  [ "$f" = "$SELF" ] && continue
  # Skip binary files (grep -I prints nothing and returns non-zero for binary).
  grep -Iq . "$f" 2>/dev/null || continue
  while IFS=$'\t' read -r name regex; do
    [ -z "$name" ] && continue
    while IFS= read -r hit; do
      case "$hit" in *leak-scan:allow*) continue ;; esac
      printf 'LEAK[%s] %s:%s\n' "$name" "$f" "$hit"
      status=1
    done < <(grep -nE "$regex" "$f" 2>/dev/null || true)
  done <<< "$RULES"
done

if [ "$status" -ne 0 ]; then
  printf '\nDeny-list leak scan FAILED.\n'
  printf 'Remove the value, or append the marker "leak-scan:allow" to the line if it is a reviewed false positive.\n'
fi
exit "$status"
