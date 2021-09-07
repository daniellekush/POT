from setuptools import setup
from Cython.Build import cythonize

setup(
    name = "POT_Engine",
    ext_modules = cythonize("*.pyx")
)
