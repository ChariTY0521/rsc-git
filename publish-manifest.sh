#!/usr/bin/env bash
set -Eeuo pipefail

# Place this file in the root of rsc-git, beside rustdesk.json and the PEM keys.
cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

manifest='rustdesk.json'
signature='rustdesk.json.sig'
private_key='rsc-manifest-private.pem'
public_key='rsc-manifest-public.pem'
to_sign="$(mktemp "$PWD/rustdesk.json.to-sign.XXXXXX")"
signature_bin="$(mktemp "$PWD/rustdesk.json.sig.bin.XXXXXX")"
commit_message="${1:-Update signed RustDesk manifest}"

cleanup() {
    rm -f -- "$to_sign" "$signature_bin"
}
trap cleanup EXIT

command -v git >/dev/null || { echo 'Git was not found in PATH.' >&2; exit 1; }
command -v openssl >/dev/null || { echo 'OpenSSL was not found in PATH.' >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null || {
    echo 'Run this script from the rsc-git repository root.' >&2
    exit 1
}

for file in "$manifest" "$private_key" "$public_key"; do
    [[ -f "$file" ]] || { echo "Missing $file." >&2; exit 1; }
done

git check-attr eol -- "$manifest" | grep -Fq 'eol: lf' || {
    echo ".gitattributes must contain: $manifest text eol=lf" >&2
    exit 1
}
git check-attr text -- "$signature" | grep -Fq 'text: unset' || {
    echo ".gitattributes must contain: $signature -text" >&2
    exit 1
}

# Sign the staged Git blob so the published JSON and signature always match.
git add --renormalize "$manifest"
git cat-file blob :"$manifest" > "$to_sign"
openssl dgst -sha256 -sign "$private_key" -out "$signature_bin" "$to_sign"
openssl base64 -A -in "$signature_bin" -out "$signature"
openssl base64 -d -A -in "$signature" -out "$signature_bin"
openssl dgst -sha256 -verify "$public_key" -signature "$signature_bin" "$to_sign"

git add -f "$signature"
if git diff --cached --quiet; then
    echo 'Manifest unchanged; nothing to deploy.'
    exit 0
fi

git commit -m "$commit_message"
git push origin main
echo 'Manifest deployed.'
