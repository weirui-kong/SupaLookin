//
//  SPLKDemoApp.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import UIKit

// A fixed view tree that SPLKEndToEndTests reads and changes; keep the two in sync.
final class SPLKDemoCustomView: UIView {

    @objc var demoNote = "initial"

    @objc func splk_customDebugInfos() -> NSDictionary {
        let setNote: @convention(block) (NSString) -> Void = { [weak self] value in
            self?.demoNote = value as String
        }
        return [
            "title": "Demo Custom",
            "properties": [
                ["section": "Strings", "title": "Note", "valueType": "string", "value": demoNote, "retainedSetter": setNote],
                ["section": "Numbers", "title": "Count", "valueType": "number", "value": 3],
                ["section": "Numbers", "title": "Flag", "valueType": "bool", "value": true],
                ["section": "Visual", "title": "Tint", "valueType": "color", "value": UIColor.systemOrange],
                ["section": "Visual", "title": "Box", "valueType": "rect", "value": NSValue(cgRect: CGRect(x: 1, y: 2, width: 3, height: 4))],
                ["section": "Visual", "title": "Extent", "valueType": "size", "value": NSValue(cgSize: CGSize(width: 5, height: 6))],
                ["section": "Visual", "title": "Spot", "valueType": "point", "value": NSValue(cgPoint: CGPoint(x: 7, y: 8))],
                ["section": "Visual", "title": "Padding", "valueType": "insets", "value": NSValue(uiEdgeInsets: UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4))],
                ["section": "Visual", "title": "Glow", "valueType": "shadow", "value": ["color": UIColor.black, "offset": NSValue(cgSize: CGSize(width: 0, height: 2)), "opacity": 0.5, "radius": 3]],
                ["section": "Other", "title": "Mode", "valueType": "enum", "value": "b", "allEnumCases": ["a", "b", "c"]],
                ["section": "Other", "title": "Payload", "valueType": "json", "value": "{\"answer\":42}"],
            ],
        ]
    }
}

final class SPLKDemoViewController: UIViewController, UITableViewDataSource {

    // What injected input reached the demo; the tests read these with InvokeMethod.
    @objc var buttonTaps = 0
    @objc var viewTaps = 0
    @objc var shakes = 0

    @objc var detailShown: Bool {
        navigationController?.topViewController !== self
    }

    @objc func pushDetail() {
        let detail = UIViewController()
        detail.view.backgroundColor = .systemTeal
        navigationController?.pushViewController(detail, animated: false)
    }

    @objc func buttonTapped() {
        buttonTaps += 1
    }

    @objc func viewTapped() {
        viewTaps += 1
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            shakes += 1
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel(frame: CGRect(x: 20, y: 80, width: 300, height: 30))
        label.text = "SPLK e2e"
        view.addSubview(label)

        let field = UITextField(frame: CGRect(x: 20, y: 120, width: 300, height: 30))
        field.placeholder = "Field"
        view.addSubview(field)

        let textView = UITextView(frame: CGRect(x: 20, y: 160, width: 300, height: 40))
        textView.text = "Text view"
        view.addSubview(textView)

        let imageView = UIImageView(frame: CGRect(x: 20, y: 210, width: 40, height: 40))
        imageView.image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        view.addSubview(imageView)

        let button = UIButton(type: .system)
        button.frame = CGRect(x: 80, y: 210, width: 120, height: 40)
        button.setTitle("Button", for: .normal)
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        view.addSubview(button)

        let effect = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        effect.frame = CGRect(x: 220, y: 210, width: 80, height: 40)
        view.addSubview(effect)

        let custom = SPLKDemoCustomView()
        custom.backgroundColor = .systemYellow
        custom.translatesAutoresizingMaskIntoConstraints = false
        custom.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))
        view.addSubview(custom)
        NSLayoutConstraint.activate([
            custom.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            custom.topAnchor.constraint(equalTo: view.topAnchor, constant: 260),
            custom.widthAnchor.constraint(equalToConstant: 100),
            custom.heightAnchor.constraint(equalToConstant: 44),
        ])

        let table = UITableView(frame: CGRect(x: 20, y: 320, width: 300, height: 200), style: .plain)
        table.dataSource = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(table)
    }

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 30 : 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "Row \(indexPath.section)-\(indexPath.row)"
        return cell
    }
}

final class SPLKDemoSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: SPLKDemoViewController())
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class SPLKDemoAppDelegate: UIResponder, UIApplicationDelegate {}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(SPLKDemoAppDelegate.self))
