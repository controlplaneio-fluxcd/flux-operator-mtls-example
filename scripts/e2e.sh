#!/usr/bin/env bash
# Creates the kind cluster with Terraform, bootstraps Flux with SPIFFE mTLS,
# verifies every mTLS path and destroys the cluster.
#
# Env:
#   GIT_REF       ref Flux syncs from (default: the current branch, which
#                 must be pushed)
#   CLUSTER_NAME  kind cluster name (default: flux-mtls)
#   KEEP_CLUSTER  set to true to skip terraform destroy
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
CLUSTER_NAME="${CLUSTER_NAME:-flux-mtls}"
KEEP_CLUSTER="${KEEP_CLUSTER:-false}"
GIT_REF="${GIT_REF:-refs/heads/$(git -C "${ROOT_DIR}" rev-parse --abbrev-ref HEAD)}"
RECEIVER_TOKEN="$(openssl rand -hex 16)"
FLUX_NS="flux-system"
# Terraform writes the kind context to ~/.kube/config. Every kubectl and
# helm call is pinned to it so the script never touches another cluster.
export KUBECONFIG="${HOME}/.kube/config"
KUBE_CONTEXT="kind-${CLUSTER_NAME}"
kubectl() { command kubectl --context "${KUBE_CONTEXT}" "$@"; }
helm() { command helm --kube-context "${KUBE_CONTEXT}" "$@"; }

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
fail() { printf '\033[1;31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }

tf() {
    local cmd="$1"
    shift
    terraform -chdir="${TF_DIR}" "${cmd}" -input=false \
        -var "cluster_name=${CLUSTER_NAME}" \
        -var "git_ref=${GIT_REF}" \
        -var "receiver_token=${RECEIVER_TOKEN}" \
        "$@"
}

PIDS=()
# port_forward <namespace> <service> <local port> <remote port>
port_forward() {
    kubectl -n "$1" port-forward "service/$2" "$3:$4" >/dev/null 2>&1 &
    PIDS+=("$!")
}

# retry_curl <curl args...> retries while the port-forward is not ready.
retry_curl() {
    local rc
    for _ in $(seq 1 30); do
        rc=0
        curl "$@" || rc=$?
        case "${rc}" in
            7|28|52|56) sleep 1 ;;
            *) return "${rc}" ;;
        esac
    done
    return "${rc}"
}

# expect_tls_rejection <url> <server name> fails unless a TLS client without
# an SVID is rejected.
expect_tls_rejection() {
    local rc
    for _ in $(seq 1 30); do
        rc=0
        curl -k -sS --max-time 5 -o /dev/null "$1" 2>/dev/null || rc=$?
        case "${rc}" in
            0) fail "$2 accepted a TLS client without an SVID" ;;
            7|28) sleep 1 ;;
            *) return 0 ;;
        esac
    done
    fail "$2 was not reachable"
}

# wait_spiffeid <ClusterSPIFFEID name> waits for the entry to select a pod.
wait_spiffeid() {
    local selected
    for _ in $(seq 1 60); do
        selected=$(kubectl get clusterspiffeid "$1" -o jsonpath='{.status.stats.podsSelected}' 2>/dev/null || true)
        [[ "${selected:-0}" -gt 0 ]] && return 0
        sleep 2
    done
    fail "ClusterSPIFFEID $1 selected no pods"
}

# expect_plain_http_rejection <namespace> <service> <local port> <source> <source namespace>
# fails unless the artifact server answers a plain HTTP GET of the source
# artifact with 400.
expect_plain_http_rejection() {
    local path code
    path="$(kubectl -n "$5" get "$4" -o jsonpath='{.status.artifact.url}' | sed -E 's|^https?://[^/]+||')"
    [[ -n "${path}" ]] || fail "$4 has no artifact"
    port_forward "$1" "$2" "$3" 80
    for _ in $(seq 1 30); do
        # 000 means the port-forward is not ready yet.
        code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$3${path}" || true)"
        [[ "${code}" != "000" ]] && break
        sleep 1
    done
    [[ "${code}" == "400" ]] || fail "$2 answered plain HTTP with ${code}"
}

# helm_revision <namespace> <release>
helm_revision() {
    helm -n "$1" history "$2" -o json | jq -r 'max_by(.revision).revision'
}

cleanup() {
    local code=$?
    for pid in "${PIDS[@]}"; do
        kill "${pid}" >/dev/null 2>&1 || true
    done
    if [[ ${code} -ne 0 ]] && command kubectl config get-contexts "${KUBE_CONTEXT}" >/dev/null 2>&1; then
        log "FAILURE (exit ${code}), dumping diagnostics"
        kubectl get pods -A -o wide || true
        kubectl -n "${FLUX_NS}" get fluxinstance/flux -o yaml || true
        kubectl get kustomizations,helmreleases,ocirepositories,gitrepositories -A || true
        kubectl get clusterspiffeids -o yaml || true
        kubectl -n "${FLUX_NS}" get gateway,httproute,backendtlspolicy -o yaml || true
        kubectl get events -A --sort-by=.lastTimestamp | tail -50 || true
        for dep in flux-operator source-controller kustomize-controller helm-controller notification-controller; do
            echo "--- ${dep} ---"
            kubectl -n "${FLUX_NS}" logs "deploy/${dep}" --tail=80 || true
        done
        kubectl -n envoy-gateway-system logs deploy/envoy-gateway --tail=80 || true
        kubectl -n envoy-gateway-system logs -l gateway.envoyproxy.io/owning-gateway-name=flux --tail=80 || true
    fi
    if [[ "${KEEP_CLUSTER}" != "true" ]]; then
        log "Destroying the cluster"
        tf destroy -auto-approve >/dev/null || true
    fi
    exit "${code}"
}

for bin in terraform kubectl helm docker jq curl tar openssl git; do
    command -v "${bin}" >/dev/null 2>&1 || fail "required tool '${bin}' not found"
done

if [[ -z "${CI:-}" ]]; then
    remote_sha="$(git -C "${ROOT_DIR}" ls-remote origin "${GIT_REF}" | cut -f1)"
    [[ "${remote_sha}" == "$(git -C "${ROOT_DIR}" rev-parse HEAD)" ]] \
        || fail "${GIT_REF} on origin does not match HEAD; push first or set GIT_REF"
fi

log "Initializing Terraform"
terraform -chdir="${TF_DIR}" init -input=false >/dev/null
[[ -z "$(terraform -chdir="${TF_DIR}" state list 2>/dev/null)" ]] \
    || fail "Terraform state is not empty; run terraform destroy first"

trap cleanup EXIT

log "Creating the cluster and bootstrapping Flux from ${GIT_REF}"
tf apply -auto-approve -var debug_on_failure=true

log "Checking the FluxInstance"
kubectl -n "${FLUX_NS}" wait fluxinstance/flux --for=condition=Ready --timeout=5m
[[ "$(kubectl -n "${FLUX_NS}" get fluxinstance/flux -o jsonpath='{.status.spiffe.mtls.enabled}')" == "true" ]] \
    || fail "FluxInstance status reports mTLS disabled"
info "Flux controllers run with SPIFFE mTLS"

log "Waiting for the Flux Kustomizations"
for ks in "${FLUX_NS}/flux-system" "${FLUX_NS}/spire" "${FLUX_NS}/envoy-gateway" "${FLUX_NS}/gateway" frontend/frontend backend/backend; do
    ns="${ks%%/*}"
    name="${ks#*/}"
    for _ in $(seq 1 60); do
        kubectl -n "${ns}" get "kustomization/${name}" >/dev/null 2>&1 && break
        sleep 5
    done
    kubectl -n "${ns}" wait "kustomization/${name}" --for=condition=Ready --timeout=15m
done
kubectl wait helmreleases --all -A --for=condition=Ready --timeout=5m

log "Checking SPIFFE identities"
wait_spiffeid spire-system-spire-flux-system
wait_spiffeid spire-system-spire-envoy-gateway-proxy
wait_spiffeid spire-system-spire-apps
info "ClusterSPIFFEIDs select the Flux, Envoy and app pods"

log "Checking that Flux adopted the bootstrap releases"
for obj in "spire-system statefulset/spire-server" "${FLUX_NS} deployment/flux-operator"; do
    read -r ns name <<<"${obj}"
    [[ -n "$(kubectl -n "${ns}" get "${name}" -o jsonpath='{.metadata.labels.helm\.toolkit\.fluxcd\.io/name}')" ]] \
        || fail "${name} is not managed by helm-controller"
done
[[ "$(helm -n spire-system list -q | sort | tr '\n' ' ')" == "spire spire-crds " ]] \
    || fail "unexpected Helm releases in spire-system"
SPIRE_REV="$(helm_revision spire-system spire)"
OPERATOR_REV="$(helm_revision "${FLUX_NS}" flux-operator)"
info "spire and flux-operator releases are managed by helm-controller"

log "Checking the app namespaces"
for app in frontend backend; do
    [[ -n "$(kubectl get namespace "${app}" -o jsonpath='{.metadata.labels.source\.extensions\.fluxcd\.io/generator}')" ]] \
        || fail "namespace ${app} is not managed by the ArtifactGenerator"
    kubectl -n "${app}" wait "externalartifact/${app}" --for=condition=Ready --timeout=2m
done
APP_SA="system:serviceaccount:frontend:flux"
[[ "$(kubectl auth can-i create deployments -n frontend --as="${APP_SA}")" == "yes" ]] \
    || fail "the frontend ServiceAccount cannot manage its own namespace"
for check in "create deployments -n backend" "create deployments -n default" "create clusterrolebindings" "get secrets -n flux-system"; do
    # shellcheck disable=SC2086
    [[ "$(kubectl auth can-i ${check} --as="${APP_SA}" || true)" == "no" ]] \
        || fail "the frontend ServiceAccount can ${check}"
done
info "apps get a managed namespace, an ExternalArtifact and admin rights in that namespace only"

log "Checking that the artifact servers reject plain HTTP"
expect_plain_http_rejection "${FLUX_NS}" source-controller 9090 gitrepository/flux-system "${FLUX_NS}"
expect_plain_http_rejection "${FLUX_NS}" source-watcher 9091 externalartifact/frontend frontend
info "source-controller and source-watcher reject plain HTTP with 400"

log "Checking that the Web UI and the Receiver reject clients without an SVID"
port_forward "${FLUX_NS}" flux-operator 9443 9080
expect_tls_rejection "https://127.0.0.1:9443/" "Web UI"
port_forward "${FLUX_NS}" webhook-receiver 9444 443
expect_tls_rejection "https://127.0.0.1:9444/" "webhook Receiver"
info "TLS clients without an SVID rejected"

log "Calling the Receiver through Envoy Gateway"
for _ in $(seq 1 60); do
    kubectl -n envoy-gateway-system get service/flux-gateway >/dev/null 2>&1 && break
    sleep 2
done
kubectl -n envoy-gateway-system rollout status deployment \
    -l gateway.envoyproxy.io/owning-gateway-name=flux --timeout=5m
port_forward envoy-gateway-system flux-gateway 8080 80
kubectl -n "${FLUX_NS}" wait receiver/flux-system --for=condition=Ready --timeout=2m
WEBHOOK_PATH="$(kubectl -n "${FLUX_NS}" get receiver/flux-system -o jsonpath='{.status.webhookPath}')"
retry_curl -fsS --max-time 10 -X POST -H 'Content-Type: application/json' -d '{}' \
    "http://127.0.0.1:8080${WEBHOOK_PATH}" >/dev/null
for _ in $(seq 1 30); do
    nc_logs="$(kubectl -n "${FLUX_NS}" logs deploy/notification-controller --tail=-1 2>/dev/null || true)"
    grep -q "handling request: ${WEBHOOK_PATH##*/}" <<<"${nc_logs}" && break
    sleep 1
done
grep -q "handling request: ${WEBHOOK_PATH##*/}" <<<"${nc_logs}" \
    || fail "notification-controller did not handle the Receiver request"
info "Envoy reached the Receiver over SPIFFE mTLS"

log "Using the Web UI through Envoy Gateway"
UI_BODY="$(retry_curl -fsS --max-time 10 "http://127.0.0.1:8080/")"
grep -qi "<html" <<<"${UI_BODY}" || fail "Web UI did not return HTML"
ARTIFACT_FILE="$(mktemp)"
retry_curl -fsS --max-time 30 -o "${ARTIFACT_FILE}" \
    "http://127.0.0.1:8080/api/v1/artifact/download?kind=GitRepository&namespace=${FLUX_NS}&name=flux-system"
tar -tzf "${ARTIFACT_FILE}" >/dev/null || fail "downloaded artifact is not a tar.gz"
rm -f "${ARTIFACT_FILE}"
info "Envoy reached the Web UI and the operator fetched the artifact over SPIFFE mTLS"

log "Calling the backend from the frontend over SPIFFE mTLS"
port_forward frontend podinfo 9898 9898
ECHO="$(retry_curl -fsS --max-time 10 -X POST -d 'mtls-e2e' "http://127.0.0.1:9898/echo")"
grep -q "mtls-e2e" <<<"${ECHO}" || fail "the frontend did not get the backend echo: ${ECHO}"
BACKEND_LOGS="$(kubectl -n backend logs deploy/podinfo --tail=-1)"
jq -eR 'fromjson? | select(.msg == "request started" and .uri == "/echo" and .spiffe_id == "spiffe://example.org/ns/frontend/sa/podinfo")' \
    <<<"${BACKEND_LOGS}" >/dev/null || fail "the backend did not log the frontend SPIFFE ID"
port_forward backend podinfo 9445 9899
expect_tls_rejection "https://127.0.0.1:9445/" "backend"
info "the frontend called the backend with its SVID; the backend rejects clients without one"

log "Re-running the bootstrap"
tf apply -auto-approve -var revision=2 >/dev/null
[[ "$(helm_revision spire-system spire)" == "${SPIRE_REV}" ]] \
    || fail "the bootstrap upgraded the adopted spire release"
[[ "$(helm_revision "${FLUX_NS}" flux-operator)" == "${OPERATOR_REV}" ]] \
    || fail "the bootstrap upgraded the adopted flux-operator release"
info "the bootstrap left the adopted releases alone"

log "PASS"
