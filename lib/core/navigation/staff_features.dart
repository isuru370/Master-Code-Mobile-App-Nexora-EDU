/// The staff app menu the server sent with the dashboard (role based, e.g.
/// "payment_delete"). Kept in memory so other pages can check it.
/// Empty until the dashboard has loaded.
class StaffFeatures {
  const StaffFeatures._();

  static List<String> _current = const [];

  static void set(List<String> features) => _current = List.unmodifiable(features);

  static bool has(String feature) => _current.contains(feature);
}
