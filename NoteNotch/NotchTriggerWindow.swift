import AppKit
import SwiftUI

class NotchTriggerWindow: NSWindow {
    
    var onHover: (() -> Void)?
    var onExit: (() -> Void)?
    
    init() {
        let screen = NSScreen.main?.frame ?? .zero
        let width: CGFloat = 200
        let height: CGFloat = 40
        
        // Position at the top center
        let x = (screen.width - width) / 2
        let y = screen.height - height
        
        super.init(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.level = .statusBar
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let view = TriggerView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view.onHover = { [weak self] in self?.onHover?() }
        view.onExit = { [weak self] in self?.onExit?() }
        
        self.contentView = view
    }
}

class TriggerView: NSView {
    var onHover: (() -> Void)?
    var onExit: (() -> Void)?
    
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways
        ]
        
        trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        
        addTrackingArea(trackingArea!)
        super.updateTrackingAreas()
    }
    
    override func mouseEntered(with event: NSEvent) {
        onHover?()
    }
    
    override func mouseExited(with event: NSEvent) {
        onExit?()
    }
}
