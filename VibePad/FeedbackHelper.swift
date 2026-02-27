import AppKit

enum FeedbackHelper {
    private static let githubIssuesURL = URL(string: "https://github.com/ignatovv/VibePad/issues")!

    static func openFeedback(subject: String = "VibePad Feedback", body: String = "") {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "feedback@vibepad.now"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]

        guard let mailtoURL = components.url,
              NSWorkspace.shared.urlForApplication(toOpen: mailtoURL) != nil else {
            NSWorkspace.shared.open(githubIssuesURL)
            return
        }

        NSWorkspace.shared.open(mailtoURL)
    }
}
