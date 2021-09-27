from setuptools import setup, find_packages
from Cython.Build import cythonize

setup(
    name = "POT",
    ext_modules = cythonize("*.pyx"),
    packages = find_packages(),
    package_dir = {"POT":""}
)
