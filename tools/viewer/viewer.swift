// webkit window for local preview servers (typst-preview, notebooks, ...) and pdfs
//
// usage: viewer <url-or-file>...
// build.sh builds viewer.app and a viewer command that passes documents to
// the running app with `open`. the window shows one document at a time, and a
// pill of buttons along the bottom switches between them

import AppKit
import PDFKit
import WebKit

// one open document
final class Page: NSObject, WKNavigationDelegate, WKUIDelegate {
	let url: URL
	var title: String
	let view: NSView
	var watcher: Timer?
	var titleObservation: NSKeyValueObservation?
	unowned let delegate: Delegate

	init(url: URL, delegate: Delegate) {
		self.url = url
		self.delegate = delegate
		title = url.isFileURL ? url.lastPathComponent : url.absoluteString

		// pdfkit rather than webkit, whose pdf viewer has a floating toolbar
		if url.isFileURL, let document = PDFDocument(url: url) {
			let pdfView = PDFView()
			pdfView.document = document
			pdfView.autoScales = true
			// match the web pages: no grey backdrop or margins, and extend under
			// the titlebar instead of leaving a gap for it
			pdfView.displaysPageBreaks = false
			pdfView.backgroundColor = .white
			pdfView.documentView?.enclosingScrollView?.automaticallyAdjustsContentInsets = false
			view = pdfView
		} else {
			view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
		}
		view.autoresizingMask = [.width, .height]
		super.init()

		guard let webView = view as? WKWebView else { return }
		webView.navigationDelegate = self
		webView.uiDelegate = self
		webView.isInspectable = true // right click > inspect element

		// label the button after the page
		titleObservation = webView.observe(\.title) { [weak self] webView, _ in
			guard let self, let title = webView.title, !title.isEmpty else { return }
			self.title = title
			delegate.updateButtons()
		}
		load()
	}

	deinit { watcher?.invalidate() }

	// also used when the document is opened again, e.g. after recompiling a pdf
	// or restarting a server that wasn't up the first time
	func load() {
		if let pdfView = view as? PDFView {
			pdfView.document = PDFDocument(url: url)
		} else if let webView = view as? WKWebView {
			if url.isFileURL {
				webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
			} else {
				webView.load(URLRequest(url: url))
			}
		}
	}

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

	// window.close() from the page (e.g. :MarkdownPreviewStop)
	func webViewDidClose(_ webView: WKWebView) { delegate.close(self) }

	// once loaded, close when the server goes away (e.g. :TypstPreviewStop)
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		// the error page below also finishes loading, so check the host
		guard watcher == nil, !url.isFileURL, webView.url?.host == url.host else { return }
		var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 1)
		request.httpMethod = "HEAD"
		watcher = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
			URLSession.shared.dataTask(with: request) { _, _, error in
				if (error as? URLError)?.code == .cannotConnectToHost {
					DispatchQueue.main.async { if let self { self.delegate.close(self) } }
				}
			}.resume()
		}
	}

	// the title is hidden, so show errors in the page
	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		webView.loadHTMLString("<pre>\(url.absoluteString)\n\(error.localizedDescription)</pre>", baseURL: nil)
	}
}

// takes the click even when the window isn't focused
final class Button: NSButton {
	override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class Delegate: NSObject, NSApplicationDelegate {
	var window: NSWindow!
	var pages: [Page] = []
	var current: Page?
	let pill = NSGlassEffectView()
	let buttons = NSStackView()
	// resets a pdf zoomed with a pinch. only shown when zoomed
	let zoom = NSGlassEffectView()
	// the pill makes room for the zoom button while it shows
	var pillTrailing: NSLayoutConstraint!
	var zoomShown = false

	func applicationWillFinishLaunching(_ notification: Notification) {
		window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 800, height: 1000),
			// the page extends under the transparent titlebar
			styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
			backing: .buffered,
			defer: false
		)
		// the window is held by `window`, so appkit mustn't release it too
		window.isReleasedWhenClosed = false
		window.titleVisibility = .hidden
		window.titlebarAppearsTransparent = true

		// the traffic lights cover content, so hide them and close with cmd-w
		for button in [.closeButton, .miniaturizeButton, .zoomButton] as [NSWindow.ButtonType] {
			window.standardWindowButton(button)?.isHidden = true
		}
		let item = NSMenuItem()
		item.submenu = NSMenu()
		item.submenu?.addItem(withTitle: "Close", action: #selector(closeCurrent(_:)), keyEquivalent: "w")
		// cmd-[ and cmd-], and cmd-shift-[ and cmd-shift-] as for tabs elsewhere
		for (key, step) in [("[", -1), ("]", 1), ("{", -1), ("}", 1)] {
			item.submenu?.addItem(withTitle: "", action: #selector(cycle(_:)), keyEquivalent: key).tag = step
		}
		item.submenu?.addItem(withTitle: "Actual Size", action: #selector(resetZoom(_:)), keyEquivalent: "0")
		NSApp.mainMenu = NSMenu()
		NSApp.mainMenu?.addItem(item)
		// macos routes the window tiling shortcuts (fn-ctrl-arrows) through the window menu
		NSApp.windowsMenu = item.submenu

		// remember size and position between launches
		if !window.setFrameUsingName("viewer") { window.center() }
		window.setFrameAutosaveName("viewer")

		pill.contentView = buttons
		buttons.distribution = .fillEqually
		// the gaps pad each title, with the separators in the middle of them
		buttons.spacing = 28
		buttons.edgeInsets = NSEdgeInsets(top: 3, left: 17, bottom: 3, right: 17)

		let reset = Button(
			image: NSImage(systemSymbolName: "1.magnifyingglass", accessibilityDescription: "Actual Size")!,
			target: self,
			action: #selector(resetZoom(_:))
		)
		reset.isBordered = false
		reset.contentTintColor = .secondaryLabelColor
		zoom.contentView = reset
		zoom.alphaValue = 0
		zoom.isHidden = true
		NotificationCenter.default.addObserver(forName: .PDFViewScaleChanged, object: nil, queue: .main) { [weak self] _ in
			self?.updateZoom()
		}

		let content = NSView()
		window.contentView = content
		for glass in [pill, zoom] {
			glass.cornerRadius = 14
			glass.translatesAutoresizingMaskIntoConstraints = false
			content.addSubview(glass)
			NSLayoutConstraint.activate([
				glass.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
				glass.heightAnchor.constraint(equalToConstant: 28),
			])
		}
		pillTrailing = pill.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12)
		NSLayoutConstraint.activate([
			pillTrailing,
			pill.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
			zoom.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
			zoom.widthAnchor.constraint(equalToConstant: 28),
		])
	}

	// documents passed at launch arrive before this
	func applicationDidFinishLaunching(_ notification: Notification) {
		if pages.isEmpty { NSApp.terminate(nil) }
	}

	func application(_ application: NSApplication, open urls: [URL]) {
		for url in urls {
			if let page = pages.first(where: { $0.url == url }) {
				page.load()
				show(page)
			} else {
				let page = Page(url: url, delegate: self)
				pages.append(page)
				show(page)
			}
		}
		// show without activating so focus stays in the editor
		window.orderFrontRegardless()
	}

	func show(_ page: Page) {
		guard page !== current else { return }
		current?.view.removeFromSuperview()
		current = page
		let content = window.contentView!
		content.addSubview(page.view, positioned: .below, relativeTo: nil)
		page.view.frame = content.bounds
		// so arrow keys and space scroll without clicking into the page first
		window.makeFirstResponder(page.view)
		updateButtons()
		updateZoom()
	}

	func close(_ page: Page) {
		guard let index = pages.firstIndex(where: { $0 === page }) else { return }
		pages.remove(at: index)
		if pages.isEmpty { NSApp.terminate(nil); return }
		if page === current { show(pages[min(index, pages.count - 1)]) } else { updateButtons() }
	}

	// equal width buttons, one per page, with the others dimmed. the pill only
	// shows when there's something to switch to
	func updateButtons() {
		buttons.subviews.forEach { $0.removeFromSuperview() }
		for (index, page) in pages.enumerated() {
			let button = Button(title: page.title, target: self, action: #selector(select(_:)))
			button.tag = index
			button.isBordered = false
			button.lineBreakMode = .byTruncatingTail
			button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
			button.contentTintColor = page === current ? .labelColor : .tertiaryLabelColor
			buttons.addArrangedSubview(button)

			if index > 0 {
				let separator = NSBox()
				separator.boxType = .separator
				separator.translatesAutoresizingMaskIntoConstraints = false
				buttons.addSubview(separator)
				NSLayoutConstraint.activate([
					separator.centerXAnchor.constraint(equalTo: button.leadingAnchor, constant: -14),
					separator.centerYAnchor.constraint(equalTo: buttons.centerYAnchor),
					separator.widthAnchor.constraint(equalToConstant: 1),
					separator.heightAnchor.constraint(equalToConstant: 16),
				])
			}
		}
		pill.isHidden = pages.count < 2
		window.title = current?.title ?? "" // hidden, but still shown in mission control
	}

	// a pinch turns off fitting the pdf to the window. the button fades in as
	// the pill shrinks to make room
	func updateZoom() {
		let zoomed = (current?.view as? PDFView)?.autoScales == false
		guard zoomed != zoomShown else { return }
		zoomShown = zoomed
		zoom.isHidden = false
		NSAnimationContext.runAnimationGroup { context in
			context.duration = 0.2
			// the button is 28 wide, with 8 between it and the pill
			pillTrailing.animator().constant = zoomed ? -48 : -12
			zoom.animator().alphaValue = zoomed ? 1 : 0
		} completionHandler: { [self] in
			zoom.isHidden = !zoomShown
		}
	}

	@objc func select(_ sender: NSButton) { show(pages[sender.tag]) }

	@objc func resetZoom(_ sender: Any?) {
		(current?.view as? PDFView)?.autoScales = true
		updateZoom()
	}

	@objc func closeCurrent(_ sender: Any?) {
		if let current { close(current) }
	}

	@objc func cycle(_ sender: NSMenuItem) {
		guard let index = pages.firstIndex(where: { $0 === current }) else { return }
		show(pages[(index + sender.tag + pages.count) % pages.count])
	}
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // no dock icon or cmd-tab entry
app.run()
