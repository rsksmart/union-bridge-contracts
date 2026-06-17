#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C   # locale-independent sort/compare

echo "================ BYTECODE DETERMINISM CHECK ================"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXPECTED_SOLC="${EXPECTED_SOLC:-}"
SRC_DIR="${SRC_DIR:-src}"; SRC_DIR="${SRC_DIR%/}"
OUT_DIR="${OUT_DIR:-out}"; OUT_DIR="${OUT_DIR%/}"

# ---- preconditions ---------------------------------------------------------
for bin in jq forge tar; do
    command -v "$bin" >/dev/null 2>&1 || { echo "::error::'$bin' is required"; exit 1; }
done

if command -v sha256sum >/dev/null 2>&1; then
    SHA() { sha256sum | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
    SHA() { shasum -a 256 | awk '{print $1}'; }
else
    echo "::error::need sha256sum or shasum"; exit 1
fi

FORGE_USE=()
[ -n "$EXPECTED_SOLC" ] && FORGE_USE=(--use "$EXPECTED_SOLC")

echo "forge: $(forge --version | head -n1)" >&2

# ---- helpers ---------------------------------------------------------------

# Build a project rooted at $1 (clean + build, pinned solc if configured)
build_in() {
    local where="$1"
    echo "Building in ${where} ..." >&2
    ( cd "$where" \
        && forge clean >/dev/null \
        && forge build -q ${FORGE_USE[@]+"${FORGE_USE[@]}"} )
}

# Write a deterministic per-contract digest for the project rooted at $1 into $2
# Each line: "<src>:<name>\t<solcVersion>\t<sha256(creation)>\t<sha256(runtime)>"
collect_digest() {
    local base="$1" digest_file="$2"
    : > "$digest_file"

    local art src name ver creation runtime ch rh
    while IFS= read -r art; do
        # Resolve source path + contract name from the artifact's own metadata
        IFS=$'\t' read -r src name ver < <(jq -r '
            (.metadata.settings.compilationTarget // {}) as $ct
            | [ ($ct | keys_unsorted[0] // ""),
                ($ct | to_entries[0].value // ""),
                (.metadata.compiler.version // "") ]
            | @tsv' "$art")

        [ -n "$src" ] || continue          # artifacts without a target (e.g. metadata-only)
        case "$src" in "$SRC_DIR"/*) : ;; *) continue ;; esac   # production only

        creation="$(jq -r '.bytecode.object // empty' "$art" | sed 's/^0x//')"
        runtime="$(jq -r '.deployedBytecode.object // empty' "$art" | sed 's/^0x//')"
        [ -z "$creation" ] && [ -z "$runtime" ] && continue     # interfaces / abstract

        ch="$(printf '%s' "$creation" | SHA)"
        rh="$(printf '%s' "$runtime"  | SHA)"

        printf '%s\t%s\t%s\t%s\n' "${src}:${name}" "$ver" "$ch" "$rh" >> "$digest_file"
    done < <(find "${base}/${OUT_DIR}" -type f -name '*.json' 2>/dev/null | sort)

    sort -o "$digest_file" "$digest_file"   # ordering independent of FS traversal

    if [ ! -s "$digest_file" ]; then
        echo "::error::no production contracts discovered under ${SRC_DIR}/ in ${base}" >&2
        exit 1
    fi
}

# Assert a single solc version across production contracts (+ optional pin)
assert_solc() {
    local digest_file="$1" versions count
    versions="$(cut -f2 "$digest_file" | sort -u)"
    count="$(printf '%s\n' "$versions" | grep -c . || true)"
    if [ "$count" -ne 1 ]; then
        echo "::error::multiple solc versions across production contracts:" >&2
        printf '  %s\n' "$versions" >&2
        exit 1
    fi
    if [ -n "$EXPECTED_SOLC" ]; then
        case "$versions" in
            "$EXPECTED_SOLC"|"$EXPECTED_SOLC"+*) : ;;
            *) echo "::error::solc ${versions} != expected ${EXPECTED_SOLC}" >&2; exit 1 ;;
        esac
    fi
    echo "solc: ${versions} ($(grep -c . "$digest_file") production contracts)" >&2
}

# ---- run -------------------------------------------------------------------
ALT_ROOT="$(mktemp -d)"
DIGEST_A="$(mktemp)"
DIGEST_B="$(mktemp)"
trap 'rm -rf "$ALT_ROOT" "$DIGEST_A" "$DIGEST_B"' EXIT

# Paths that do not affect forge compilation; skip them to keep replication fast.
COPY_EXCLUDE=(
    "$OUT_DIR"
    cache
    broadcast
    .git
    node_modules
    .pnpm-store
    .npm
    target
    dist
    build
    venv
    __pycache__
    .pytest_cache
    lcov.info
    dry-run
    31337
    .DS_Store
)

TAR_EXCLUDE_ARGS=()
for pattern in "${COPY_EXCLUDE[@]}"; do
    TAR_EXCLUDE_ARGS+=(--exclude="$pattern")
done

echo "Replicating working tree to ${ALT_ROOT} (excluding build dirs and tool caches)..." >&2
tar -c -C "$ROOT" "${TAR_EXCLUDE_ARGS[@]}" . | tar -x -C "$ALT_ROOT"

build_in "$ROOT"
collect_digest "$ROOT" "$DIGEST_A"
assert_solc "$DIGEST_A"

build_in "$ALT_ROOT"
collect_digest "$ALT_ROOT" "$DIGEST_B"

HASH_A="$(SHA < "$DIGEST_A")"
HASH_B="$(SHA < "$DIGEST_B")"
echo "Digest (pass 1, ${ROOT}):     ${HASH_A}"
echo "Digest (pass 2, ${ALT_ROOT}): ${HASH_B}"

if [ "$HASH_A" != "$HASH_B" ]; then
    echo "::error::bytecode is not reproducible across independent build paths" >&2
    echo "---- per-contract digest diff (name<TAB>solc<TAB>sha(creation)<TAB>sha(runtime)) ----" >&2
    diff -u "$DIGEST_A" "$DIGEST_B" >&2 || true
    exit 1
fi

echo "Bytecode determinism check passed"