import 'package:supabase_flutter/supabase_flutter.dart';

class UserSession {
  static String? uid;
  static String? email;
  static String role = 'resident';

  static Future<void> init() async {
    final supabase = Supabase.instance.client;

    final user = supabase.auth.currentUser;
    uid = user?.id;
    email = user?.email;

    if (uid == null) return;

    // CHECK ADMIN TABLE
    final admin = await supabase
        .from('admin_new')
        .select('id')
        .eq('id', uid!)
        .maybeSingle();

    if (admin != null) {
      role = 'admin';
      return;
    }

    // CHECK RESIDENT TABLE (optional but safer)
    final resident = await supabase
        .from('resident')
        .select('id')
        .eq('id', uid!)
        .maybeSingle();

    if (resident != null) {
      role = 'resident';
    }
  }

  static bool get isAdmin => role == 'admin';
  static bool get isResident => role == 'resident';
}