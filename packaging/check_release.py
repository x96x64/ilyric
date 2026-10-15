#!/usr/bin/env python3
"""Reject non-stable or unpublished releases before package distribution."""
import json
import re
import subprocess
import sys


def validate_tag(tag):
    if re.fullmatch(r"v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", tag) is None:
        raise ValueError("Distribution requires a stable vMAJOR.MINOR.PATCH tag; prerelease packaging is not supported")


def validate_release(tag, release):
    validate_tag(tag)
    if release.get("tagName") != tag:
        raise ValueError("The release tag does not match the requested tag")
    if release.get("isDraft") is not False or release.get("isPrerelease") is not False:
        raise ValueError("Distribution requires a published, non-prerelease GitHub Release")


def main(tag):
    validate_tag(tag)
    release = json.loads(subprocess.check_output(
        ["gh", "release", "view", tag, "--json", "tagName,isDraft,isPrerelease"], text=True))
    validate_release(tag, release)


if __name__ == "__main__":
    try:
        main(sys.argv[1])
    except (ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
