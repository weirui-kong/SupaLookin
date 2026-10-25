//
//  LKServerVersionRequestor.swift
//  SupaLookin
//
// Created by likai.123 on 2023/10/30.
// Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

final class LKServerVersionRequestor {

    static let shared = LKServerVersionRequestor()

    private init() {}

    func preload() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        // avoid network cache
        let dateString = dateFormatter.string(from: Date())

        guard let jsonURL = URL(string: "https://lookin.work/queryversion.json?time=\(dateString)") else {
            return
        }
        let dataTask = URLSession.shared.dataTask(with: jsonURL) { data, _, error in
            if let error {
                NSLog("Error: %@", String(describing: error))
                return
            }
            let json: Any
            do {
                json = try JSONSerialization.jsonObject(with: data ?? Data())
            } catch {
                NSLog("JSON Error: %@", String(describing: error))
                return
            }
            guard let version = (json as? [String: Any])?["currentVersion"] as? String else {
                NSLog("No currentVersion")
                return
            }
            DispatchQueue.main.async {
                LKServerVersionRequestor.shared.handleReceive(version: version)
            }
        }
        dataTask.resume()
    }

    private func handleReceive(version: String) {
        NSLog("Receive version: %@", version)
        UserDefaults.standard.set(version, forKey: "LKServerVersionRequestor_version")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "LKServerVersionRequestor_time")
    }

    func query() -> String? {
        let version = UserDefaults.standard.object(forKey: "LKServerVersionRequestor_version") as? String
        let time = UserDefaults.standard.double(forKey: "LKServerVersionRequestor_time")
        guard time > 0, let version, !version.isEmpty else {
            return nil
        }
        let timeDiff = Date().timeIntervalSince1970 - time
        if timeDiff >= 3600 * 24 * 3 {
            // 3 day
            return nil
        }
        return version
    }
}
