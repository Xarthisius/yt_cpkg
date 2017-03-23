#!/bin/bash

echo "$PREFIX" > embree.cfg

if [ "$(uname)" == "Darwin" ]; then
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export LDFLAGS="-Wl,-headerpad_max_install_names"
fi

sed -n 's/^__version__ = "\(.*\)"$/\1/p' ${SRC_DIR}/yt/__init__.py > __conda_version__.txt
sed -i -e 's/-/_/g' __conda_version__.txt

(
cat <<'EOF'
import subprocess as sp
from distutils.version import StrictVersion

cmd = 'hg log -r "reverse(tag())" --template "{tags},"'
tags = sp.check_output(cmd, shell=True).decode('utf8').split(',')
tags = [t[3:] for t in tags if t.startswith('yt-')]
tags = sorted(tags, key=StrictVersion, reverse=True)
for tag in tags:
    t = StrictVersion(tag)
    if len(t.version) == 2 or t.version[2] == 0:
        last_major_tag = "yt-{}".format(tag)
        break
cmd = 'hg log -q -r "last(ancestors(%s) and branch(yt))"' % last_major_tag
last_before_release = sp.check_output(cmd, shell=True).decode('utf-8')
cmd = 'hg log -q -r "first(descendants({0}) and branch(yt) and not {0})"'.format(
    last_before_release)
last_major_release = sp.check_output(cmd, shell=True).decode('utf8').strip('\n')
cmd = 'hg log -r "head() and branch(yt)" -q'
last_dev = sp.check_output(cmd, shell=True).decode('utf8').strip('\n').split('\n')
first = last_major_release.split(':')[-1]
last = last_dev[-1].split(':')[-1]
cmd = "'{0}'::'{1}' and p1('{0}'::'{1}') + '{0}'".format(first, last)
cmd = 'hg log -q -r "' + cmd + '"'
lineage = sp.check_output(cmd, shell=True).decode('utf8').split('\n')

with open("__conda_buildnum__.txt", "w") as fp:
    fp.write("%i" % len(lineage))
EOF
) > gen_buildnum.py

$PYTHON gen_buildnum.py

# Build yt
$PYTHON setup.py install --single-version-externally-managed --record=record.txt
cp scripts/* $PREFIX/bin/
