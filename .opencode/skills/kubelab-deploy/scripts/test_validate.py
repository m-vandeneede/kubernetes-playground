import copy
import importlib.util
import unittest
from pathlib import Path

import yaml


BASE = Path(__file__).parent
spec = importlib.util.spec_from_file_location("deployment_validation", BASE / "validate.py")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class ValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo = BASE.parents[3]
        cls.path = "kubernetes/talos/deploy/tgtg"
        cls.resources = validator.render(cls.repo, cls.path)
        cls.app = yaml.safe_load((cls.repo / "kubernetes/talos/argocd/applications/tgtg.yaml").read_text())
        cls.project = yaml.safe_load((cls.repo / "kubernetes/talos/argocd/projects/tgtg.yaml").read_text())

    def test_rendered_tgtg_allowed(self):
        self.assertEqual(validator.validate(self.resources, self.app, self.project, self.path), 12)
        self.assertNotIn("Secret", {r["kind"] for r in self.resources})

    def test_secret_rejected(self):
        secret = {"apiVersion": "v1", "kind": "Secret", "metadata": {"name": "fixture", "namespace": "tgtg"}, "data": {"test": "not-a-real-value"}}
        with self.assertRaisesRegex(ValueError, "Plain Secret"):
            validator.validate(self.resources + [secret], self.app, self.project, self.path)

    def test_diff_only_replica_exclusion_is_not_sufficient(self):
        app = copy.deepcopy(self.app)
        app["spec"]["syncPolicy"]["syncOptions"].remove("RespectIgnoreDifferences=true")
        with self.assertRaisesRegex(ValueError, "replica ownership"):
            validator.validate(self.resources, app, self.project, self.path)

    def test_ignore_must_target_named_vpn(self):
        app = copy.deepcopy(self.app)
        del app["spec"]["ignoreDifferences"][0]["name"]
        with self.assertRaisesRegex(ValueError, "replica ownership"):
            validator.validate(self.resources, app, self.project, self.path)

    def test_pvc_protection_required(self):
        resources = copy.deepcopy(self.resources)
        pvc = next(r for r in resources if r["kind"] == "PersistentVolumeClaim")
        del pvc["metadata"]["annotations"]
        with self.assertRaisesRegex(ValueError, "protected"):
            validator.validate(resources, self.app, self.project, self.path)

    def test_project_scope_and_credentials(self):
        project = copy.deepcopy(self.project)
        project["spec"]["clusterResourceWhitelist"][0]["kind"] = "*"
        with self.assertRaisesRegex(ValueError, "wildcards"):
            validator.validate(self.resources, self.app, project, self.path)
        with self.assertRaisesRegex(ValueError, "Credential-bearing"):
            validator.literal_credentials("https://fixture-user:fixture-password@example.invalid")
        with self.assertRaisesRegex(ValueError, "Literal credential"):
            validator.literal_credentials({"name": "API_TOKEN", "value": "synthetic-only"})


if __name__ == "__main__":
    unittest.main()
