#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["cyclopts", "httpx"]
# ///
"""Connect to Princeton's GlobalProtect VPN with openconnect, for campus traffic only.

The portal uses Palo Alto's cloud authentication (CAS), which openconnect can't finish
on its own: the browser sign-in ends in a short-lived token, and the portal only trades
it for a login cookie when the request carries the fields of a recent official client.
So this signs in in the browser, makes that trade, and keeps the cookie in the keychain.
openconnect then logs in to a gateway with the cookie, and each login returns a fresh
cookie to save for next time. The browser comes back only when the cookie stops working.

Routing is set up by `princeton-vpn-tunnel` (see default.nix), which runs openconnect
as root with vpn-slice, so only Princeton's address blocks go through the tunnel.
"""

import base64
import binascii
import platform
import re
import signal
import socket
import subprocess
import sys
import time
import uuid
import webbrowser
import xml.etree.ElementTree as ET
from pathlib import Path
from types import FrameType
from urllib.parse import parse_qs, unquote

import httpx
from cyclopts import App

app = App(name="princeton-vpn")

PORTAL = "vpn.princeton.edu"
CAMPUS_DOMAIN = "princeton.edu"
# from ./default.nix, run with sudo
TUNNEL = "/run/current-system/sw/bin/princeton-vpn-tunnel"

# the portal refuses cas sign-in from clients older than 6.0
CLIENT_VERSION = "6.3.3-915"
OS_VERSION = f"Apple Mac OS X {platform.mac_ver()[0]}"
USER_AGENT = f"PAN GlobalProtect/{CLIENT_VERSION} ({OS_VERSION})"

KEYCHAIN_SERVICE = "princeton-vpn"
STATE = Path.home() / ".cache" / "princeton-vpn"
LOGIN_PAGE = STATE / "login.html"
# built by ./callback, which saves the link the browser opens when sign-in finishes
CALLBACK_APP = Path.home() / "Applications" / "princeton-vpn-callback.app"
CALLBACK = STATE / "callback"
SIGN_IN_TIMEOUT_SECONDS = 300

# both end up in a `security -i` command line, so they must not contain quotes,
# spaces or newlines
NETID = re.compile(r"[a-z0-9]+@princeton\.edu")
COOKIE = re.compile(r"[A-Za-z0-9+/=]+")
FRESH_COOKIE = re.compile(
    rf"GlobalProtect login returned portal-userauthcookie=({COOKIE.pattern})\s*$"
)
# openconnect's messages when the gateway refuses the cookie, at login and later
REJECTED = ("Unexpected 512 result from server", "Cookie was rejected by server")


class CookieRejected(Exception):
    """The gateway refused the cookie."""


def run(*args: str, input: str | None = None) -> str:
    """A command's stdout, or "" if it fails."""
    result = subprocess.run(
        args,
        input=input,
        capture_output=True,
        text=True,
        check=False,
    )
    return "" if result.returncode else result.stdout.strip()


def succeeds(*args: str, input: str | None = None) -> bool:
    result = subprocess.run(
        args,
        input=input,
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode == 0


def on_campus() -> bool:
    """Whether a physical interface has a DHCP lease from the campus network."""
    return any(
        run("ipconfig", "getoption", name, "domain_name") == CAMPUS_DOMAIN
        for _, name in socket.if_nameindex()
        if name.startswith("en")
    )


def saved_login() -> tuple[str, str] | None:
    """The user and portal cookie saved in the keychain, if any."""
    attributes = run("security", "find-generic-password", "-s", KEYCHAIN_SERVICE)
    cookie = run("security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w")
    user = re.search(r'"acct"<blob>="([^"]+)"', attributes)
    return (user[1], cookie) if user and cookie else None


def save_login(user: str, cookie: str) -> None:
    # `security -i` reads the command from stdin, which keeps the cookie out of `ps`
    command = f'add-generic-password -U -s {KEYCHAIN_SERVICE} -a {user} -w "{cookie}"\n'

    if not succeeds("security", "-i", input=command):
        print("Couldn't save the login to the keychain.", file=sys.stderr)


def forget_login() -> None:
    # one at a time, in case an earlier sign-in saved another netid
    while succeeds("security", "delete-generic-password", "-s", KEYCHAIN_SERVICE):
        pass


def portal_request(
    client: httpx.Client,
    path: str,
    data: dict[str, str],
) -> ET.Element:
    try:
        response = client.post(f"https://{PORTAL}/global-protect/{path}", data=data)
        response.raise_for_status()
        return ET.fromstring(response.text)
    except (httpx.HTTPError, ET.ParseError) as error:
        sys.exit(f"Couldn't sign in with {PORTAL}: {error}")


def wait_for_callback() -> str:
    """The `globalprotectcallback:` link the callback app saves when sign-in finishes."""
    deadline = time.monotonic() + SIGN_IN_TIMEOUT_SECONDS

    while not CALLBACK.exists():
        if time.monotonic() > deadline:
            sys.exit(
                "Timed out waiting for the browser sign-in. If the browser said the "
                f"address is invalid, {CALLBACK_APP.name} isn't handling the link."
            )

        time.sleep(0.2)

    callback = CALLBACK.read_text()
    CALLBACK.unlink()
    return callback


def browser_sign_in(client: httpx.Client) -> tuple[str, str]:
    """The netid and the one-minute cas token from a sign-in in the default browser."""
    if not CALLBACK_APP.exists():
        sys.exit(f"{CALLBACK_APP} is missing. Run darwin-rebuild switch.")

    prelogin = portal_request(
        client,
        "prelogin.esp?tmp=tmp&clientVer=4100&clientos=Mac",
        {"cas-support": "yes", "default-browser": "1", "clientos": "Mac"},
    )

    try:
        login_page = base64.b64decode(
            prelogin.findtext("saml-request") or "", validate=True
        )
    except binascii.Error:
        login_page = b""

    if prelogin.findtext("saml-auth-method") != "POST" or not login_page:
        reason = prelogin.findtext("msg") or "no reason given"
        sys.exit(f"{PORTAL} didn't offer a browser sign-in: {reason}.")

    # the saml request is a self-submitting form, so open it from a file
    STATE.mkdir(parents=True, exist_ok=True)
    STATE.chmod(0o700)
    CALLBACK.unlink(missing_ok=True)
    LOGIN_PAGE.write_bytes(login_page)

    if not webbrowser.open(LOGIN_PAGE.as_uri()):
        sys.exit("Couldn't open the browser.")

    print("Finish the sign-in in the browser.")

    try:
        callback = wait_for_callback()
    finally:
        LOGIN_PAGE.unlink(missing_ok=True)

    query = callback.removeprefix("globalprotectcallback:")
    # some browsers hand over the whole query percent-encoded
    fields = parse_qs(query if "=" in query else unquote(query))
    user = fields.get("un", [""])[0].lower()

    if not (NETID.fullmatch(user) and fields.get("token")):
        sys.exit("The sign-in didn't return a Princeton netid and token.")

    return user, fields["token"][0]


def sign_in() -> tuple[str, str]:
    """Sign in in the browser and save the portal cookie the token is traded for."""
    with httpx.Client(headers={"User-Agent": USER_AGENT}, timeout=30) as client:
        user, token = browser_sign_in(client)
        # what gpclient sends. the portal rejects the token without these
        config = portal_request(
            client,
            "getconfig.esp",
            {
                "user": user,
                "passwd": "",
                "prelogin-cookie": "",
                "portal-userauthcookie": "",
                "portal-prelogonuserauthcookie": "",
                "token": token,
                "inputStr": "",
                "ok": "Login",
                "clientVer": "4100",
                "clientos": "Mac",
                "clientgpversion": CLIENT_VERSION,
                "computer": socket.gethostname().split(".")[0],
                "os-version": OS_VERSION,
                "host-id": ":".join(re.findall("..", f"{uuid.getnode():012x}")),
                "ipv6-support": "yes",
                "serialno": "",
                "csc-digest": "",
                "config-digest": "",
                "csc-support": "no",
                "host": PORTAL,
                "swg-auth-token": "0",
                "swg-nonce": "0",
            },
        )

    cookie = config.findtext(".//portal-userauthcookie") or ""

    if not COOKIE.fullmatch(cookie):
        sys.exit(f"{PORTAL} didn't return a usable login cookie.")

    forget_login()
    save_login(user, cookie)
    return user, cookie


def stop(signum: int, frame: FrameType | None) -> None:
    sys.exit(128 + signum)


def tunnel(user: str, cookie: str) -> int:
    """Run openconnect until it exits, saving each fresh cookie."""
    # ctrl-c reaches openconnect through the terminal, so keep reading while it tears
    # the tunnel down instead of exiting first. a handler, unlike SIG_IGN, isn't
    # inherited. on other signals, exit through the cleanup below
    handlers = {
        signal.SIGINT: signal.signal(signal.SIGINT, lambda *_: None),
        signal.SIGTERM: signal.signal(signal.SIGTERM, stop),
        signal.SIGHUP: signal.signal(signal.SIGHUP, stop),
    }
    process = subprocess.Popen(
        ["sudo", TUNNEL, user],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    rejected = False

    try:
        assert process.stdin and process.stdout
        process.stdin.write(f"{cookie}\n")
        process.stdin.close()

        # openconnect prints the fresh cookie with its progress messages
        for line in process.stdout:
            if fresh := FRESH_COOKIE.search(line):
                save_login(user, fresh[1])
                continue

            rejected = rejected or any(message in line for message in REJECTED)
            print(line, end="")

        process.wait()
    finally:
        for signum, handler in handlers.items():
            signal.signal(signum, handler)

        # don't leave a root tunnel running without anyone watching it
        if process.poll() is None:
            process.terminate()
            process.wait()

    if process.returncode and rejected:
        raise CookieRejected

    return process.returncode


@app.default
def princeton_vpn(*, sign_in_again: bool = False, on_campus_too: bool = False):
    """Connect to Princeton's VPN, routing only campus addresses through it.

    Ctrl-C disconnects.

    Parameters
    ----------
    sign_in_again
        Use the browser sign-in even if a login is saved.
    on_campus_too
        Connect even on the campus network, e.g. with a Tailscale exit node on.
    """
    if on_campus() and not on_campus_too:
        sys.exit(
            "Already on the campus network. Pass --on-campus-too to connect anyway."
        )

    if not sign_in_again and (saved := saved_login()):
        try:
            sys.exit(tunnel(*saved))
        except CookieRejected:
            print("The saved login has expired. Signing in again.")

    try:
        sys.exit(tunnel(*sign_in()))
    except CookieRejected:
        sys.exit("The gateway rejected a fresh login.")


if __name__ == "__main__":
    app()
