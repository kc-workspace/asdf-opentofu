#!/usr/bin/env bash

## Check GPG value from input path
## usage: `kc_asdf_gpg '/tmp/hello.tar.gz' 'https://example.com'`
kc_asdf_gpg() {
  local ns="gpg.addon"

  [ -n "${ASDF_INSECURE:-}" ] &&
    kc_asdf_warn "$ns" "Skipped checksum because user disable security" &&
    return 0
  ! command -v gpg >/dev/null &&
    kc_asdf_error "$ns" "gpg command is missing" &&
    return 1

  local filepath="$1" gpg_sig_url="$2"
  if command -v _kc_asdf_custom_gpg_filepath >/dev/null; then
    kc_asdf_debug "$ns" "developer custom filepath to verify gpg"
    filepath="$(_kc_asdf_custom_gpg_filepath "$filepath")"
  fi

  if command -v _kc_asdf_custom_gpg_setup >/dev/null; then
    kc_asdf_debug "$ns" "developer custom gpg setup function"
    _kc_asdf_custom_gpg_setup "$filepath" ||
      return 1
  fi

  local dirpath filename
  dirpath="$(dirname "$filepath")"
  filename="$(basename "$filepath")"
  local public_key
  public_key="$(kc_asdf_temp_file)"
  kc_asdf_fetch_file \
    "" \
    "$public_key"
  ! [ -f "$public_key" ] &&
    kc_asdf_error "$ns" "public key (%s) is missing" "$public_key" &&
    return 1
  if ! kc_asdf_exec gpg --quiet --import "$public_key"; then
    kc_asdf_error "$ns" "import public key failed, look on debug mode for more detail"
    return 1
  fi

  local signature="$dirpath/$filename.sig"
  if command -v _kc_asdf_custom_gpg_sigpath >/dev/null; then
    kc_asdf_debug "$ns" "developer custom gpg signature path"
    signature="$(_kc_asdf_custom_gpg_sigpath "$dirpath" "$filename.sig")"
  fi

  if [ -n "$gpg_sig_url" ]; then
    kc_asdf_debug "$ns" "downloading gpg signature of %s from '%s'" \
      "$filename" "$gpg_sig_url"
    if ! kc_asdf_fetch_file "$gpg_sig_url" "$signature"; then
      return 1
    fi
  fi

  kc_asdf_debug "$ns" "verifying signature of %s" "$filepath"
  if ! kc_asdf_exec gpg --quiet --verify "$signature" "$filepath"; then
    return 1
  fi

  kc_asdf_debug "$ns" "clean gpg key imported earlier"
  kc_asdf_exec gpg --quiet --yes --batch \
    --delete-secret-and-public-key "${fingerprint:-${keyid:-${email}}}"
}
