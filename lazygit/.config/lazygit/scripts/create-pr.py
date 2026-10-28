#!/usr/bin/env python3
"""Create a PR from LazyGit's title, description, base, and reviewer prompts."""

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import unquote, urlsplit


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def base_ref(base):
    # Resolve locally without a network request, including in worktrees where
    # only origin/main exists. Pass the original branch name to gh later.
    for ref in (f"refs/heads/{base}", f"refs/remotes/origin/{base}"):
        result = subprocess.run(
            ["git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    raise ValueError(f"Base branch {base!r} not found locally. Fetch it first.")


def package_scopes(root, changed_paths):
    """Rank nearest named packages by the number of changed files they own."""
    scopes = Counter()
    cache = {}
    for path in changed_paths:
        directory = (root / path).parent
        visited = []
        scope = None
        while directory == root or root in directory.parents:
            if directory in cache:
                scope = cache[directory]
                break
            visited.append(directory)
            manifest = directory / "package.json"
            if manifest.is_file():
                scope = json.loads(manifest.read_text()).get("name")
                if scope:
                    break
            directory = directory.parent
        for directory in visited:
            cache[directory] = scope
        if scope:
            scopes[scope] += 1
    return [scope for scope, _ in scopes.most_common()]


def attach_images(body, directory):
    """Resolve inline Markdown images, leaving hosted images and code alone."""
    attachments = []
    # Code blocks and inline code are alternatives so image examples inside
    # them are preserved, rather than treated as files to upload.
    pattern = re.compile(
        r"(?P<code>^(?P<fence>`{3,}|~{3,})[^\n]*\n.*?^(?P=fence)[ \t]*$|`+[^`\n]*`+)"
        r"|!\[(?:\\.|[^\]\\])*\]\([ \t]*(?P<path><[^>\n]+>|(?:\\.|[^()\s]|\([^()\n]*\))+)"
        r"(?:[ \t]+[\"'][^\n]*?[\"'])?[ \t]*\)",
        re.MULTILINE | re.DOTALL,
    )

    def replace(match):
        if match.group("code"):
            return match.group()
        destination = match.group("path").removeprefix("<").removesuffix(">")
        if urlsplit(destination).scheme or destination.startswith(("//", "#")):
            return match.group()
        destination = unquote(re.sub(r"\\([!\"#$%&'()*+,\-./:;<=>?@\[\]^_`{|}~\\])", r"\1", destination))
        path = Path(destination).expanduser()
        candidates = [directory / path, Path.cwd() / path]
        image = next((p.resolve() for p in candidates if p.is_file()), None)
        if image is None:
            raise ValueError(f"Screenshot not found: {destination}")
        if str(image) not in attachments:
            attachments.append(str(image))
        # The generated body lives in a temporary directory. Absolute image
        # references let gh match --attach regardless of the source directory.
        start, end = match.span("path")
        return match.group()[:start - match.start()] + f"<{image}>" + match.group()[end - match.start():]

    return pattern.sub(replace, body), attachments


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body-file", help="Markdown body; local inline images are attached automatically")
    parser.add_argument("--reviewer", default="", help="GitHub login; empty skips requesting a review")
    parser.add_argument("title")
    parser.add_argument("description")
    parser.add_argument("base", nargs="?", default="main")
    args = parser.parse_args()
    title = args.title.strip()
    if not title or "\n" in title or "\r" in title:
        raise ValueError("Enter a non-empty, single-line PR title.")

    branch = git("symbolic-ref", "--quiet", "--short", "HEAD")
    base = args.base.strip() or "main"
    if branch == base:
        raise ValueError("Switch to your PR branch before creating a pull request.")
    ticket = re.search(r"[a-z]+-\d+", branch, re.IGNORECASE)
    if not ticket:
        raise ValueError("The current branch must include a Jira ticket, e.g. frm-123.")

    root = Path(git("rev-parse", "--show-toplevel"))
    paths = subprocess.check_output(
        ["git", "diff", "--name-only", "--no-renames", "-z", f"{base_ref(base)}...HEAD", "--"]
    ).decode().split("\0")
    scopes = package_scopes(root, filter(None, paths))
    full_title = f"{branch}: {title}"
    if scopes:
        full_title += f" ({scopes[0]})"
    key = ticket.group().lower()
    directory = Path.cwd()
    if args.body_file:
        source = Path(args.body_file).expanduser().resolve()
        body = source.read_text(encoding="utf-8")
        directory = source.parent
    else:
        body = args.description.strip()
    if not re.search(r"^Jira:", body, re.MULTILINE | re.IGNORECASE):
        jira = f"Jira: [{key}](https://frame-labs.atlassian.net/browse/{key.upper()})"
        body = jira + (f"\n\n{body}" if body else "")
    if len(scopes) > 1:
        body += f"\n\nAlso touches: {', '.join(scopes[1:])}"
    body, attachments = attach_images(body, directory)
    if len(attachments) > 50:
        raise ValueError("GitHub CLI supports at most 50 attachments per PR.")
    if attachments:
        help_text = subprocess.check_output(["gh", "pr", "create", "--help"], text=True)
        if "--attach" not in help_text:
            raise ValueError("Update GitHub CLI to gh 2.99+ to upload screenshots with --attach.")

    # Argument arrays keep quotes, backticks and shell syntax in user input literal.
    # A temporary copy preserves the source file and leaves stdin available
    # for gh's unpublished-branch push prompt.
    with tempfile.TemporaryDirectory(prefix="lazygit-pr-") as temporary:
        body_file = Path(temporary) / "body.md"
        body_file.write_text(body, encoding="utf-8")
        command = [
            "gh", "pr", "create", "--base", base, "--title", full_title,
            "--body-file", str(body_file), "--label", "frontend", "--assignee", "shaked-frame",
        ]
        if args.reviewer.strip():
            command.extend(["--reviewer", args.reviewer.strip()])
        for attachment in attachments:
            command.extend(["--attach", attachment])
        return subprocess.call(command, cwd=root)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Create PR: {error}", file=sys.stderr)
        sys.exit(1)
