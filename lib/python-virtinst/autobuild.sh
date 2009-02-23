#!/bin/sh

set -v
set -e

rm -rf build dist python-virtinst.spec MANIFEST

python setup.py build
python tests/coverage.py -e
rm -rf build/coverage
mkdir build/coverage
python setup.py test
python tests/coverage.py -r virtinst/*.py > build/coverage/summary.txt
python tests/coverage.py -d build/coverage/ -a virtinst/*.py
python setup.py install --prefix=$AUTOBUILD_INSTALL_ROOT

VERSION=`python setup.py --version`
cat python-virtinst.spec.in | sed -e "s/::VERSION::/$VERSION/" > python-virtinst.spec
python setup.py sdist

if [ -f /usr/bin/rpmbuild ]; then
  if [ -n "$AUTOBUILD_COUNTER" ]; then
    EXTRA_RELEASE=".auto$AUTOBUILD_COUNTER"
  else
    NOW=`date +"%s"`
    EXTRA_RELEASE=".$USER$NOW"
  fi
  rpmbuild --define "extra_release $EXTRA_RELEASE" \
           --define "_sourcedir `pwd`/dist" \
           -ba --clean python-virtinst.spec
fi
