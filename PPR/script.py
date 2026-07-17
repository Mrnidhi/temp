"""Install the libraries the PPR notebook needs. Real install, real progress.
Run:  python setup_env.py
"""
import subprocess, sys

PACKAGES = ["numpy", "pandas", "scikit-learn", "matplotlib", "openpyxl"]

def main():
    print("Setting up the Python environment for the PPR dashboard work.\n")
    for pkg in PACKAGES:
        print(f"==> installing {pkg} ...")
        rc = subprocess.call([sys.executable, "-m", "pip", "install", "-v", pkg])
        if rc != 0:
            print(f"!! {pkg} failed (exit {rc}). Fix this before continuing.")
            sys.exit(rc)
    print("\nAll set. Verifying imports:")
    import importlib
    for mod in ["numpy", "pandas", "sklearn", "matplotlib", "openpyxl"]:
        m = importlib.import_module(mod)
        print(f"  {mod:14s} {getattr(m, '__version__', 'ok')}")
    print("\nEnvironment ready.")

if __name__ == "__main__":
    main()