//
//  AppDelegate.swift
//  FigmaSimuCast
//
//  Created by Lorant Csonka on 3/8/25.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    
    // UI Components in the custom menu view
    var simulatorPopup: NSPopUpButton!
    var refreshButton: NSButton!
    var frequencySlider: NSSlider!
    var startStopButton: NSButton!
    var portTextField: NSTextField!
    var applyPortButton: NSButton!
    var imageView: NSImageView!
    var addressLabel: NSTextField!
    var copyButton: NSButton!
    
    // Timer to update the live preview when the menu is open (10 fps)
    var previewTimer: Timer?
    
    // Monitoring state
    var captureTimer: Timer?
    var currentFrequency: Double = 1.0 // fps (capture frequency)
    var isMonitoring = false
    var latestImageData: Data?
    
    // Selected simulator (set via simulator popup)
    var selectedSimulator: Simulator? {
        didSet {
            // If monitoring and a new simulator is chosen, restart monitoring.
            if isMonitoring {
                stopMonitoring()
                startMonitoring()
            }
        }
    }
    
    // HTTP server for hosting the image
    var httpServer: HTTPServer?
    var currentPort: UInt16 = 8080
    
    var isMenuOpen: Bool = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusItem()
        refreshSimulators()
    }
    
    // MARK: - Setup Status Item and Custom Menu
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // Initially stopped: use "play.fill". When running, we’ll show "record.circle"
            button.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Stopped")
            button.action = #selector(statusItemClicked)
        }
        
        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        
        // Create a custom view for the menu with increased height
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 250))
        
        // Row 1: Simulator selection label and controls
        let simLabel = NSTextField(labelWithString: "Select Simulator:")
        simLabel.frame = NSRect(x: 10, y: 220, width: 280, height: 20)
        customView.addSubview(simLabel)
        
        simulatorPopup = NSPopUpButton(frame: NSRect(x: 10, y: 190, width: 200, height: 25))
        simulatorPopup.target = self
        simulatorPopup.action = #selector(simulatorSelectionChanged)
        customView.addSubview(simulatorPopup)
        
        refreshButton = NSButton(frame: NSRect(x: 220, y: 190, width: 70, height: 25))
        refreshButton.title = "Refresh"
        refreshButton.target = self
        refreshButton.action = #selector(refreshSimulatorsAction)
        customView.addSubview(refreshButton)
        
        // Row 2: Frequency label and slider
        let freqLabel = NSTextField(labelWithString: "Capture Frequency (fps):")
        freqLabel.frame = NSRect(x: 10, y: 160, width: 280, height: 20)
        customView.addSubview(freqLabel)
        
        frequencySlider = NSSlider(value: currentFrequency, minValue: 1, maxValue: 10, target: self, action: #selector(frequencyChanged))
        frequencySlider.frame = NSRect(x: 10, y: 130, width: 280, height: 25)
        customView.addSubview(frequencySlider)
        
        // Row 3: Start/Stop button
        startStopButton = NSButton(frame: NSRect(x: 10, y: 100, width: 280, height: 25))
        startStopButton.title = "Start Monitoring"
        startStopButton.target = self
        startStopButton.action = #selector(toggleMonitoring)
        customView.addSubview(startStopButton)
        
        // Row 4: Port settings row
        let portLabel = NSTextField(labelWithString: "Port:")
        portLabel.frame = NSRect(x: 10, y: 70, width: 50, height: 25)
        customView.addSubview(portLabel)
        
        portTextField = NSTextField(string: "\(currentPort)")
        portTextField.frame = NSRect(x: 60, y: 70, width: 100, height: 25)
        customView.addSubview(portTextField)
        
        applyPortButton = NSButton(frame: NSRect(x: 170, y: 70, width: 120, height: 25))
        applyPortButton.title = "Apply Port"
        applyPortButton.target = self
        applyPortButton.action = #selector(applyPortChange)
        customView.addSubview(applyPortButton)
        
        // Row 5: Preview row: mini image preview, host URL, copy button
        imageView = NSImageView(frame: NSRect(x: 10, y: 5, width: 60, height: 30))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        customView.addSubview(imageView)
        
        addressLabel = NSTextField(labelWithString: "http://localhost:\(currentPort)/latest.png")
        addressLabel.frame = NSRect(x: 80, y: 5, width: 150, height: 30)
        customView.addSubview(addressLabel)
        
        copyButton = NSButton(frame: NSRect(x: 240, y: 5, width: 50, height: 30))
        copyButton.title = "Copy"
        copyButton.target = self
        copyButton.action = #selector(copyHostURL)
        customView.addSubview(copyButton)
        
        let customMenuItem = NSMenuItem()
        customMenuItem.view = customView
        menu.addItem(customMenuItem)
        
        // Add an exit item at the bottom
        menu.addItem(NSMenuItem.separator())
        let exitItem = NSMenuItem(title: "Exit", action: #selector(exitApp), keyEquivalent: "q")
        exitItem.target = self
        menu.addItem(exitItem)
    }
    
    @objc func statusItemClicked() {
        if let button = statusItem.button {
            button.performClick(nil)
        }
    }
    
    // MARK: - UI Actions
    
    @objc func simulatorSelectionChanged() {
        if let selectedTitle = simulatorPopup.selectedItem?.title {
            if let sim = SimulatorManager.shared.simulators.first(where: { $0.name == selectedTitle }) {
                selectedSimulator = sim
            }
        }
    }
    
    @objc func frequencyChanged() {
        currentFrequency = frequencySlider.doubleValue
        if isMonitoring {
            restartCaptureTimer()
        }
    }
    
    @objc func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    @objc func refreshSimulatorsAction() {
        let wasMonitoring = isMonitoring
        stopMonitoring()
        refreshSimulators()
        if wasMonitoring {
            startMonitoring()
        }
    }
    
    @objc func applyPortChange() {
        guard let portValue = UInt16(portTextField.stringValue) else { return }
        currentPort = portValue
        addressLabel.stringValue = "http://localhost:\(currentPort)/latest.png"
        // Restart HTTP server if already running
        if httpServer != nil {
            httpServer?.stop()
            httpServer = HTTPServer(port: currentPort, imageDataProvider: { [weak self] in
                return self?.latestImageData
            })
            httpServer?.start()
        }
    }
    
    @objc func copyHostURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(addressLabel.stringValue, forType: .string)
    }
    
    @objc func exitApp() {
        NSApp.terminate(self)
    }
    
    // MARK: - Monitoring & Capture
    
    func startMonitoring() {
        guard let sim = selectedSimulator else {
            print("No simulator selected.")
            return
        }
        isMonitoring = true
        startStopButton.title = "Stop Monitoring"
        updateStatusIcon()
        
        // Start HTTP server if not already running
        if httpServer == nil {
            httpServer = HTTPServer(port: currentPort, imageDataProvider: { [weak self] in
                return self?.latestImageData
            })
            httpServer?.start()
        }
        restartCaptureTimer()
    }
    
    func stopMonitoring() {
        isMonitoring = false
        startStopButton.title = "Start Monitoring"
        updateStatusIcon()
        captureTimer?.invalidate()
        captureTimer = nil
    }
    
    func restartCaptureTimer() {
        captureTimer?.invalidate()
        captureTimer = Timer.scheduledTimer(timeInterval: 1.0 / currentFrequency, target: self, selector: #selector(captureTick), userInfo: nil, repeats: true)
    }
    
    @objc func captureTick() {
        guard let sim = selectedSimulator else { return }
        SimulatorManager.shared.captureScreenshot(for: sim) { [weak self] data in
            guard let self = self, let data = data else { return }
            self.latestImageData = data
            // If menu isn't open, update preview here; otherwise, previewTimer handles it.
            if !self.isMenuOpen, let image = NSImage(data: data) {
                self.imageView.image = image
            }
        }
    }
    
    // MARK: - Simulator Management
    
    func refreshSimulators() {
        SimulatorManager.shared.fetchRunningSimulators { [weak self] simulators in
            guard let self = self else { return }
            self.simulatorPopup.removeAllItems()
            for sim in simulators {
                self.simulatorPopup.addItem(withTitle: sim.name)
            }
            if let first = simulators.first {
                self.selectedSimulator = first
                self.simulatorPopup.selectItem(withTitle: first.name)
            }
        }
    }
    
    func updateStatusIcon() {
        if let button = statusItem.button {
            if isMonitoring {
                button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Running")
            } else {
                button.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Stopped")
            }
        }
    }
    
    // MARK: - NSMenuDelegate Methods
    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        // Start preview update timer (10 fps) when menu opens
        previewTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in
            guard let self = self, let data = self.latestImageData, let image = NSImage(data: data) else { return }
            self.imageView.image = image
        })
    }
    
    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        previewTimer?.invalidate()
        previewTimer = nil
    }
}
