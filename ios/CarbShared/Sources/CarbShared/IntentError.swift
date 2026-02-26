import Foundation

public enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let msg):
            return "\(msg)"
        }
    }
}
