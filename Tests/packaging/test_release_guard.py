"""Offline release-policy tests; no package upload or registry access."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "check_release", Path(__file__).resolve().parents[2] / "packaging/check_release.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class ReleaseGuardTests(unittest.TestCase):
    def test_stable_releases(self):
        for tag in ("v0.1.0", "v1.3.0", "v10.20.30"):
            with self.subTest(tag=tag):
                guard.validate_release(tag, dict(tagName=tag, isDraft=False, isPrerelease=False))

    def test_unsupported_tags_never_call_github(self):
        for tag in ("v1.4.0-rc.1", "v1.4.0-beta.2", "v1.4.0+build", "main", "1.4.0",
                    "v01.4.0", "v1.4", "v1.4.0\n", "v1.4.0; echo invalid", "--help", ""):
            with self.subTest(tag=tag), patch.object(guard.subprocess, "check_output") as request:
                with self.assertRaises(ValueError):
                    guard.main(tag)
                request.assert_not_called()

    def test_nonpublic_and_prerelease_flags(self):
        for draft, prerelease in ((True, False), (False, True), (True, True), (None, False), (False, None)):
            with self.subTest(draft=draft, prerelease=prerelease):
                with self.assertRaises(ValueError):
                    guard.validate_release("v1.4.0", dict(tagName="v1.4.0", isDraft=draft, isPrerelease=prerelease))

    def test_mismatched_or_missing_metadata(self):
        for data in ({}, dict(tagName="v1.3.0", isDraft=False, isPrerelease=False)):
            with self.assertRaises(ValueError):
                guard.validate_release("v1.4.0", data)

    def test_live_entry_point_with_mocked_response(self):
        with patch.object(guard.subprocess, "check_output", return_value=
                          '{"tagName":"v1.3.0","isDraft":false,"isPrerelease":false}') as request:
            guard.main("v1.3.0")
            request.assert_called_once()

    def test_api_failure_stops_distribution(self):
        with patch.object(guard.subprocess, "check_output", side_effect=guard.subprocess.CalledProcessError(1, "gh")):
            with self.assertRaises(guard.subprocess.CalledProcessError):
                guard.main("v1.3.0")
