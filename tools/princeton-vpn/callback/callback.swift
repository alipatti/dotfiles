// receives the globalprotectcallback: link the browser opens at the end of the
// vpn sign-in, and leaves it where princeton-vpn is waiting for it

import AppKit

let state = FileManager.default.homeDirectoryForCurrentUser
	.appending(path: ".cache/princeton-vpn")

final class Delegate: NSObject, NSApplicationDelegate {
	func application(_ application: NSApplication, open urls: [URL]) {
		try? FileManager.default.createDirectory(
			at: state,
			withIntermediateDirectories: true,
			attributes: [.posixPermissions: 0o700]
		)

		for url in urls {
			// atomic, so princeton-vpn never reads half a link
			try? Data(url.absoluteString.utf8).write(
				to: state.appending(path: "callback"),
				options: [.atomic]
			)
		}

		NSApp.terminate(nil)
	}

	// opened by hand rather than with a link
	func applicationDidFinishLaunching(_ notification: Notification) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 5) { NSApp.terminate(nil) }
	}
}

let delegate = Delegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
