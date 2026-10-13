import AppKit

/// A panel that can take keyboard focus without activating CopyHero, so the
/// app you were typing in stays frontmost and receives the paste.
final class KeyPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyHandler?(event) == true { return }
        super.sendEvent(event)
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

func makeBackground(frame: NSRect) -> NSVisualEffectView {
    let bg = NSVisualEffectView(frame: frame)
    bg.material = .menu
    bg.blendingMode = .behindWindow
    bg.state = .active
    bg.wantsLayer = true
    bg.layer?.cornerRadius = 10
    bg.layer?.masksToBounds = true
    return bg
}

func makePanel(ignoresMouse: Bool) -> KeyPanel {
    let p = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                     backing: .buffered, defer: true)
    p.isFloatingPanel = true
    p.level = .popUpMenu
    p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    p.backgroundColor = .clear
    p.isOpaque = false
    p.hasShadow = true
    p.hidesOnDeactivate = false
    p.ignoresMouseEvents = ignoresMouse
    return p
}

// MARK: - Row

final class RowView: NSView {
    let index: Int
    var onHover: ((Int) -> Void)?
    var onClick: ((Int) -> Void)?
    private let numberLabel: NSTextField
    private let titleLabel: NSTextField

    var isSelected = false {
        didSet {
            titleLabel.textColor = isSelected ? .white : .labelColor
            numberLabel.textColor = isSelected ? .white.withAlphaComponent(0.8) : .tertiaryLabelColor
            needsDisplay = true
        }
    }

    init(index: Int, item: ClipItem, frame: NSRect) {
        self.index = index
        numberLabel = NSTextField(labelWithString: index < 9 ? "\(index + 1)" : "")
        titleLabel = NSTextField(labelWithString: item.title)
        super.init(frame: frame)

        numberLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        numberLabel.textColor = .tertiaryLabelColor
        numberLabel.alignment = .right
        numberLabel.frame = NSRect(x: 8, y: (frame.height - 14) / 2, width: 14, height: 14)

        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.cell?.usesSingleLineMode = true
        titleLabel.frame = NSRect(x: 30, y: (frame.height - 16) / 2, width: frame.width - 40, height: 16)

        addSubview(numberLabel)
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // .activeAlways is required because CopyHero is never the active app.
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { onHover?(index) }
    override func mouseMoved(with event: NSEvent) { if !isSelected { onHover?(index) } }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?(index) }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isSelected else { return }
        NSColor.selectedContentBackgroundColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 1), xRadius: 5, yRadius: 5).fill()
    }
}

// MARK: - History panel

final class HistoryPanelController: NSObject, NSWindowDelegate {
    private let history: ClipboardHistory
    private let panel = makePanel(ignoresMouse: false)
    private let preview = PreviewPanelController()
    private var rows: [RowView] = []
    private var selected: Int?
    private var targetApp: NSRunningApplication?

    private let width: CGFloat = 340
    private let rowHeight: CGFloat = 24
    private let headerHeight: CGFloat = 28
    private let footerHeight: CGFloat = 38

    init(history: ClipboardHistory) {
        self.history = history
        super.init()
        panel.delegate = self
        panel.keyHandler = { [weak self] in self?.handleKey($0) ?? false }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero

        // Remember who should receive the paste; a mouse click can shift focus.
        let front = NSWorkspace.shared.frontmostApplication
        targetApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front

        rebuild()
        var origin = NSPoint(x: mouse.x + 4, y: mouse.y - panel.frame.height - 4)
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - panel.frame.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - panel.frame.height - 8)
        panel.setFrameOrigin(origin)

        panel.makeKeyAndOrderFront(nil)
        select(history.items.isEmpty ? nil : 0)
    }

    func hide() {
        preview.hide()
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: Layout

    private func rebuild() {
        let items = history.items
        let listHeight = items.isEmpty ? 44 : CGFloat(items.count) * rowHeight
        let height = headerHeight + listHeight + 6 + footerHeight

        // Keep the top edge fixed when resizing (e.g. after Clear).
        let oldTop = panel.isVisible ? panel.frame.maxY : nil
        panel.setContentSize(NSSize(width: width, height: height))
        if let oldTop { panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: oldTop - height)) }

        let bounds = NSRect(x: 0, y: 0, width: width, height: height)
        let bg = makeBackground(frame: bounds)
        let content = FlippedView(frame: bounds)
        content.autoresizingMask = [.width, .height]
        bg.addSubview(content)

        let header = NSTextField(labelWithString: "Clipboard History")
        header.font = .systemFont(ofSize: 11, weight: .semibold)
        header.textColor = .secondaryLabelColor
        header.frame = NSRect(x: 12, y: 8, width: width - 24, height: 14)
        content.addSubview(header)

        rows = items.enumerated().map { i, item in
            let row = RowView(index: i, item: item,
                              frame: NSRect(x: 0, y: headerHeight + CGFloat(i) * rowHeight, width: width, height: rowHeight))
            row.onHover = { [weak self] in self?.select($0) }
            row.onClick = { [weak self] in self?.choose($0) }
            content.addSubview(row)
            return row
        }

        if items.isEmpty {
            let empty = NSTextField(labelWithString: "Nothing copied yet — press ⌘C on something.")
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = .secondaryLabelColor
            empty.alignment = .center
            empty.frame = NSRect(x: 12, y: headerHeight + 12, width: width - 24, height: 18)
            content.addSubview(empty)
        }

        let footerY = height - footerHeight
        let separator = NSBox(frame: NSRect(x: 0, y: footerY, width: width, height: 1))
        separator.boxType = .separator
        content.addSubview(separator)

        let hint = NSTextField(labelWithString: "↩ paste   ↑↓ move   esc close")
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .tertiaryLabelColor
        hint.frame = NSRect(x: 12, y: footerY + 12, width: 180, height: 14)
        content.addSubview(hint)

        let clear = NSButton(title: "Clear History", target: self, action: #selector(clearHistory))
        clear.bezelStyle = .rounded
        clear.controlSize = .small
        clear.font = .systemFont(ofSize: 11)
        clear.hasDestructiveAction = true
        clear.refusesFirstResponder = true
        clear.isEnabled = !items.isEmpty
        clear.sizeToFit()
        clear.frame.origin = NSPoint(x: width - clear.frame.width - 10, y: footerY + (footerHeight - clear.frame.height) / 2)
        content.addSubview(clear)

        panel.contentView = bg
    }

    // MARK: Selection & actions

    private func select(_ index: Int?) {
        selected = index
        for row in rows { row.isSelected = row.index == index }
        guard let index, index < rows.count else { preview.hide(); return }
        let row = rows[index]
        let rowRect = panel.convertToScreen(row.convert(row.bounds, to: nil))
        preview.show(history.items[index], besidePanel: panel.frame, rowTop: rowRect.maxY)
    }

    private func choose(_ index: Int) {
        guard index < history.items.count else { return }
        let item = history.items[index]
        let target = targetApp
        hide()
        Paster.copyToPasteboard(item)
        Paster.paste(into: target)
    }

    @objc private func clearHistory() {
        history.clear()
        rebuild()
        select(nil)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let count = history.items.count
        switch Int(event.keyCode) {
        case 53: // esc
            hide()
            return true
        case 125: // down
            if count > 0 { select(((selected ?? -1) + 1) % count) }
            return true
        case 126: // up
            if count > 0 { select(((selected ?? count) - 1 + count) % count) }
            return true
        case 36, 76: // return, keypad enter
            if let selected { choose(selected) }
            return true
        default:
            if let c = event.charactersIgnoringModifiers, let n = Int(c), (1...9).contains(n), n <= count {
                choose(n - 1)
                return true
            }
            return false
        }
    }
}

// MARK: - Hover preview

final class PreviewPanelController {
    private let panel = makePanel(ignoresMouse: true)
    private let maxWidth: CGFloat = 420
    private let maxHeight: CGFloat = 420
    private let padding: CGFloat = 12

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    func show(_ item: ClipItem, besidePanel host: NSRect, rowTop: CGFloat) {
        let contentView: NSView
        let contentSize: NSSize
        let meta: String
        let ago = Date().timeIntervalSince(item.date) < 5
            ? "just now" : Self.relativeFormatter.localizedString(for: item.date, relativeTo: Date())

        switch item.content {
        case .text(let s):
            let label = NSTextField(wrappingLabelWithString: String(s.prefix(5000)))
            label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            label.textColor = .labelColor
            label.maximumNumberOfLines = 28
            label.cell?.truncatesLastVisibleLine = true
            label.isSelectable = false
            let fit = label.cell!.cellSize(forBounds: NSRect(x: 0, y: 0, width: maxWidth - padding * 2, height: maxHeight))
            contentSize = NSSize(width: max(ceil(fit.width), 160), height: min(ceil(fit.height), maxHeight - 40))
            contentView = label
            let lines = s.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
            meta = "\(s.count.formatted()) characters · \(lines) line\(lines == 1 ? "" : "s") · \(ago)"

        case .image(let img, _, _):
            let box = maxWidth - padding * 2
            let scale = min(1, box / max(img.size.width, 1), box / max(img.size.height, 1))
            contentSize = NSSize(width: max(img.size.width * scale, 160), height: img.size.height * scale)
            let iv = NSImageView()
            iv.image = img
            iv.imageScaling = .scaleProportionallyDown
            contentView = iv
            meta = "Image · \(Int(img.size.width))×\(Int(img.size.height)) · \(ago)"
        }

        let metaHeight: CGFloat = 14
        let size = NSSize(width: contentSize.width + padding * 2,
                          height: contentSize.height + padding * 2 + metaHeight + 6)
        let bounds = NSRect(origin: .zero, size: size)
        let bg = makeBackground(frame: bounds)
        let flipped = FlippedView(frame: bounds)
        bg.addSubview(flipped)

        contentView.frame = NSRect(x: padding, y: padding, width: contentSize.width, height: contentSize.height)
        flipped.addSubview(contentView)

        let metaLabel = NSTextField(labelWithString: meta)
        metaLabel.font = .systemFont(ofSize: 10)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.frame = NSRect(x: padding, y: size.height - padding - metaHeight, width: contentSize.width, height: metaHeight)
        flipped.addSubview(metaLabel)

        panel.contentView = bg

        // Place to the right of the history panel, or to the left if there's no room.
        let screen = NSScreen.screens.first { $0.frame.intersects(host) }?.visibleFrame ?? .zero
        var x = host.maxX + 6
        if x + size.width > screen.maxX { x = host.minX - 6 - size.width }
        var y = rowTop - size.height + 4
        y = min(max(y, screen.minY + 8), screen.maxY - size.height - 8)
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }
}
