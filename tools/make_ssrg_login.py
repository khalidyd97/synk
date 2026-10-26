"""Create the private SSRG Playables login (local/ssrg_login.json).

Usage:
    python tools/make_ssrg_login.py

Asks for a username and password and stores the username with a SHA-256 hash of the password
(never the password itself). local/ is git-ignored, so the file stays on this computer; Android
builds made here include it. Without the file, SSRG Playables opens without a login.
"""
import getpass
import hashlib
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    user = input("Username: ").strip()
    password = getpass.getpass("Password: ")
    if not user or not password:
        print("Username and password are both needed.")
        return
    os.makedirs(os.path.join(ROOT, "local"), exist_ok=True)
    path = os.path.join(ROOT, "local", "ssrg_login.json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump({"user": user, "sha256": hashlib.sha256(password.encode("utf-8")).hexdigest()}, handle)
    print("Saved %s. Rebuild the APK to include it." % path)


if __name__ == "__main__":
    main()
