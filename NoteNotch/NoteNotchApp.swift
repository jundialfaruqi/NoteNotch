import SwiftUI

@main
struct NoteNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var panel: FloatingPanel<ContentView>!
    var triggerWindow: NotchTriggerWindow!
    
    private var hideTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)
        
        panel = FloatingPanel {
            ContentView()
        }
        panel.acceptsMouseMovedEvents = true
        
        triggerWindow = NotchTriggerWindow()
        triggerWindow.makeKeyAndOrderFront(nil)
        
        triggerWindow.onHover = { [weak self] in
            self?.showPanel()
        }
        
        triggerWindow.onExit = { [weak self] in
            self?.startHideTimer()
        }
        
        // Add mouse tracking to panel as well to keep it open when mouse is over it
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.cancelHideTimer()
        }
    }
    
    func showPanel() {
        cancelHideTimer()
        panel.showPanel()
    }
    
    func startHideTimer() {
        cancelHideTimer()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            // Only hide if the mouse is not currently over the panel
            if let panel = self?.panel, NSApp.keyWindow != panel {
                let mouseLocation = NSEvent.mouseLocation
                if !NSWindow.contentRect(forFrameRect: panel.frame, styleMask: panel.styleMask).contains(mouseLocation) {
                    panel.hidePanel()
                }
            }
        }
    }
    
    func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
}
