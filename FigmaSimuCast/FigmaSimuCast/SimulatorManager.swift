//
//  SimulatorManager.swift
//  FigmaSimuCast
//
//  Created by Lorant Csonka on 3/8/25.
//

import Foundation

struct Simulator {
    let udid: String
    let name: String
}

class SimulatorManager {
    static let shared = SimulatorManager()
    
    private(set) var simulators: [Simulator] = []
    var selectedSimulator: Simulator?
    
    /// Fetches running simulators by invoking `xcrun simctl list --json devices`
    func fetchRunningSimulators(completion: @escaping ([Simulator]) -> Void) {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launchPath = "/usr/bin/xcrun"
        task.arguments = ["simctl", "list", "--json", "devices"]
        
        task.terminationHandler = { process in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let devices = json["devices"] as? [String: Any] {
                    var bootedSimulators: [Simulator] = []
                    for (_, simArray) in devices {
                        if let sims = simArray as? [[String: Any]] {
                            for sim in sims {
                                if let state = sim["state"] as? String, state == "Booted",
                                   let udid = sim["udid"] as? String,
                                   let name = sim["name"] as? String {
                                    bootedSimulators.append(Simulator(udid: udid, name: name))
                                }
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        self.simulators = bootedSimulators
                        completion(bootedSimulators)
                    }
                }
            } catch {
                print("Error parsing simulator list: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
        
        do {
            try task.run()
        } catch {
            print("Error running simctl: \(error)")
            completion([])
        }
    }
    
    /// Captures a screenshot for the given simulator by invoking `xcrun simctl io <udid> screenshot`
    func captureScreenshot(for simulator: Simulator, completion: @escaping (Data?) -> Void) {
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + "simulator_screenshot.png"
        
        let task = Process()
        task.launchPath = "/usr/bin/xcrun"
        task.arguments = ["simctl", "io", simulator.udid, "screenshot", filePath]
        task.terminationHandler = { process in
            let imageData = try? Data(contentsOf: URL(fileURLWithPath: filePath))
            DispatchQueue.main.async {
                completion(imageData)
            }
        }
        
        do {
            try task.run()
        } catch {
            print("Error capturing screenshot: \(error)")
            completion(nil)
        }
    }
}
