import Foundation
import Security

/// Verifies a connecting XPC caller's code signature against a requirement
/// string. The XPC helper uses two layers:
///
///   1. `NSXPCListener.setCodeSigningRequirement(_:)` — primary defense.
///      Set once at listener setup; the kernel rejects any connection
///      whose caller doesn't satisfy the requirement BEFORE the delegate
///      method is invoked. Apple's recommended approach since macOS 13.
///
///   2. `XPCSignatureGuard.validate(callerCode:requirement:)` — defense
///      in depth in the delegate. Re-asserts the same requirement on the
///      connection's audit-token-derived SecCode; refuses if the kernel
///      check was bypassed or the system is misconfigured.
///
/// Pure-ish: takes a SecCode and a requirement string, returns Bool. Unit
/// tests pass the test process's own SecCode to verify the requirement-
/// string syntax we ship actually does what we think it does.
public enum XPCSignatureGuard {

    /// Returns true iff `callerCode` satisfies `requirement`. False on any
    /// failure (malformed requirement, requirement not satisfied, missing
    /// signing info, anything else) — fail-closed.
    public static func validate(
        callerCode: SecCode,
        requirement: String
    ) -> Bool {
        // Empty / whitespace-only requirement is rejected up-front.
        // SecRequirementCreateWithString happens to accept an empty string
        // and produce a SecRequirement that matches anything — we refuse
        // to ship that as a "valid configuration".
        let trimmed = requirement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        var req: SecRequirement?
        let parseStatus = SecRequirementCreateWithString(
            trimmed as CFString, [], &req
        )
        guard parseStatus == errSecSuccess, let req else { return false }

        let evalStatus = SecCodeCheckValidity(callerCode, [], req)
        return evalStatus == errSecSuccess
    }

    /// Returns a SecCode for the currently-running process. Used by unit
    /// tests as a known-identity stand-in for an XPC caller.
    public static func currentProcessCode() -> SecCode? {
        var code: SecCode?
        let status = SecCodeCopySelf([], &code)
        guard status == errSecSuccess else { return nil }
        return code
    }
}
