#!/usr/bin/env bash
set -Eeuo pipefail

# Idempotently route the demo Keycloak and mock frontend hostnames through the
# existing public ALB to Caddy on the current Keycloak demo EC2 instance.
# Default mode is a read-only preview. Pass --apply to change AWS resources.

readonly EXPECTED_ACCOUNT_ID="982081049921"
AWS_REGION="${AWS_REGION:-eu-central-1}"
DNS_ZONE_NAME="${DNS_ZONE_NAME:-solutions.adorsys.com}"
ALB_NAME="${ALB_NAME:-keycloak-demo-migration}"
SOURCE_TARGET_GROUP_NAME="${SOURCE_TARGET_GROUP_NAME:-keycloak-demo-targets}"
CADDY_TARGET_GROUP_NAME="${CADDY_TARGET_GROUP_NAME:-keycloak-demo-caddy}"
CADDY_PORT="${CADDY_PORT:-8081}"
KEYCLOAK_HOST="${KEYCLOAK_HOST:-keycloak-demo-env.solutions.adorsys.com}"
MOCK_FE_HOST="${MOCK_FE_HOST:-issuer-mock-fe.solutions.adorsys.com}"
APPLY=false

usage() {
  cat <<'EOF'
Usage: configure-demo-alb.sh [--apply]

Without --apply, performs read-only discovery and prints the changes that
would be made. With --apply, it creates the Caddy target group, registers the
existing demo EC2 instance on port 8081, adds ALB-only ingress for that port,
adds HTTPS host-header rules, and creates Route 53 A aliases.

Optional environment overrides: AWS_PROFILE, AWS_REGION, DNS_ZONE_NAME,
ALB_NAME, SOURCE_TARGET_GROUP_NAME, CADDY_TARGET_GROUP_NAME, CADDY_PORT,
KEYCLOAK_HOST, MOCK_FE_HOST.
EOF
}

while (($#)); do
  case "$1" in
    --apply) APPLY=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unexpected argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

fail() { echo "[ERROR] $*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }
require_command aws
require_command jq
[[ "$CADDY_PORT" =~ ^[0-9]+$ ]] && ((CADDY_PORT > 0 && CADDY_PORT < 65536)) || fail "CADDY_PORT must be a valid TCP port."
for host in "$KEYCLOAK_HOST" "$MOCK_FE_HOST"; do
  [[ "$host" == *.solutions.adorsys.com ]] || fail "Hostname $host must be under solutions.adorsys.com."
done

AWS_ARGS=(--region "$AWS_REGION")
if [[ -n "${AWS_PROFILE:-}" ]]; then
  AWS_ARGS+=(--profile "$AWS_PROFILE")
fi
aws_demo() { aws "${AWS_ARGS[@]}" "$@"; }

ACCOUNT_ID="$(aws_demo sts get-caller-identity --query Account --output text)"
[[ "$ACCOUNT_ID" == "$EXPECTED_ACCOUNT_ID" ]] || fail \
  "AWS account is $ACCOUNT_ID, expected $EXPECTED_ACCOUNT_ID. Select the intended profile/account."

ALB_JSON="$(aws_demo elbv2 describe-load-balancers --names "$ALB_NAME")"
[[ "$(jq '.LoadBalancers | length' <<<"$ALB_JSON")" == 1 ]] || fail "Expected exactly one ALB named $ALB_NAME."
ALB="$(jq -c '.LoadBalancers[0]' <<<"$ALB_JSON")"
ALB_ARN="$(jq -r '.LoadBalancerArn' <<<"$ALB")"
ALB_DNS="$(jq -r '.DNSName' <<<"$ALB")"
ALB_ZONE_ID="$(jq -r '.CanonicalHostedZoneId' <<<"$ALB")"
ALB_VPC_ID="$(jq -r '.VpcId' <<<"$ALB")"
ALB_STATE="$(jq -r '.State.Code' <<<"$ALB")"
[[ "$ALB_STATE" == active ]] || fail "ALB $ALB_NAME is not active (state: $ALB_STATE)."
[[ "$(jq '.SecurityGroups | length' <<<"$ALB")" == 1 ]] || fail "Expected exactly one security group attached to $ALB_NAME."
ALB_SG="$(jq -r '.SecurityGroups[0]' <<<"$ALB")"

LISTENER_JSON="$(aws_demo elbv2 describe-listeners --load-balancer-arn "$ALB_ARN")"
[[ "$(jq '[.Listeners[] | select(.Port == 443 and .Protocol == "HTTPS")] | length' <<<"$LISTENER_JSON")" == 1 ]] || \
  fail "Expected exactly one HTTPS listener on port 443 for $ALB_NAME."
LISTENER="$(jq -c '[.Listeners[] | select(.Port == 443 and .Protocol == "HTTPS")][0]' <<<"$LISTENER_JSON")"
LISTENER_ARN="$(jq -r '.ListenerArn' <<<"$LISTENER")"
CERT_ARN="$(jq -r '.Certificates[0].CertificateArn // empty' <<<"$LISTENER")"
[[ -n "$CERT_ARN" ]] || fail "HTTPS listener has no certificate."
CERT_JSON="$(aws_demo acm describe-certificate --certificate-arn "$CERT_ARN")"
CERT_STATUS="$(jq -r '.Certificate.Status' <<<"$CERT_JSON")"
[[ "$CERT_STATUS" == ISSUED ]] || fail "Listener certificate is not ISSUED (status: $CERT_STATUS)."
for host in "$KEYCLOAK_HOST" "$MOCK_FE_HOST"; do
  jq -e --arg host "$host" \
    '([.Certificate.SubjectAlternativeNames[]?] | any(. == $host or . == "*.solutions.adorsys.com"))' \
    <<<"$CERT_JSON" >/dev/null || fail "The ALB certificate does not cover $host."
done

ZONE_JSON="$(aws_demo route53 list-hosted-zones-by-name --dns-name "$DNS_ZONE_NAME")"
ZONE_MATCHES="$(jq -c --arg zone "$DNS_ZONE_NAME." \
  '[.HostedZones[] | select(.Name == $zone and .Config.PrivateZone == false)]' <<<"$ZONE_JSON")"
[[ "$(jq 'length' <<<"$ZONE_MATCHES")" == 1 ]] || fail "Expected one public Route 53 zone named $DNS_ZONE_NAME."
ZONE_ID="$(jq -r '.[0].Id | sub("^/hostedzone/"; "")' <<<"$ZONE_MATCHES")"

SOURCE_TG_JSON="$(aws_demo elbv2 describe-target-groups --names "$SOURCE_TARGET_GROUP_NAME")"
[[ "$(jq '.TargetGroups | length' <<<"$SOURCE_TG_JSON")" == 1 ]] || fail "Expected one source target group named $SOURCE_TARGET_GROUP_NAME."
SOURCE_TG_ARN="$(jq -r '.TargetGroups[0].TargetGroupArn' <<<"$SOURCE_TG_JSON")"
SOURCE_TG_VPC="$(jq -r '.TargetGroups[0].VpcId' <<<"$SOURCE_TG_JSON")"
[[ "$SOURCE_TG_VPC" == "$ALB_VPC_ID" ]] || fail "Source target group and ALB are in different VPCs."
SOURCE_TARGETS="$(aws_demo elbv2 describe-target-health --target-group-arn "$SOURCE_TG_ARN")"
[[ "$(jq '.TargetHealthDescriptions | length' <<<"$SOURCE_TARGETS")" == 1 ]] || \
  fail "Expected exactly one registered EC2 instance in $SOURCE_TARGET_GROUP_NAME."
INSTANCE_ID="$(jq -r '.TargetHealthDescriptions[0].Target.Id' <<<"$SOURCE_TARGETS")"
INSTANCE_JSON="$(aws_demo ec2 describe-instances --instance-ids "$INSTANCE_ID")"
[[ "$(jq '.Reservations[].Instances | length' <<<"$INSTANCE_JSON")" == 1 ]] || fail "Could not resolve EC2 instance $INSTANCE_ID."
INSTANCE="$(jq -c '.Reservations[0].Instances[0]' <<<"$INSTANCE_JSON")"
[[ "$(jq -r '.State.Name' <<<"$INSTANCE")" == running ]] || fail "EC2 instance $INSTANCE_ID is not running."
[[ "$(jq -r '.VpcId' <<<"$INSTANCE")" == "$ALB_VPC_ID" ]] || fail "EC2 instance and ALB are in different VPCs."
[[ "$(jq '.SecurityGroups | length' <<<"$INSTANCE")" == 1 ]] || fail "Expected exactly one security group attached to EC2 instance $INSTANCE_ID."
INSTANCE_SG="$(jq -r '.SecurityGroups[0].GroupId' <<<"$INSTANCE")"

TG_LIST="$(aws_demo elbv2 describe-target-groups)"
TG_MATCHES="$(jq -c --arg name "$CADDY_TARGET_GROUP_NAME" '[.TargetGroups[] | select(.TargetGroupName == $name)]' <<<"$TG_LIST")"
[[ "$(jq 'length' <<<"$TG_MATCHES")" -le 1 ]] || fail "Multiple target groups named $CADDY_TARGET_GROUP_NAME found."
TG_ARN=""
if [[ "$(jq 'length' <<<"$TG_MATCHES")" == 1 ]]; then
  TG="$(jq -c '.[0]' <<<"$TG_MATCHES")"
  [[ "$(jq -r '.Protocol' <<<"$TG")" == HTTP ]] || fail "$CADDY_TARGET_GROUP_NAME exists with a non-HTTP protocol."
  [[ "$(jq -r '.Port' <<<"$TG")" == "$CADDY_PORT" ]] || fail "$CADDY_TARGET_GROUP_NAME exists on the wrong port."
  [[ "$(jq -r '.VpcId' <<<"$TG")" == "$ALB_VPC_ID" ]] || fail "$CADDY_TARGET_GROUP_NAME exists in the wrong VPC."
  [[ "$(jq -r '.TargetType' <<<"$TG")" == instance ]] || fail "$CADDY_TARGET_GROUP_NAME is not an instance target group."
  [[ "$(jq -r '.HealthCheckProtocol' <<<"$TG")" == HTTP ]] || fail "$CADDY_TARGET_GROUP_NAME has a non-HTTP health check."
  [[ "$(jq -r '.HealthCheckPath' <<<"$TG")" == /health ]] || fail "$CADDY_TARGET_GROUP_NAME has a health check path other than /health."
  [[ "$(jq -r '.HealthCheckPort' <<<"$TG")" == traffic-port ]] || fail "$CADDY_TARGET_GROUP_NAME health check is not using the target port."
  jq -e --arg alb "$ALB_ARN" '(.LoadBalancerArns | length == 0) or all(.LoadBalancerArns[]; . == $alb)' <<<"$TG" >/dev/null || \
    fail "$CADDY_TARGET_GROUP_NAME is associated with a different load balancer."
  TG_ARN="$(jq -r '.TargetGroupArn' <<<"$TG")"
fi

CADDY_TARGET_PRESENT=false
CADDY_TARGET_STATE=""
if [[ -n "$TG_ARN" ]]; then
  CADDY_TARGETS="$(aws_demo elbv2 describe-target-health --target-group-arn "$TG_ARN")"
  matching_targets="$(jq -c --arg id "$INSTANCE_ID" '[.TargetHealthDescriptions[] | select(.Target.Id == $id)]' <<<"$CADDY_TARGETS")"
  [[ "$(jq 'length' <<<"$matching_targets")" -le 1 ]] || fail "The EC2 instance has duplicate registrations in $CADDY_TARGET_GROUP_NAME."
  if [[ "$(jq 'length' <<<"$matching_targets")" == 1 ]]; then
    registered_port="$(jq -r '.[0].Target.Port' <<<"$matching_targets")"
    [[ "$registered_port" == "$CADDY_PORT" ]] || fail \
      "$INSTANCE_ID is already registered in $CADDY_TARGET_GROUP_NAME on port $registered_port, expected $CADDY_PORT."
    CADDY_TARGET_PRESENT=true
    CADDY_TARGET_STATE="$(jq -r '.[0].TargetHealth.State' <<<"$matching_targets")"
  fi
fi

SG_JSON="$(aws_demo ec2 describe-security-groups --group-ids "$INSTANCE_SG")"
SG_RULE_EXISTS="$(jq -r --arg source "$ALB_SG" --argjson port "$CADDY_PORT" \
  '[.SecurityGroups[0].IpPermissions[]? | select(.IpProtocol == "tcp" and .FromPort == $port and .ToPort == $port) | .UserIdGroupPairs[]?.GroupId | select(. == $source)] | length > 0' \
  <<<"$SG_JSON")"

RULES_JSON="$(aws_demo elbv2 describe-rules --listener-arn "$LISTENER_ARN")"
for host in "$KEYCLOAK_HOST" "$MOCK_FE_HOST"; do
  existing="$(jq -c --arg host "$host" \
    '[.Rules[] | select(.Priority != "default") | select(any(.Conditions[]?; .Field == "host-header" and any(.Values[]?; . == $host)))]' \
    <<<"$RULES_JSON")"
  [[ "$(jq 'length' <<<"$existing")" -le 1 ]] || fail "More than one listener rule matches $host."
  if [[ "$(jq 'length' <<<"$existing")" == 1 ]]; then
    [[ -n "$TG_ARN" ]] || fail "A listener rule already exists for $host but the Caddy target group does not. Inspect it before proceeding."
    ACTIONS="$(jq -c '.[0].Actions' <<<"$existing")"
    jq -e --arg tg "$TG_ARN" \
      'length == 1 and .[0].Type == "forward" and ((.[0].TargetGroupArn == $tg) or (.[0].ForwardConfig.TargetGroups | length == 1 and .[0].TargetGroupArn == $tg))' \
      <<<"$ACTIONS" >/dev/null || fail "An existing listener rule for $host routes elsewhere; refusing to replace it."
  fi
done

check_dns_record() {
  local host="$1" fqdn="${1}."
  local all records alias_dns alias_zone
  all="$(aws_demo route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" --start-record-name "$fqdn" --max-items 20)"
  records="$(jq -c --arg name "$fqdn" '[.ResourceRecordSets[]? | select(.Name == $name)]' <<<"$all")"
  case "$(jq 'length' <<<"$records")" in
    0) echo missing ;;
    1)
      [[ "$(jq -r '.[0].Type' <<<"$records")" == A ]] || fail "A non-A Route 53 record already exists for $host."
      alias_dns="$(jq -r '.[0].AliasTarget.DNSName // empty' <<<"$records" | sed -E 's/^dualstack\./ /; s/[.]$//' | xargs)"
      alias_zone="$(jq -r '.[0].AliasTarget.HostedZoneId // empty' <<<"$records")"
      [[ "$alias_dns" == "$ALB_DNS" && "$alias_zone" == "$ALB_ZONE_ID" ]] || \
        fail "An A record already exists for $host but does not alias to $ALB_NAME; refusing to overwrite it."
      echo present ;;
    *) fail "Multiple Route 53 records already exist for $host; inspect them before proceeding." ;;
  esac
}

echo "AWS account: $ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "ALB: $ALB_NAME ($ALB_DNS), listener HTTPS:443"
echo "Certificate: $CERT_ARN (ISSUED; covers both hostnames)"
echo "EC2 target: $INSTANCE_ID, security group $INSTANCE_SG"
echo "Caddy target: HTTP:$CADDY_PORT, health check GET /health"
echo "Route 53 zone: $DNS_ZONE_NAME ($ZONE_ID)"
echo "Host routing: $KEYCLOAK_HOST and $MOCK_FE_HOST -> $CADDY_TARGET_GROUP_NAME"
echo "Existing default ALB action will remain unchanged."

if [[ "$APPLY" != true ]]; then
  printf '\nPreview only. Planned changes:\n'
  if [[ -n "$TG_ARN" ]]; then
    echo "  Target group $CADDY_TARGET_GROUP_NAME is already available."
  else
    echo "  Create target group $CADDY_TARGET_GROUP_NAME (HTTP:$CADDY_PORT, health path /health)."
  fi
  if [[ "$CADDY_TARGET_PRESENT" == true ]]; then
    echo "  EC2 target $INSTANCE_ID:$CADDY_PORT is already registered (health: $CADDY_TARGET_STATE)."
  else
    echo "  Register $INSTANCE_ID:$CADDY_PORT in that target group."
  fi
  if [[ "$SG_RULE_EXISTS" == true ]]; then
    echo "  ALB-only ingress TCP:$CADDY_PORT is already available on $INSTANCE_SG."
  else
    echo "  Allow TCP:$CADDY_PORT to $INSTANCE_SG from ALB security group $ALB_SG."
  fi
  for host in "$KEYCLOAK_HOST" "$MOCK_FE_HOST"; do
    state="$(check_dns_record "$host")"
    [[ "$state" == present ]] || echo "  Create HTTPS listener host rule and Route 53 A alias for $host."
  done
  printf '\nNo AWS resources changed. Re-run with --apply to make these changes.\n'
  exit 0
fi

if [[ "$SG_RULE_EXISTS" != true ]]; then
  aws_demo ec2 authorize-security-group-ingress \
    --group-id "$INSTANCE_SG" --protocol tcp --port "$CADDY_PORT" --source-group "$ALB_SG" >/dev/null
  echo "Added ALB-only ingress TCP:$CADDY_PORT to $INSTANCE_SG."
else
  echo "ALB-only ingress TCP:$CADDY_PORT is already available on $INSTANCE_SG."
fi

if [[ -z "$TG_ARN" ]]; then
  TG_CREATE="$(aws_demo elbv2 create-target-group \
    --name "$CADDY_TARGET_GROUP_NAME" --protocol HTTP --port "$CADDY_PORT" \
    --vpc-id "$ALB_VPC_ID" --target-type instance \
    --health-check-protocol HTTP --health-check-port traffic-port \
    --health-check-path /health --matcher HttpCode=200)"
  TG_ARN="$(jq -r '.TargetGroups[0].TargetGroupArn' <<<"$TG_CREATE")"
  [[ -n "$TG_ARN" && "$TG_ARN" != null ]] || fail "AWS did not return the new target-group ARN."
  echo "Created target group $CADDY_TARGET_GROUP_NAME."
else
  echo "Target group $CADDY_TARGET_GROUP_NAME is already available."
fi

if [[ "$CADDY_TARGET_PRESENT" != true ]]; then
  aws_demo elbv2 register-targets --target-group-arn "$TG_ARN" --targets "Id=$INSTANCE_ID,Port=$CADDY_PORT"
  echo "Registered $INSTANCE_ID:$CADDY_PORT in $CADDY_TARGET_GROUP_NAME."
else
  echo "EC2 target $INSTANCE_ID:$CADDY_PORT is already registered (health: $CADDY_TARGET_STATE)."
fi

create_or_check_rule() {
  local host="$1" rules existing priority
  rules="$(aws_demo elbv2 describe-rules --listener-arn "$LISTENER_ARN")"
  existing="$(jq -c --arg host "$host" \
    '[.Rules[] | select(.Priority != "default") | select(any(.Conditions[]?; .Field == "host-header" and any(.Values[]?; . == $host)))]' \
    <<<"$rules")"
  if [[ "$(jq 'length' <<<"$existing")" == 1 ]]; then
    jq -e --arg tg "$TG_ARN" \
      '.[0].Actions | length == 1 and .[0].Type == "forward" and ((.[0].TargetGroupArn == $tg) or (.[0].ForwardConfig.TargetGroups | length == 1 and .[0].TargetGroupArn == $tg))' \
      <<<"$existing" >/dev/null || fail "Existing listener rule for $host routes elsewhere; refusing to replace it."
    echo "Listener rule for $host already targets Caddy."
    return
  fi
  priority=10
  while jq -e --arg p "$priority" '.Rules[] | select(.Priority == $p)' <<<"$rules" >/dev/null; do
    ((priority++))
    ((priority < 50000)) || fail "No available ALB listener-rule priority."
  done
  aws_demo elbv2 create-rule --listener-arn "$LISTENER_ARN" --priority "$priority" \
    --conditions "Field=host-header,HostHeaderConfig={Values=[$host]}" \
    --actions "Type=forward,TargetGroupArn=$TG_ARN" >/dev/null
  echo "Created HTTPS host rule for $host at priority $priority."
}

ensure_alias() {
  local host="$1" state fqdn batch
  state="$(check_dns_record "$host")"
  [[ "$state" == present ]] && { echo "Route 53 alias for $host already targets $ALB_NAME."; return; }
  fqdn="${host}."
  batch="$(jq -nc --arg name "$fqdn" --arg zone "$ALB_ZONE_ID" --arg dns "dualstack.${ALB_DNS}." \
    '{Comment:"Keycloak demo Caddy host routing",Changes:[{Action:"CREATE",ResourceRecordSet:{Name:$name,Type:"A",AliasTarget:{HostedZoneId:$zone,DNSName:$dns,EvaluateTargetHealth:true}}}]}')"
  aws_demo route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "$batch" >/dev/null
  echo "Created Route 53 A alias for $host."
}

create_or_check_rule "$KEYCLOAK_HOST"
create_or_check_rule "$MOCK_FE_HOST"
ensure_alias "$KEYCLOAK_HOST"
ensure_alias "$MOCK_FE_HOST"

HEALTH="$(aws_demo elbv2 describe-target-health --target-group-arn "$TG_ARN")"
echo "Target health after configuration:"
jq -r '.TargetHealthDescriptions[] | "  \(.Target.Id):\(.Target.Port) \(.TargetHealth.State) \(.TargetHealth.Reason // "")"' <<<"$HEALTH"
echo "AWS routing setup complete. Start the Compose stack on EC2 and confirm the Caddy target becomes healthy."
