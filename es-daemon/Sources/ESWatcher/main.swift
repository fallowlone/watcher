import EndpointSecurity
import Foundation

// MARK: - Config

let watchPath: String = {
    if CommandLine.arguments.count > 1 {
        return CommandLine.arguments[1]
    }
    return ProcessInfo.processInfo.environment["WATCH_PATH"] ?? ""
}()

guard !watchPath.isEmpty else {
    fputs("Usage: ESWatcher <watch_path>\n", stderr)
    fputs("  or set WATCH_PATH env var\n", stderr)
    exit(1)
}

fputs("ESWatcher: blocking exec in \(watchPath)\n", stderr)

// MARK: - ES Client

var client: OpaquePointer?

let result = es_new_client(&client) { _, message in
    guard message.pointee.event_type == ES_EVENT_TYPE_AUTH_EXEC else { return }

    let exec = message.pointee.event.exec
    let pathToken = exec.target.pointee.executable.pointee.path
    let path = String(cString: pathToken.data)

    // Block execution of any file landing in the watched directory.
    // Files are allowed through only after VirusTotal clears them and
    // they are restored from quarantine (at which point they are no
    // longer in watchPath).
    if path.hasPrefix(watchPath) {
        fputs("ES: BLOCKED \(path)\n", stderr)
        es_respond_auth_result(client!, message, ES_AUTH_RESULT_DENY, false)
    } else {
        es_respond_auth_result(client!, message, ES_AUTH_RESULT_ALLOW, false)
    }
}

switch result {
case ES_NEW_CLIENT_RESULT_SUCCESS:
    fputs("ES client ready.\n", stderr)

case ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED:
    fputs("""
    Error: must run as root.
      sudo \(CommandLine.arguments[0]) <watch_path>
    \n
    """, stderr)
    exit(1)

case ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED:
    fputs("""
    Error: com.apple.developer.endpoint-security.client entitlement missing.

    Two options:
      A) Development — disable SIP:
           1. Restart → hold power → Recovery Mode
           2. Utilities → Terminal → csrutil disable
           3. Reboot, then: sudo \(CommandLine.arguments[0]) <watch_path>

      B) Production — request Apple entitlement:
           https://developer.apple.com/contact/request/system-extension/
    \n
    """, stderr)
    exit(1)

case ES_NEW_CLIENT_RESULT_ERR_TOO_MANY_CLIENTS:
    fputs("Error: too many ES clients running.\n", stderr)
    exit(1)

default:
    fputs("Error: es_new_client failed (\(result.rawValue))\n", stderr)
    exit(1)
}

// Subscribe to AUTH_EXEC — fires BEFORE the kernel allows execution.
// We get a chance to deny it. Deadline: es_respond_auth_result must be
// called within the deadline or the kernel kills our client.
let events: [es_event_type_t] = [ES_EVENT_TYPE_AUTH_EXEC]
es_subscribe(client!, events, UInt32(events.count))

// Block main thread — ES callbacks fire on internal dispatch queue.
dispatchMain()
