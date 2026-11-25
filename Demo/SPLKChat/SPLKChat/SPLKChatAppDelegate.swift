//
//  SPLKChatAppDelegate.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/18.
//

import UIKit

@main
final class SPLKChatAppDelegate: UIResponder, UIApplicationDelegate {}

final class SPLKChatSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.tintColor = .splkChatAccent
        window.rootViewController = SPLKChatTabBarController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class SPLKChatTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let tabs: [(UIViewController, String, String)] = [
            (SPLKChatsViewController(), "Chats", "message"),
            (SPLKContactsViewController(), "Contacts", "person.2"),
            (SPLKDiscoverViewController(), "Discover", "safari"),
            (SPLKMeViewController(), "Me", "person"),
        ]
        viewControllers = tabs.map { controller, title, symbol in
            controller.title = title
            let navigation = UINavigationController(rootViewController: controller)
            navigation.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbol), selectedImage: UIImage(systemName: symbol + ".fill"))
            return navigation
        }
        // Launching with `-SPLKChatScreen masks` opens Discover › Masks, for tests that need it on screen.
        if UserDefaults.standard.string(forKey: "SPLKChatScreen") == "masks", let discover = tabs[2].0 as? SPLKDiscoverViewController {
            selectedIndex = 2
            discover.showMasks(animated: false)
        }
    }
}

extension UIColor {
    static let splkChatAccent = UIColor(red: 0.16, green: 0.68, blue: 0.38, alpha: 1)
    static let splkChatOutgoingBubble = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.52, blue: 0.32, alpha: 1)
            : UIColor(red: 0.62, green: 0.89, blue: 0.47, alpha: 1)
    }
    static let splkChatIncomingBubble = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .secondarySystemBackground : .white
    }
    static let splkChatBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemBackground : UIColor(white: 0.93, alpha: 1)
    }
}
