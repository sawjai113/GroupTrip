import Foundation
import Supabase

enum SupabaseConfig {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://dpmijgrlvnpxmiarwkrf.supabase.co")!,
        supabaseKey: "sb_publishable_QO9lmMHkzlkalLywJ6g6RQ_GYAFJHHL"
    )
}
