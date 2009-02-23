from distutils.core import setup, Command
from distutils.command.sdist import sdist as _sdist
from distutils.command.build import build as _build
from distutils.command.install_data import install_data as _install_data
from distutils.command.install_lib import install_lib as _install_lib
from distutils.command.install import install as _install
from unittest import TextTestRunner, TestLoader
from glob import glob
from os.path import splitext, basename, join as pjoin
import os, sys

pkgs = ['virtinst', 'virtconv', 'virtconv.parsers' ]

datafiles = [('share/man/man1', ['man/en/virt-install.1',
                                 'man/en/virt-clone.1',
                                 'man/en/virt-image.1',
                                 'man/en/virt-convert.1']),
             ('share/man/man5', ['man/en/virt-image.5'])]
locale = None
builddir = None

VERSION="0.400.0"

class TestBaseCommand(Command):

    user_options = [('debug', 'd', 'Show debug output')]
    boolean_options = ['debug']

    def initialize_options(self):
        self.debug = 0
        self._testfiles = []
        self._dir = os.getcwd()

    def finalize_options(self):
        if self.debug and not os.environ.has_key("DEBUG_TESTS"):
            os.environ["DEBUG_TESTS"] = "1"

    def run(self):
        import tests.coverage as coverage
        tests = TestLoader().loadTestsFromNames(self._testfiles)
        t = TextTestRunner(verbosity = 1)
        coverage.erase()
        coverage.start()
        result = t.run(tests)
        coverage.stop()
        if len(result.failures) > 0 or len(result.errors) > 0:
            sys.exit(1)
        else:
            sys.exit(0)

class TestCommand(TestBaseCommand):

    description = "Runs a quick unit test suite"

    def run(self):
        '''
        Finds all the tests modules in tests/, and runs them.
        '''
        testfiles = []
        for t in glob(pjoin(self._dir, 'tests', '*.py')):
            if not t.endswith('__init__.py') and \
               not t.endswith("urltest.py"):
                testfiles.append('.'.join(
                    ['tests', splitext(basename(t))[0]])
                )
        self._testfiles = testfiles
        TestBaseCommand.run(self)

class TestURLFetch(TestBaseCommand):

    description = "Test fetching kernels and isos from various distro trees"

    user_options = TestBaseCommand.user_options + \
                   [("match=", None, "Regular expression of dist names to "
                                     "match [default: '.*']")]

    def initialize_options(self):
        TestBaseCommand.initialize_options(self)
        self.match = None

    def finalize_options(self):
        TestBaseCommand.finalize_options(self)
        if self.match is None:
            self.match = ".*"

    def run(self):
        import tests
        self._testfiles = [ "tests.urltest" ]
        tests.urltest.MATCH_FILTER = self.match
        TestBaseCommand.run(self)

class CheckPylint(Command):
    user_options = []
    description = "Run static analysis script against codebase."

    def initialize_options(self):
        pass
    def finalize_options(self):
        pass

    def run(self):
        os.system("tests/pylint-virtinst.sh")

class custom_rpm(Command):

    user_options = []

    description = "Build a non-binary rpm."

    def initialize_options(self):
        pass

    def finalize_options(self):
        pass

    def run(self):
        """
        Run sdist, then 'rpmbuild' the tar.gz
        """
        self.run_command('sdist')
        os.system('rpmbuild -ta dist/virtinst-%s.tar.gz' % VERSION)

class sdist(_sdist):
    """ custom sdist command, to prep virtinst.spec file for inclusion """

    def run(self):
        cmd = (""" sed -e "s/::VERSION::/%s/g" < python-virtinst.spec.in """ %
               VERSION) + " > python-virtinst.spec"
        os.system(cmd)
        _sdist.run(self)

class build(_build):
    """ custom build command to compile i18n files"""

    def run(self):
        global builddir
        dirlist = os.listdir("po")

        if not os.path.exists("build/po"):
            os.makedirs("build/po")

        for filename in dirlist:
            if filename.endswith(".po"):
                lang = filename[0:len(filename)-3]
                if not os.path.exists("build/po/%s" % lang):
                    os.makedirs("build/po/%s" % lang)
                newname = "build/po/%s/virtinst.mo" % lang
                print "Building %s from %s" % (newname, filename)
                os.system("msgfmt po/%s -o %s" % (filename, newname))

        _build.run(self)
        builddir = self.build_lib


class install(_install):
    """custom install command to extract install base for locale install"""

    def finalize_options(self):
        global locale
        _install.finalize_options(self)
        locale = self.install_base + "/share/locale"


class install_lib(_install_lib):
    """ custom install_lib command to place locale location into library"""

    def run(self):
        cmd = (("""sed -e "s,::LOCALEDIR::,%s," < virtinst/__init__.py > """ %\
                locale) + "%s/virtinst/__init__.py" % builddir)
        os.system(cmd)
        _install_lib.run(self)


class install_data(_install_data):
    """ custom install_data command to prepare i18n files for install"""

    def run(self):
        dirlist = os.listdir("build/po")
        for lang in dirlist:
            if lang != "." and lang != "..":
                install_path = "share/locale/%s/LC_MESSAGES/" % lang

                src_path = "build/po/%s/virtinst.mo" % lang

                print "Installing %s to %s" % (src_path, install_path)
                toadd = (install_path, [src_path])

                # Add these to the datafiles list
                datafiles.append(toadd)
        _install_data.run(self)

setup(name='virtinst',
      version=VERSION,
      description='Virtual machine installation',
      author='Jeremy Katz, Daniel Berrange, Cole Robinson',
      author_email='crobinso@redhat.com',
      license='GPL',
      url='http://virt-manager.et.redhat.com',
      package_dir={'virtinst': 'virtinst'},
      scripts = ["virt-install","virt-clone", "virt-image", "virt-convert"],
      packages=pkgs,
      data_files = datafiles,
      cmdclass = { 'test': TestCommand, 'test_urls' : TestURLFetch,
                    'check': CheckPylint,
                    'rpm' : custom_rpm,
                    'sdist': sdist, 'build': build,
                    'install_data' : install_data,
                    'install_lib' : install_lib,
                    'install' : install}
      )
