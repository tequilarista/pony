__author__ = 'tara.hernandez'
import os
from setuptools import setup
from setuptools import setup, find_packages

#
# Only used this for my local pypi server, I don't currently push this to the public pypi
#
 
def read(fname):
    return open(os.path.join(os.path.dirname(__file__), fname)).read()
 
setup(
    name = "pony_script",
    version = "0.3.1",
    author = "Tara Hernandez",
    author_email = "tequilarista@gmail.com",
    scripts = ['pony'],
    description = ("Log interrupts"),
    license = "BSD",
    keywords = "workflow",
    url = "http://pypi.yourcompany.com:8080/simple",
    install_requires = ['jira'],
    packages = find_packages(exclude=["*.tests", "*.tests.*", "tests.*", "tests"]),
    package_data={
        '': [
		'README.md'
	    ]
        },
    # TODO: make it work later
    # long_description=read('README.md')
)
