#!/usr/bin/env bash
set -euo pipefail
version=1.15.9
mkdir -p /tmp/streamml-terraform
cd /tmp/streamml-terraform
curl --fail --silent --show-error -O "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_linux_amd64.zip"
curl --fail --silent --show-error -O "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_SHA256SUMS"
grep "terraform_${version}_linux_amd64.zip$" "terraform_${version}_SHA256SUMS" | sha256sum -c -
unzip -o "terraform_${version}_linux_amd64.zip"
install terraform /usr/local/bin/terraform

