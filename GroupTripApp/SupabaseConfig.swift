import Foundation
import Supabase

enum SupabaseConfig {
    static let googleOAuthCallbackScheme = "com.googleusercontent.apps.698662305037-53om03eo495ihep40hajtarku2bjgktp"
    static let googleOAuthRedirectURL = URL(string: "\(googleOAuthCallbackScheme)://auth-callback")
    static let googleOAuthQueryParams = [(name: "prompt", value: "select_account")]
    static let googleOAuthPrefersEphemeralWebSession = true

    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://dpmijgrlvnpxmiarwkrf.supabase.co")!,
        supabaseKey: "sb_publishable_QO9lmMHkzlkalLywJ6g6RQ_GYAFJHHL"
    )
}
