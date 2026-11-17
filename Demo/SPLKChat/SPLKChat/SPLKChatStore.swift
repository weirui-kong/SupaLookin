//
//  SPLKChatStore.swift
//  SPLKChat
//
//  Created by Weirui Kong on 2026/11/18.
//

import UIKit

struct SPLKChatContact: Hashable {
    let id: Int
    let name: String
    let status: String

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    var color: UIColor {
        let palette: [UIColor] = [.systemBlue, .systemOrange, .systemPink, .systemPurple, .systemTeal, .systemIndigo, .systemRed, .systemBrown]
        return palette[id % palette.count]
    }
}

struct SPLKChatMessage {
    let text: String
    let isOutgoing: Bool
    let date: Date
}

final class SPLKChatConversation {
    let contact: SPLKChatContact
    var messages: [SPLKChatMessage]
    var unreadCount: Int
    var isMuted = false

    init(contact: SPLKChatContact, messages: [SPLKChatMessage], unreadCount: Int) {
        self.contact = contact
        self.messages = messages
        self.unreadCount = unreadCount
    }
}

final class SPLKChatStore {

    static let shared = SPLKChatStore()
    static let didChangeNotification = Notification.Name("SPLKChatStoreDidChange")

    let me = SPLKChatContact(id: 0, name: "Demo User", status: "Testing Supa Lookin")
    let contacts: [SPLKChatContact]
    private(set) var conversations: [SPLKChatConversation]

    private static let names = [
        "Alice Chen", "Ben Carter", "Chloe Park", "Daniel Ortiz", "Emma Wilson", "Felix Wagner", "Grace Liu",
        "Henry Brooks", "Iris Tanaka", "Jack Murphy", "Kate Nguyen", "Leo Rossi", "Mia Schmidt", "Noah Patel",
        "Olivia Brown", "Peter Novak", "Quinn Foster", "Ruby Ahmed", "Sam Lee", "Tina Kowalski", "Uma Singh",
        "Victor Hugo", "Wendy Zhao", "Xavier Ruiz", "Yuki Sato", "Zoe Martin", "Aaron Kim", "Bella Costa",
        "Caleb Hughes", "Diana Moreau", "Ethan Price", "Fiona Walsh", "George Ito", "Hannah Becker", "Ivan Petrov",
        "Julia Silva", "Kevin O'Neil", "Laura Fischer", "Marco Bianchi", "Nina Larsen",
    ]

    private static let lines = [
        "Are we still on for lunch?", "Sent you the slides.", "Haha, that's great", "Can you check the build?",
        "On my way!", "Did you see the new release?", "Call me when you're free.", "Thanks a lot!",
        "Let's sync tomorrow morning.", "The demo looks good.", "Where should we meet?", "Happy birthday!",
    ]

    private init() {
        contacts = Self.names.enumerated().map { index, name in
            SPLKChatContact(id: index + 1, name: name, status: Self.lines[index % Self.lines.count])
        }
        let now = Date()
        conversations = contacts.prefix(24).enumerated().map { index, contact in
            let start = now.addingTimeInterval(-Double(index) * 3_600 * 5)
            let messages = (0..<(6 + index % 9)).map { step in
                SPLKChatMessage(
                    text: Self.lines[(index + step) % Self.lines.count],
                    isOutgoing: step % 3 == 1,
                    date: start.addingTimeInterval(Double(step - 20) * 90)
                )
            }
            return SPLKChatConversation(contact: contact, messages: messages, unreadCount: index % 4 == 0 ? index % 7 + 1 : 0)
        }
    }

    var totalUnread: Int {
        conversations.filter { !$0.isMuted }.reduce(0) { $0 + $1.unreadCount }
    }

    func conversation(with contact: SPLKChatContact) -> SPLKChatConversation {
        if let existing = conversations.first(where: { $0.contact == contact }) {
            return existing
        }
        let conversation = SPLKChatConversation(contact: contact, messages: [], unreadCount: 0)
        conversations.insert(conversation, at: 0)
        notify()
        return conversation
    }

    func send(_ text: String, in conversation: SPLKChatConversation) {
        append(SPLKChatMessage(text: text, isOutgoing: true, date: Date()), to: conversation)
    }

    func receive(_ text: String, in conversation: SPLKChatConversation, read: Bool) {
        if !read {
            conversation.unreadCount += 1
        }
        append(SPLKChatMessage(text: text, isOutgoing: false, date: Date()), to: conversation)
    }

    func markRead(_ conversation: SPLKChatConversation) {
        guard conversation.unreadCount > 0 else { return }
        conversation.unreadCount = 0
        notify()
    }

    func delete(_ conversation: SPLKChatConversation) {
        conversations.removeAll { $0 === conversation }
        notify()
    }

    func clearHistory(of conversation: SPLKChatConversation) {
        conversation.messages.removeAll()
        conversation.unreadCount = 0
        notify()
    }

    func clearAllHistory() {
        conversations.forEach {
            $0.messages.removeAll()
            $0.unreadCount = 0
        }
        notify()
    }

    func autoReply(to text: String) -> String {
        let replies = ["Got it 👍", "Interesting, tell me more.", "Sure!", "Echo: \(text)", "Let me think about it.", "😂"]
        return replies[abs(text.hashValue) % replies.count]
    }

    private func append(_ message: SPLKChatMessage, to conversation: SPLKChatConversation) {
        conversation.messages.append(message)
        if let index = conversations.firstIndex(where: { $0 === conversation }), index > 0 {
            conversations.remove(at: index)
            conversations.insert(conversation, at: 0)
        }
        notify()
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}

enum SPLKChatFormat {

    private static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    static func listDate(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? time.string(from: date) : day.string(from: date)
    }
}
