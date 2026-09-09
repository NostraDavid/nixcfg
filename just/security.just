security-target host=default_host:
  @target="$(nix build --no-link --print-out-paths .#nixosConfigurations.\"{{host}}\".config.system.build.toplevel)"; \
  if [ -z "$target" ]; then echo "Failed to resolve NixOS system path" >&2; exit 1; fi; \
  printf '%s\n' "$target"

security-vulnix host=default_host strict="false":
  @target="$(just security-target "{{host}}")"; \
  echo "Scanning $target with vulnix"; \
  rc=0; vulnix "$target" || rc=$?; \
  if [ "$rc" -eq 2 ] && [ "{{strict}}" != "true" ]; then echo "vulnix reported vulnerabilities; continuing because strict=false"; exit 0; fi; \
  exit "$rc"

security-sbom host=default_host out_dir="reports/security":
  @report_dir="{{out_dir}}/{{host}}"; \
  target="$(just security-target "{{host}}")"; \
  mkdir -p "$report_dir"; \
  echo "Generating SBOM artifacts for $target in $report_dir"; \
  sbomnix "$target" --csv "$report_dir/sbom.csv" --cdx "$report_dir/sbom.cdx.json" --spdx "$report_dir/sbom.spdx.json"

security-osv host=default_host out_dir="reports/security" format="table":
  @report_dir="{{out_dir}}/{{host}}"; \
  sbom="$report_dir/sbom.cdx.json"; \
  if [ ! -f "$sbom" ]; then echo "CycloneDX SBOM ontbreekt, genereer die eerst in $report_dir" >&2; exit 1; fi; \
  echo "Scanning $sbom with osv-scanner"; \
  osv-scanner scan source -L "$sbom" --format "{{format}}"

security-grype host=default_host out_dir="reports/security" fail_on="":
  @report_dir="{{out_dir}}/{{host}}"; \
  sbom="$report_dir/sbom.cdx.json"; \
  if [ ! -f "$sbom" ]; then echo "CycloneDX SBOM ontbreekt, genereer die eerst in $report_dir" >&2; exit 1; fi; \
  if [ -n "{{fail_on}}" ]; then grype "sbom:$sbom" --fail-on "{{fail_on}}"; else grype "sbom:$sbom"; fi

security-smoke host=default_host:
  @just security-sbom "{{host}}" reports/security-smoke
  @just security-osv "{{host}}" reports/security-smoke
  @just security-grype "{{host}}" reports/security-smoke critical
