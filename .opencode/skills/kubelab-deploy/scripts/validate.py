#!/usr/bin/env python3
"""Read-only checks for a rendered KubeLab Argo application.

Requires PyYAML and kubectl. Does not apply resources, use credentials, or print
resource bodies. This catches obvious mistakes; it is not a complete secret scan.
"""

import argparse
import json
import re
import subprocess
from pathlib import Path

import yaml


def require(condition, message):
    if not condition:
        raise ValueError(message)


def group_of(resource):
    version = resource.get("apiVersion", "")
    return version.split("/")[0] if "/" in version else ""


def literal_credentials(value):
    if isinstance(value, dict):
        if re.search(r"(?i)(?:^|_)(?:password|token|api_key|client_secret|secret|access_key)$", str(value.get("name", ""))):
            require(not value.get("value"), "Literal credential-like environment value; use an approved Secret reference")
        for child in value.values():
            literal_credentials(child)
    elif isinstance(value, list):
        for child in value:
            literal_credentials(child)
    elif isinstance(value, str):
        require(not re.search(r"https?://[^\s/@]+:[^\s/@]+@", value), "Credential-bearing URL found")


def validate(resources, application, project, expected_path):
    require(application.get("kind") == "Application", "Expected an Argo Application")
    require(project.get("kind") == "AppProject", "Expected an Argo AppProject")
    spec, policy = application["spec"], project["spec"]
    destination = spec["destination"]
    namespace = destination["namespace"]
    require(application["metadata"].get("namespace") == project["metadata"].get("namespace") == "argocd", "Argo namespace must be argocd")
    require(spec["project"] == project["metadata"]["name"], "Application/project mismatch")
    require(spec["source"]["path"] == expected_path, "Application must point to the reviewed workload path")
    require(spec["source"].get("targetRevision"), "Declare the approved Git revision")
    require(spec["source"]["repoURL"] in policy["sourceRepos"], "Project does not allow the source repository")
    require(any(d.get("namespace") == namespace and
                (destination.get("name") and d.get("name") == destination["name"] or
                 destination.get("server") and d.get("server") == destination["server"])
                for d in policy["destinations"]), "Project does not allow the destination")
    for rule in policy.get("clusterResourceWhitelist", []) + policy.get("namespaceResourceWhitelist", []):
        require("*" not in (rule["group"], rule["kind"]), "Use explicit project resource kinds, not wildcards")
    cluster_kinds = {(r["group"], r["kind"]) for r in policy.get("clusterResourceWhitelist", [])}
    namespace_kinds = {(r["group"], r["kind"]) for r in policy.get("namespaceResourceWhitelist", [])}
    sync = spec.get("syncPolicy", {})
    options = set(sync.get("syncOptions", []))
    require(not options.intersection({"Force=true", "Replace=true", "Validate=false"}), "Unsafe sync option requires separate review")
    automated = sync.get("automated") or {}
    require(not automated.get("prune") and not automated.get("selfHeal"), "Default onboarding policy disables prune/self-heal")
    require("FailOnSharedResource=true" in options, "Refuse shared resource adoption")
    require(not application["metadata"].get("finalizers"), "Do not add application cascade deletion without approval")
    identities = set()
    for resource in resources:
        require(isinstance(resource, dict), "Rendered output must contain resource objects")
        kind, meta = resource["kind"], resource["metadata"]
        name = meta["name"]
        require(kind != "Secret", "Plain Secret objects are not permitted in this workflow; keep credentials external")
        require(kind not in {"Application", "AppProject"}, "Argo control objects must stay outside the workload source")
        pair = group_of(resource), kind
        require(pair in cluster_kinds or pair in namespace_kinds, f"Project does not allow kind {kind}")
        require(meta.get("namespace") in {None, namespace}, "Unexpected resource namespace")
        identity = pair + (meta.get("namespace"), name)
        require(identity not in identities, "Duplicate rendered resource identity")
        identities.add(identity)
        if kind == "Namespace":
            require(name == namespace, "Do not adopt a different Namespace")
        if kind in {"Namespace", "PersistentVolumeClaim"}:
            protection = meta.get("annotations", {}).get("argocd.argoproj.io/sync-options", "")
            require({"Prune=false", "Delete=false"} <= set(protection.split(",")), "Namespace/PVC must be protected from deletion")
        if kind == "Deployment" and name == "tgtg-vpn":
            rules = [r for r in spec.get("ignoreDifferences", []) if
                     r.get("group") == "apps" and r.get("kind") == "Deployment" and
                     r.get("name") == name and r.get("namespace") == namespace and
                     r.get("jsonPointers") == ["/spec/replicas"]]
            require(rules and "RespectIgnoreDifferences=true" in options, "TGTG replica ownership must be respected during sync, not just diff")
        literal_credentials(resource)
    return len(resources)


def render(repo, relative):
    root = Path(repo).resolve()
    path = (root / relative).resolve()
    require(path.is_relative_to(root), "Workload path escapes repository")
    require((path / "kustomization.yaml").is_file(), "Use an explicit Kustomize resource list")
    kustomization = yaml.safe_load((path / "kustomization.yaml").read_text())
    for item in kustomization.get("resources", []):
        require(isinstance(item, str) and not re.match(r"[a-z]+://|git@", item), "Remote resource imports need separate review")
        require((path / item).resolve().is_relative_to(path), "Resource path escapes the application directory")
    result = subprocess.run(["kubectl", "kustomize", str(path)], capture_output=True, text=True, timeout=30)
    require(result.returncode == 0, "Kustomize render failed; inspect local nonsecret inputs")
    return list(yaml.safe_load_all(result.stdout))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--app", required=True)
    parser.add_argument("--application", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    args = parser.parse_args()
    require(re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", args.app), "Use a lowercase app directory ID")
    relative = f"kubernetes/talos/deploy/{args.app}"
    count = validate(render(args.repo, relative), yaml.safe_load(args.application.read_text()),
                     yaml.safe_load(args.project.read_text()), relative)
    print(json.dumps({"application": args.app, "resource_count": count, "validation": "passed", "mutations": False}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, yaml.YAMLError) as error:
        # Never print YAML values/parser excerpts: invalid input may contain secrets.
        message = str(error) if type(error) is ValueError else type(error).__name__
        raise SystemExit("Deployment validation failed: " + message) from None
