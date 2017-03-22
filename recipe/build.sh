#!/bin/bash

echo "$PREFIX" > embree.cfg

if [ "$(uname)" == "Darwin" ]; then
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export LDFLAGS="-Wl,-headerpad_max_install_names"
fi

$PYTHON setup.py install --single-version-externally-managed --record=record.txt
cp scripts/* $PREFIX/bin/

pip install python-hglib

sed -n 's/^__version__ = "\(.*\)"$/\1/p' ${SRC_DIR}/yt/__init__.py > __conda_version__.txt
sed -i -e 's/-/_/g' __conda_version__.txt
(
cat <<'EOF'
import hglib
from distutils.version import StrictVersion


def get_lineage_between_release_and_tip(repo_path, first, last):
    last = last.decode('utf-8')
    first = first.decode('utf-8')
    with hglib.open(repo_path) as client:
        rev = "'{0}'::'{1}' and p1('{0}'::'{1}') + '{1}'".format(first, last)
        lineage = client.log(rev.encode('utf-8'))
        return lineage


def get_branch_tip(repo_path, branch, exclude=None):
    """Returns the SHA1 hash of the most recent commit on the given branch"""
    revset = "head() and branch(%s)" % branch
    with hglib.open(repo_path) as client:
        if exclude is not None:
            try:
                client.log(exclude)
                revset += "and not %s" % exclude
            except hglib.error.CommandError:
                pass
        change = client.log(revset)[0][1][:12]
    return change


def get_first_commit_after_last_major_release(repo_path):
    """Returns the SHA1 hash of the first commit to the yt branch that wasn't
    included in the last tagged release.
    """
    with hglib.open(repo_path) as client:
        tags = client.log("reverse(tag())")
        tags = [t[2][3:].decode("utf-8") for t in tags
                if t[2].decode("utf-8").startswith('yt-')]
        tags = sorted(tags, key=StrictVersion, reverse=True)
        for tag in tags:
            t = StrictVersion(tag)
            if len(t.version) == 2 or t.version[2] == 0:
                last_major_tag = "yt-{}".format(tag)
                break
        rev = "last(ancestors(%s) and branch(yt))" % last_major_tag
        last_before_release = client.log(rev.encode('utf-8'))
        rev = "first(descendants({0}) and branch(yt) and not {0})".format(
            last_before_release[0][1].decode('utf-8'))
        first_after_release = client.log(rev.encode('utf-8'))
    return first_after_release[0][1][:12]


repo_path = '.'
last_major_release = get_first_commit_after_last_major_release(repo_path)
last_dev = get_branch_tip(repo_path, 'yt', 'experimental')
lineage = get_lineage_between_release_and_tip(
    repo_path, last_major_release, last_dev)

with open("__conda_buildnum__.txt", "w") as fp:
    fp.write("%i" % len(lineage))
EOF
) > gen_buildnum.py
$PYTHON gen_buildnum.py
