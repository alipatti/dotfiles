// sign in to a site in a private webkit window and print its cookies as json.
// the window starts invisible and only appears after --show-after seconds, in case
// the stored sso session gets through on its own. in practice princeton's entra
// asks for the password again on each sign-in, so expect the window.
//
// usage: sso-cookie URL COOKIE [--show-after SECONDS] [--timeout SECONDS]
// prints {"name": "value", ...} for every cookie on the host that set COOKIE.
// SSO_DEBUG=1 logs each page, its cookies and text to stderr.
// build: /usr/bin/swiftc -O sso-cookie.swift -o sso-cookie
// e.g. sso-cookie https://princeton.instructure.com/login/saml canvas_session

import AppKit
import WebKit

var args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String, _ fallback: Double) -> Double {
	guard let i = args.firstIndex(of: name), i + 1 < args.count else { return fallback }
	let value = Double(args[i + 1]) ?? fallback
	args.removeSubrange(i...i + 1)
	return value
}
let showAfter = option("--show-after", 4)
let timeout = option("--timeout", 300)
guard args.count == 2, let parsed = URL(string: args[0]) else {
	FileHandle.standardError.write("usage: sso-cookie URL COOKIE [--show-after S] [--timeout S]\n".data(using: .utf8)!)
	exit(2)
}
let wanted = args[1]
nonisolated(unsafe) let start: URL = parsed

// fixed id: a store separate from safari's that survives between runs
let store = WKWebsiteDataStore(forIdentifier: UUID(uuidString: "6E0B5C1A-3F0D-4C55-9C3B-5A0C0D5E5150")!)

final class Delegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
	var window: NSWindow!
	var web: WKWebView!

	func applicationDidFinishLaunching(_ notification: Notification) {
		let config = WKWebViewConfiguration()
		config.websiteDataStore = store
		web = WKWebView(frame: NSRect(x: 0, y: 0, width: 520, height: 720), configuration: config)
		web.navigationDelegate = self
		window = NSWindow(
			contentRect: web.frame,
			styleMask: [.titled, .closable, .resizable],
			backing: .buffered,
			defer: false
		)
		window.contentView = web
		window.title = "sign in: \(start.host ?? "")"
		window.center()
		// webkit suspends javascript in windows that were never shown, and the sso
		// pages need it to post back, so start on screen but invisible
		window.alphaValue = 0
		window.ignoresMouseEvents = true
		window.orderFrontRegardless()
		web.load(URLRequest(url: start))

		// only bother the user if the stored sso session didn't get us through
		DispatchQueue.main.asyncAfter(deadline: .now() + showAfter) { self.show() }
		DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
			FileHandle.standardError.write("timed out waiting for \(wanted)\n".data(using: .utf8)!)
			exit(1)
		}
		Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
			self.advance(self.web)
			self.check()
		}
	}

	func show() {
		NSApp.setActivationPolicy(.regular)
		window.alphaValue = 1
		window.ignoresMouseEvents = false
		window.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		if ProcessInfo.processInfo.environment["SSO_DEBUG"] != nil {
			let u = webView.url
			FileHandle.standardError.write("loaded \(u?.host ?? "")\(u?.path ?? "")\n".data(using: .utf8)!)
			store.httpCookieStore.getAllCookies { cookies in
				let names = cookies.map { "\($0.domain):\($0.name)\($0.isSessionOnly ? "(session)" : "")" }.sorted()
				FileHandle.standardError.write("  cookies: \(names.joined(separator: " "))\n".data(using: .utf8)!)
			}
			webView.evaluateJavaScript("document.body.innerText.slice(0, 400)") { text, _ in
				FileHandle.standardError.write("  text: \((text as? String ?? "").replacingOccurrences(of: "\n", with: " | "))\n".data(using: .utf8)!)
			}
		}
		advance(webView)
		check()
	}

	// entra's "pick an account" waits for a click even with one signed-in
	// account, which would otherwise stop every silent refresh
	func advance(_ webView: WKWebView) {
		guard webView.url?.host == "login.microsoftonline.com" else { return }
		webView.evaluateJavaScript("""
			(() => {
				const tiles = [...document.querySelectorAll('[role=button][data-test-id*="@"]')]
					.filter(e => !e.dataset.testId.endsWith('-menu-dots'));
				if (tiles.length === 1) tiles[0].click();
				return tiles.length + ' ' + location.pathname + ' ' + document.body.innerText.slice(0, 300).replace(/\\s+/g, ' ');
			})()
			""") { n, error in
			if ProcessInfo.processInfo.environment["SSO_DEBUG"] != nil {
				FileHandle.standardError.write("  advance: \(String(describing: n)) \(String(describing: error))\n".data(using: .utf8)!)
			}
		}
	}

	func check() {
		// canvas etc. set their session cookie before sign-in too, so also wait to
		// land back on the start host outside its login pages
		guard let url = web.url, let host = url.host, host == start.host,
			!url.path.lowercased().contains("login")
		else { return }
		store.httpCookieStore.getAllCookies { cookies in
			let onHost = cookies.filter { host.hasSuffix($0.domain.trimmingCharacters(in: ["."])) }
			guard onHost.contains(where: { $0.name == wanted }) else { return }
			var out: [String: String] = [:]
			for c in onHost { out[c.name] = c.value }
			let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
			FileHandle.standardOutput.write(data + "\n".data(using: .utf8)!)
			exit(0)
		}
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// cmd-c/v/x/a/z only reach the web view through an edit menu
func mainMenu() -> NSMenu {
	let edit = NSMenu(title: "Edit")
	edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
	edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
	edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
	edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
	edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
	let app = NSMenu()
	app.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
	let menu = NSMenu()
	for sub in [app, edit] {
		let item = NSMenuItem()
		item.submenu = sub
		menu.addItem(item)
	}
	return menu
}

let delegate = Delegate()
NSApplication.shared.mainMenu = mainMenu()
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
