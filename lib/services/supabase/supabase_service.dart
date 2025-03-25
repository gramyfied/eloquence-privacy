import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://adyovmtayhxxdizzvspa.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFkeW92bXRheWh4eGRpenp2c3BhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgwOTQwOTksImV4cCI6MjA1MzY3MDA5OX0.YOt18gNkmPmU_ETmvvaNonuh8VyzsvdPXha3E7zTrjA';

  static final SupabaseClient client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  // Implement Supabase service methods here
}
