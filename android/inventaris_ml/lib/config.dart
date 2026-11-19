class AppConfig {
  // Ganti IP jika menggunakan device fisik tanpa adb reverse (cth: 'http://192.168.1.X:8000')
  // Bila menggunakan adb reverse tcp:8000 tcp:8000, gunakan 'http://127.0.0.1:8000'
  // Bila Android Emulator standar, gunakan 'http://10.0.2.2:8000'
  static String apiBaseUrl = 'http://127.0.0.1:8000';

  static const String supabaseUrl = 'https://fxsepvbpefhuvjubhjmc.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4c2VwdmJwZWZodXZqdWJoam1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUwMjA5OTEsImV4cCI6MjExMDU5Njk5MX0.vKKL0Lqo4LukR14FQdawgxismhrDeqiPWb0EVfNMogQ';

  static const double decisionThreshold = 0.417;
}
