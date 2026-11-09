//
//  DanceScriptManager.swift
//  SupaLookin
//
//  Created by likai.123 on 2023/12/18.
//  Copyright © 2023 hughkli. All rights reserved.
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

final class DanceScriptManager {

    static let shared = DanceScriptManager()

    private init() {}

    func handleText(_ json: String?) {
        let keyWindow = NSApplication.shared.keyWindow
        guard let json else {
            SPLKHelper.alertError(SPLKError.inner, window: keyWindow)
            return
        }
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: json.data(using: .utf8) ?? Data())
        } catch {
            SPLKHelper.alertErrorText("Failed", "Failed to parse: \(json)", window: keyWindow)
            assertionFailure()
            return
        }
        guard let dict = parsed as? [String: Any] else {
            SPLKHelper.alertErrorText("Failed", "Unexpected format: \(json)", window: keyWindow)
            return
        }
        guard let type = dict["type"] as? String, let method = dict["method"] as? String, let path = dict["build_path"] as? String else {
            SPLKHelper.alertErrorText("Failed", "Unexpected format: \(json)", window: keyWindow)
            return
        }
        execute(withType: type, method: method, path: path)
    }

    private func copyScriptFromAppToDisk() -> String? {
        let keyWindow = NSApplication.shared.keyWindow
        let fileManager = FileManager.default
        let newScriptPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("SPLK_DanceJump.sh")
        if fileManager.fileExists(atPath: newScriptPath) {
            return newScriptPath
        }

        let scriptPath = Bundle.main.url(forResource: "DanceScript", withExtension: "sh")?.relativePath
        guard let scriptPath, fileManager.fileExists(atPath: scriptPath) else {
            SPLKHelper.alertErrorText("Failed", "Cannot find script: \(scriptPath ?? "(null)")", window: keyWindow)
            return nil
        }
        let succ = (try? fileManager.copyItem(atPath: scriptPath, toPath: newScriptPath)) != nil
        try? fileManager.setAttributes([.posixPermissions: NSNumber(value: Int16(0o755))], ofItemAtPath: newScriptPath)
        if !succ {
            SPLKHelper.alertErrorText("Failed", "Copy script error", window: keyWindow)
            return nil
        }
        if !fileManager.fileExists(atPath: newScriptPath) {
            SPLKHelper.alertErrorText("Failed", "Copy script weird error", window: keyWindow)
            return nil
        }
        return newScriptPath
    }

    /*

     对应 splk_source 的类型是这个 json 结构
     {"type":"DanceUIApp.ContentView","method":"body.get","build_path":"\/Users\/bytedance\/Library\/Developer\/Xcode\/DerivedData\/DanceUIApp-ayaxbucdgzeouqefaavnvvhsjpvj\/Build\/Products\/Debug-iphonesimulator\/DanceUIApp.app\/DanceUIApp"}

     传参的顺序是 sh viewdebug.sh build_path type method
     */
    private func execute(withType type: String, method: String, path buildPath: String) {
        let scriptPath = copyScriptFromAppToDisk()
        // 创建 Process 对象
        let task = Process()

        // 设置要执行的命令
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "\(scriptPath ?? "(null)") \(buildPath) \(type) \(method)"]

        // 创建管道用于获取输出
        let pipe = Pipe()
        task.standardOutput = pipe

        // 开始任务
        do {
            try task.run()
        } catch {
            NSLog("脚本执行失败：%@", String(describing: error))
            return
        }

        // 从管道中读取输出
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // 输出脚本执行结果
        NSLog("脚本执行输出：%@", output)
    }
}
