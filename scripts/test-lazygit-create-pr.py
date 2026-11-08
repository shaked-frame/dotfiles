#!/usr/bin/env python3
"""Exercise the PR hotkey helper with real local Git repos and a fake gh."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "home/dot_config/lazygit/scripts/create-pr.py"


class CreatePRTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="lazygit-pr-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.capture = self.root / "gh.json"
        self.env = dict(
            os.environ,
            GIT_CONFIG_GLOBAL=os.devnull,
            GIT_CONFIG_NOSYSTEM="1",
            GIT_AUTHOR_NAME="Test",
            GIT_AUTHOR_EMAIL="test@example.com",
            GIT_COMMITTER_NAME="Test",
            GIT_COMMITTER_EMAIL="test@example.com",
            GH_CAPTURE=str(self.capture),
        )
        bindir = self.root / "bin"
        bindir.mkdir()
        gh = bindir / "gh"
        gh.write_text(
            f"#!{sys.executable}\n"
            "import json, os, pathlib, sys\n"
            "if '--help' in sys.argv:\n"
            "    print('usage: gh pr create' if os.environ.get('GH_OLD') else '--attach file')\n"
            "    sys.exit(0)\n"
            "args = sys.argv[1:]\n"
            "body_file = pathlib.Path(args[args.index('--body-file') + 1])\n"
            "payload = {'args': args, 'body': body_file.read_text()}\n"
            "pathlib.Path(os.environ['GH_CAPTURE']).write_text(json.dumps(payload))\n"
            "print('https://github.com/example/repo/pull/1')\n"
            "sys.exit(int(os.environ.get('GH_EXIT', '0')))\n"
        )
        gh.chmod(0o755)
        self.env["PATH"] = f"{bindir}{os.pathsep}{self.env['PATH']}"
        self.git("init", "-b", "main")
        self.write("package.json", '{"name":"workspace"}')
        self.write("apps/web/package.json", '{"name":"web-app"}')
        self.write("apps/web/src/view.js", "old\n")
        self.write("packages/ui/package.json", '{"name":"ui"}')
        self.write("packages/ui/button.js", "old\n")
        self.commit()
        self.git("checkout", "-b", "feature/FRM-123_test")
        self.write("apps/web/src/view.js", "new\n")
        self.commit()

    def git(self, *args):
        return subprocess.check_output(
            ["git", "-c", "core.hooksPath=/dev/null", *args],
            cwd=self.repo, env=self.env, stderr=subprocess.PIPE, text=True,
        ).strip()

    def write(self, path, content):
        file = self.repo / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(content)

    def commit(self):
        self.git("add", ".")
        self.git("commit", "--no-gpg-sign", "-m", "Test change")

    def run_script(self, title="add filters", description="Description", base="", cwd=None, body_file=None, reviewer=None):
        options = ["--body-file", str(body_file)] if body_file is not None else []
        if reviewer is not None:
            options.extend(["--reviewer", reviewer])
        return subprocess.run(
            [sys.executable, str(SCRIPT), *options, "--", title, description, base],
            cwd=cwd or self.repo, env=self.env, capture_output=True, text=True,
        )

    def options(self):
        payload = json.loads(self.capture.read_text())
        args = payload["args"]
        self.assertEqual(args[:2], ["pr", "create"])
        options = dict(zip(args[2::2], args[3::2]))
        options.pop("--body-file")
        options["--body"] = payload["body"]
        return options

    def attachments(self):
        args = json.loads(self.capture.read_text())["args"]
        return [args[i + 1] for i, arg in enumerate(args) if arg == "--attach"]

    def test_preserves_pr_metadata(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("https://github.com/example/repo/pull/1", result.stdout)
        self.assertEqual(self.options(), {
            "--base": "main",
            "--title": "feature/FRM-123_test: add filters (web-app)",
            "--body": "Jira: [frm-123](https://frame-labs.atlassian.net/browse/FRM-123)\n\nDescription",
            "--label": "frontend",
            "--assignee": "shaked-frame",
        })

    def test_user_input_stays_literal(self):
        title = "fix 'quotes' and $(touch injected)"
        description = 'Keep `code`, "$HOME", and \\ paths.\nSecond line.'
        result = self.run_script(title, description)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(title, self.options()["--title"])
        self.assertTrue(self.options()["--body"].endswith(description))
        self.assertFalse((self.repo / "injected").exists())

    def test_reviewer_requests_review_and_preserves_assignee(self):
        for reviewer in ("coworker", "other-coworker", "  coworker  "):
            with self.subTest(reviewer=reviewer):
                result = self.run_script(reviewer=reviewer)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.options()["--reviewer"], reviewer.strip())
                self.assertEqual(self.options()["--assignee"], "shaked-frame")

    def test_empty_reviewer_skips_review_request(self):
        for reviewer in ("", "  "):
            with self.subTest(reviewer=reviewer):
                result = self.run_script(reviewer=reviewer)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("--reviewer", self.options())
                self.assertEqual(self.options()["--assignee"], "shaked-frame")

    def test_reviewer_stays_literal(self):
        reviewer = "coworker; $(touch injected)"
        result = self.run_script(reviewer=reviewer)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.options()["--reviewer"], reviewer)
        self.assertFalse((self.repo / "injected").exists())

    def test_remote_only_base_and_nested_working_directory(self):
        self.git("update-ref", "refs/remotes/origin/main", "main")
        self.git("branch", "-D", "main")
        result = self.run_script(cwd=self.repo / "apps/web/src")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.options()["--title"].endswith("(web-app)"))

    def test_base_override(self):
        self.git("branch", "develop", "main")
        result = self.run_script(base="develop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.options()["--base"], "develop")

    def test_multiple_packages_rank_by_changed_file_count(self):
        self.write("apps/web/src/other.js", "new\n")
        self.write("packages/ui/button.js", "new\n")
        self.commit()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.options()["--title"].endswith("(web-app)"))
        self.assertTrue(self.options()["--body"].endswith("Also touches: ui"))

    def test_repo_without_package_manifest(self):
        self.git("rm", "package.json", "apps/web/package.json")
        self.commit()
        result = self.run_script(description="")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.options()["--title"], "feature/FRM-123_test: add filters")
        self.assertNotIn("\n\n", self.options()["--body"])

    def test_invalid_inputs_do_not_call_gh(self):
        for title in ("", "  ", "two\nlines"):
            with self.subTest(title=title):
                result = self.run_script(title=title)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.capture.exists())
        result = self.run_script(base="missing")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Fetch it first", result.stderr)
        self.assertFalse(self.capture.exists())

    def test_missing_jira_ticket_does_not_call_gh(self):
        self.git("branch", "-m", "feature/no-ticket")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Jira ticket", result.stderr)
        self.assertFalse(self.capture.exists())

    def test_base_branch_does_not_call_gh(self):
        self.git("checkout", "main")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Switch to your PR branch", result.stderr)
        self.assertFalse(self.capture.exists())

    def test_detached_head_does_not_call_gh(self):
        self.git("checkout", "--detach")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.capture.exists())

    def test_gh_failure_is_propagated(self):
        self.env["GH_EXIT"] = "7"
        self.assertEqual(self.run_script().returncode, 7)

    def test_markdown_file_preserves_formatting_and_source(self):
        source = self.root / "pr body.md"
        markdown = "## Summary\n\n```text\nparent\n  child\n```\n\n## Evidence\n\n- test passed\n"
        source.write_text(markdown)
        result = self.run_script(body_file=source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(source.read_text(), markdown)
        self.assertTrue(self.options()["--body"].endswith(markdown))
        payload = json.loads(self.capture.read_text())
        self.assertIn("--body-file", payload["args"])
        generated = Path(payload["args"][payload["args"].index("--body-file") + 1])
        self.assertFalse(generated.exists(), "Temporary body should be cleaned up")

    def test_existing_jira_line_is_not_duplicated(self):
        source = self.root / "body.md"
        markdown = "Jira: [frm-123](https://frame-labs.atlassian.net/browse/FRM-123)\n\n## Summary\n\nDone.\n"
        source.write_text(markdown)
        result = self.run_script(body_file=source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.options()["--body"], markdown)

    def test_local_screenshots_are_attached_once_and_remote_images_unchanged(self):
        source = self.root / "body.md"
        before = self.root / "before.png"
        after = self.root / "after shot.png"
        before.write_bytes(b"fake image")
        after.write_bytes(b"fake image")
        markdown = (
            "## Evidence\n\n![Before](./before.png)\n"
            f"![After](<{after}> \"Caption\")\n"
            "![Repeat](before.png)\n"
            "![Hosted](https://github.com/user-attachments/assets/123)\n"
        )
        source.write_text(markdown)
        result = self.run_script(body_file=source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.attachments(), [str(before.resolve()), str(after.resolve())])
        body = self.options()["--body"]
        self.assertIn(f"![Before](<{before.resolve()}>)", body)
        self.assertIn(f'![After](<{after.resolve()}> "Caption")', body)
        self.assertIn("![Hosted](https://github.com/user-attachments/assets/123)", body)
        self.assertEqual(source.read_text(), markdown)

    def test_markdown_image_examples_in_code_are_not_uploaded(self):
        source = self.root / "body.md"
        markdown = (
            "```markdown\n![Example](missing.png)\n```\n\n"
            "Use `![Example](also-missing.png)` for images.\n"
            "~~~markdown\n![Example](another-missing.png)\n~~~\n"
        )
        source.write_text(markdown)
        result = self.run_script(body_file=source)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.options()["--body"].endswith(markdown))
        self.assertEqual(self.attachments(), [])

    def test_relative_body_path_and_working_directory_image_fallback(self):
        self.write("docs/pr.md", "![Screenshot](screen.png)")
        self.write("screen.png", "fake image")
        result = self.run_script(body_file="docs/pr.md")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.attachments(), [str((self.repo / "screen.png").resolve())])

    def test_missing_body_file_does_not_call_gh(self):
        result = self.run_script(body_file=self.root / "missing.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing.md", result.stderr)
        self.assertFalse(self.capture.exists())

    def test_missing_screenshot_does_not_call_gh(self):
        source = self.root / "body.md"
        source.write_text("![Before](missing.png)")
        result = self.run_script(body_file=source)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Screenshot not found", result.stderr)
        self.assertFalse(self.capture.exists())

    def test_old_gh_does_not_create_pr_with_broken_images(self):
        source = self.root / "body.md"
        source.write_text("![Before](before.png)")
        (self.root / "before.png").write_bytes(b"fake image")
        self.env["GH_OLD"] = "1"
        result = self.run_script(body_file=source)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Update GitHub CLI", result.stderr)
        self.assertFalse(self.capture.exists())


if __name__ == "__main__":
    unittest.main()
