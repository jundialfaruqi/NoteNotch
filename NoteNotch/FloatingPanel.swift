import SwiftUI
import AppKit

class FloatingPanel<Content: View>: NSPanel {

    init(@ViewBuilder content: () -> Content) {
        let screen = NSScreen.main?.frame ?? .zero

        let width: CGFloat = 600
        let height: CGFloat = 450

        let x = (screen.width - width) / 2
        // Start hidden (above the screen)
        let y = screen.height

        super.init(
            contentRect: NSRect(
                x: x,
                y: y,
                width: width,
                height: height
            ),
            styleMask: [
                .borderless,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .mainMenu + 1 // Di atas segalanya

        backgroundColor = .clear
        isOpaque = false
        hasShadow = false // Hapus shadow agar menempel rata

        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]

        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        contentView = NSHostingView(
            rootView: content()
        )
    }
    
    override var canBecomeKey: Bool { true }
    
    func showPanel() {
        guard let screen = NSScreen.main?.frame else { return }
        
        let targetY = screen.height - self.frame.height // Menempel pas di sisi atas (0 margin)
        let targetX = (screen.width - 600) / 2
        
        let targetFrame = NSRect(x: targetX, y: targetY, width: 600, height: self.frame.height)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(targetFrame, display: true)
            self.animator().alphaValue = 1.0
        }
        
        self.makeKeyAndOrderFront(nil)
    }
    
    func hidePanel() {
        guard let screen = NSScreen.main?.frame else { return }
        
        let targetY = screen.height // Hide above screen
        let targetFrame = NSRect(x: self.frame.origin.x, y: targetY, width: self.frame.width, height: self.frame.height)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(targetFrame, display: true)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}
