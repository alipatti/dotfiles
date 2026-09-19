// minimal webkit window for local preview servers (typst-preview, notebooks, ...)
//
// usage: webview <url>
// build: swiftc -O macos/webview.swift -o ~/.local/bin/webview

import AppKit
import WebKit

final class Delegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
	let url: URL
	var window: NSWindow!
	var webView: WKWebView!
	var watcher: Timer?

	init(url: URL) {
		self.url = url
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
		webView.navigationDelegate = self
		webView.uiDelegate = self
		webView.isInspectable = true // right click > inspect element

		window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 800, height: 1000),
			// the page extends under the transparent titlebar
			styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
			backing: .buffered,
			defer: false
		)
		window.title = url.absoluteString // hidden, but still shown in mission control
		window.titleVisibility = .hidden
		window.titlebarAppearsTransparent = true
		window.contentView = webView

		// the traffic lights cover content, so hide them and close with cmd-w
		for button in [.closeButton, .miniaturizeButton, .zoomButton] as [NSWindow.ButtonType] {
			window.standardWindowButton(button)?.isHidden = true
		}
		let item = NSMenuItem()
		item.submenu = NSMenu()
		item.submenu?.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
		NSApp.mainMenu = NSMenu()
		NSApp.mainMenu?.addItem(item)

		// remember size and position between launches
		if !window.setFrameUsingName("webview") { window.center() }
		window.setFrameAutosaveName("webview")

		webView.load(URLRequest(url: url))

		// show without activating so focus stays in the editor
		window.orderFrontRegardless()
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

	// links that want a new window go to the default browser
	func webView(
		_ webView: WKWebView,
		createWebViewWith configuration: WKWebViewConfiguration,
		for navigationAction: WKNavigationAction,
		windowFeatures: WKWindowFeatures
	) -> WKWebView? {
		if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
		return nil
	}

	// once loaded, quit when the server goes away (e.g. :TypstPreviewStop)
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		// the error page below also finishes loading, so check the host
		guard watcher == nil, webView.url?.host == url.host else { return }
		var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 1)
		request.httpMethod = "HEAD"
		watcher = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
			URLSession.shared.dataTask(with: request) { _, _, error in
				if (error as? URLError)?.code == .cannotConnectToHost { exit(0) }
			}.resume()
		}
	}

	// the title is hidden, so show errors in the page
	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		let message = "\(url.absoluteString)\n\(error.localizedDescription)"
		fputs("webview: \(message)\n", stderr)
		webView.loadHTMLString("<pre>\(message)</pre>", baseURL: nil)
	}
}

guard CommandLine.arguments.count == 2,
	let url = URL(string: CommandLine.arguments[1]),
	url.scheme != nil
else {
	fputs("usage: webview <url>\n", stderr)
	exit(64)
}

let app = NSApplication.shared
let delegate = Delegate(url: url)
app.delegate = delegate
app.setActivationPolicy(.accessory) // no dock icon or cmd-tab entry
app.run()
