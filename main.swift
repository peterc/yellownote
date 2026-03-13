import Cocoa

// Load Chicago font from bundle directory
private var chicagoRegistered = false

func loadChicagoFont(size: CGFloat) -> NSFont {
    if !chicagoRegistered {
        let fontPath = (Bundle.main.resourcePath ?? (CommandLine.arguments[0] as NSString).deletingLastPathComponent) + "/ChicagoFLF.ttf"
        let fontURL = URL(fileURLWithPath: fontPath) as CFURL
        CTFontManagerRegisterFontsForURL(fontURL, .process, nil)
        chicagoRegistered = true
    }
    return NSFont(name: "ChicagoFLF", size: size) ?? NSFont.systemFont(ofSize: size)
}

// Classic Mac OS title bar with pinstripes, close box, and centered title
class ClassicTitleBar: NSView {
    var title: String = "Untitled"
    private var closeBoxHighlighted = false
    private var isShaded = false
    private var unshadedHeight: CGFloat = 0
    private let titleBarHeight: CGFloat = 20
    private let closeBoxSize: CGFloat = 11
    private let closeBoxMargin: CGFloat = 8

    private var closeBoxRect: NSRect {
        NSRect(
            x: closeBoxMargin,
            y: (bounds.height - closeBoxSize) / 2,
            width: closeBoxSize,
            height: closeBoxSize
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        // Title bar background
        NSColor(red: 0xF8/255, green: 0xE8/255, blue: 0x78/255, alpha: 1).setFill()
        bounds.fill()

        // Close box defines the vertical stripe range
        let cbr = closeBoxRect
        let stripeTop = cbr.maxY
        let stripeBottom = cbr.minY

        // Measure title for gap
        let font = loadChicagoFont(size: 12)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let titleSize = (title as NSString).size(withAttributes: attrs)
        let titleGapLeft = (bounds.width - titleSize.width) / 2 - 6
        let titleGapRight = (bounds.width + titleSize.width) / 2 + 6

        // Close box gap (slightly wider than the box itself)
        let closeGapLeft = cbr.minX - 3
        let closeGapRight = cbr.maxX + 3

        // Draw horizontal pinstripes only within close box vertical range
        NSColor.black.setStroke()
        let stripeSpacing: CGFloat = 2
        var y = stripeBottom
        while y <= stripeTop {
            let path = NSBezierPath()
            path.lineWidth = 1

            // Left of close box gap
            if closeGapLeft > 1 {
                path.move(to: NSPoint(x: 3, y: y + 0.5))
                path.line(to: NSPoint(x: closeGapLeft, y: y + 0.5))
            }

            // Between close box and title gap
            path.move(to: NSPoint(x: closeGapRight, y: y + 0.5))
            path.line(to: NSPoint(x: titleGapLeft, y: y + 0.5))

            // After title gap to right edge
            path.move(to: NSPoint(x: titleGapRight, y: y + 0.5))
            path.line(to: NSPoint(x: bounds.maxX - 3, y: y + 0.5))

            path.stroke()
            y += stripeSpacing
        }

        // Draw close box (no white fill — stripes are already absent in this area)
        NSColor.black.setStroke()
        let boxPath = NSBezierPath(rect: cbr)
        boxPath.lineWidth = 1
        boxPath.stroke()

        if closeBoxHighlighted {
            let inset = cbr.insetBy(dx: 2, dy: 2)
            let xPath = NSBezierPath()
            xPath.move(to: NSPoint(x: inset.minX, y: inset.minY))
            xPath.line(to: NSPoint(x: inset.maxX, y: inset.maxY))
            xPath.move(to: NSPoint(x: inset.maxX, y: inset.minY))
            xPath.line(to: NSPoint(x: inset.minX, y: inset.maxY))
            xPath.lineWidth = 1.5
            xPath.stroke()
        }

        // Draw title text centered
        let attrs2: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
        ]
        let titleSize2 = (title as NSString).size(withAttributes: attrs2)
        let titlePoint = NSPoint(
            x: (bounds.width - titleSize2.width) / 2,
            y: (bounds.height - titleSize2.height) / 2
        )
        (title as NSString).draw(at: titlePoint, withAttributes: attrs2)

        // Outer border at bottom
        let borderPath = NSBezierPath()
        borderPath.move(to: NSPoint(x: 0, y: 0.5))
        borderPath.line(to: NSPoint(x: bounds.width, y: 0.5))
        borderPath.lineWidth = 1
        NSColor.black.setStroke()
        borderPath.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if closeBoxRect.insetBy(dx: -2, dy: -2).contains(loc) {
            closeBoxHighlighted = true
            needsDisplay = true
            return
        }
        if event.clickCount == 2 {
            toggleWindowShade()
            return
        }
        window?.performDrag(with: event)
    }

    private func setSiblingsHidden(_ hidden: Bool) {
        guard let siblings = superview?.subviews else { return }
        for view in siblings where view !== self {
            view.isHidden = hidden
        }
    }

    private func toggleWindowShade() {
        guard let win = window else { return }
        let frame = win.frame
        if isShaded {
            // Expand: grow downward from top edge
            let newFrame = NSRect(
                x: frame.origin.x,
                y: frame.origin.y - (unshadedHeight - frame.height),
                width: frame.width,
                height: unshadedHeight
            )
            win.setFrame(newFrame, display: true, animate: false)
            setSiblingsHidden(false)
            isShaded = false
        } else {
            // Collapse: shrink up to just the title bar + border
            unshadedHeight = frame.height
            setSiblingsHidden(true)
            let shadedHeight: CGFloat = titleBarHeight + 2  // +2 for border
            let newFrame = NSRect(
                x: frame.origin.x,
                y: frame.origin.y + (frame.height - shadedHeight),
                width: frame.width,
                height: shadedHeight
            )
            win.setFrame(newFrame, display: true, animate: false)
            isShaded = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        if closeBoxHighlighted {
            let loc = convert(event.locationInWindow, from: nil)
            if closeBoxRect.insetBy(dx: -2, dy: -2).contains(loc) {
                NSApp.terminate(nil)
            }
            closeBoxHighlighted = false
            needsDisplay = true
        }
    }
}

class ResizeHandle: NSView {
    private var initialMouseLocation = NSPoint.zero
    private var initialFrame = NSRect.zero

    private var trackingArea: NSTrackingArea?

    private var resizeCursor: NSCursor {
        if #available(macOS 15.0, *) {
            return NSCursor.frameResize(position: .bottomRight, directions: .all)
        }
        return .crosshair
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        resizeCursor.push()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        initialFrame = window!.frame
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let dx = current.x - initialMouseLocation.x
        let dy = current.y - initialMouseLocation.y
        let newWidth = min(1024, max(250, initialFrame.width + dx))
        let newHeight = min(1024, max(250, initialFrame.height - dy))
        let newY = initialFrame.origin.y + (initialFrame.height - newHeight)
        let newOrigin = NSPoint(x: initialFrame.origin.x, y: newY)
        window?.setFrame(NSRect(x: newOrigin.x, y: newOrigin.y, width: newWidth, height: newHeight), display: true)
        UserDefaults.standard.set(NSStringFromRect(window!.frame), forKey: "windowFrame")
    }

    override func draw(_ dirtyRect: NSRect) {
        // Classic Mac OS resize grip: small lines at bottom-right
        NSColor.black.setStroke()
        let path = NSBezierPath()
        for i in 0..<3 {
            let offset = CGFloat(i) * 4 + 2
            path.move(to: NSPoint(x: bounds.maxX - offset, y: bounds.minY))
            path.line(to: NSPoint(x: bounds.maxX, y: bounds.minY + offset))
        }
        path.lineWidth = 1
        path.stroke()
    }
}

class ContentView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Prioritize the resize handle over the scroll view
        for sub in subviews.reversed() {
            if sub is ResizeHandle {
                let local = sub.convert(point, from: self)
                if sub.bounds.contains(local) { return sub }
            }
        }
        return super.hitTest(point)
    }
}

class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

let noteFilePath: String = {
    let icloud = NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs"
    return icloud + "/YellowNote.txt"
}()

class NoteStorage {
    private var saveTimer: DispatchSourceTimer?
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var lastSavedContents: String = ""
    private var isSaving = false
    weak var textView: NSTextView?

    func load() -> String {
        guard FileManager.default.fileExists(atPath: noteFilePath),
              let contents = try? String(contentsOfFile: noteFilePath, encoding: .utf8) else {
            return ""
        }
        lastSavedContents = contents
        return contents
    }

    func scheduleSave(text: String) {
        saveTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0)
        timer.setEventHandler { [weak self] in
            self?.save(text: text)
        }
        timer.resume()
        saveTimer = timer
    }

    private func save(text: String) {
        guard text != lastSavedContents else { return }
        isSaving = true
        lastSavedContents = text
        try? text.write(toFile: noteFilePath, atomically: true, encoding: .utf8)
        isSaving = false
    }

    func startWatching() {
        let fd = open(noteFilePath, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self = self, !self.isSaving else { return }
            guard let contents = try? String(contentsOfFile: noteFilePath, encoding: .utf8),
                  contents != self.lastSavedContents else { return }
            self.lastSavedContents = contents
            self.textView?.string = contents
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatcher = source
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSTextStorageDelegate {
    var window: NSWindow!
    let storage = NoteStorage()
    var textView: NSTextView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.hasShadow = false
        window.backgroundColor = NSColor(red: 0xF8/255, green: 0xE8/255, blue: 0x78/255, alpha: 1)
        let content = ContentView()
        window.contentView = content
        content.wantsLayer = true
        content.layer?.cornerRadius = 0

        // Draw a 1px black border around the entire window
        content.layer?.borderWidth = 1
        content.layer?.borderColor = NSColor.black.cgColor

        // Title bar
        let titleBar = ClassicTitleBar()
        titleBar.title = "YellowNote"
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(titleBar)

        // Editable text area
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerKnobStyle = .dark

        textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.font = loadChicagoFont(size: 12)
        textView.textColor = .black
        textView.backgroundColor = NSColor(red: 0xF8/255, green: 0xE8/255, blue: 0x78/255, alpha: 1)
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        window.contentView!.addSubview(scrollView)

        // Load saved content
        textView.string = storage.load()
        storage.textView = textView
        textView.textStorage?.delegate = self

        // Create the file if it doesn't exist, then start watching
        if !FileManager.default.fileExists(atPath: noteFilePath) {
            try? "".write(toFile: noteFilePath, atomically: true, encoding: .utf8)
        }
        storage.startWatching()

        // Resize handle
        let resizeHandle = ResizeHandle()
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(resizeHandle)

        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 20),

            scrollView.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 1),
            scrollView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -1),
            scrollView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -17),

            resizeHandle.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            resizeHandle.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            resizeHandle.widthAnchor.constraint(equalTo: window.contentView!.widthAnchor),
            resizeHandle.heightAnchor.constraint(equalToConstant: 16),
        ])

        if let saved = UserDefaults.standard.string(forKey: "windowFrame") {
            window.setFrame(NSRectFromString(saved), display: true)
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        if editedMask.contains(.editedCharacters) {
            storage.scheduleSave(text: textView.string)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)

let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
mainMenu.addItem(appMenuItem)
let appMenu = NSMenu()
appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
appMenuItem.submenu = appMenu

let editMenuItem = NSMenuItem()
mainMenu.addItem(editMenuItem)
let editMenu = NSMenu(title: "Edit")
editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
editMenu.addItem(NSMenuItem.separator())
editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
editMenuItem.submenu = editMenu

app.mainMenu = mainMenu

app.activate(ignoringOtherApps: true)
app.run()
