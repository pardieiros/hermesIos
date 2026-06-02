import 'package:url_launcher/url_launcher.dart';

class EmailService {
  static final EmailService _instance = EmailService._();
  factory EmailService() => _instance;
  EmailService._();

  Future<bool> compose({
    required String to,
    String? subject,
    String? body,
    List<String>? cc,
  }) async {
    final params = <String>[];
    if (subject != null) params.add('subject=${Uri.encodeComponent(subject)}');
    if (body != null) params.add('body=${Uri.encodeComponent(body)}');
    if (cc != null && cc.isNotEmpty) {
      params.add('cc=${cc.map(Uri.encodeComponent).join(',')}');
    }

    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final uri = Uri.parse('mailto:${Uri.encodeComponent(to)}$query');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  Future<bool> openInbox() async {
    // On iOS, tries to open the Mail app directly.
    final uri = Uri.parse('message://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }
}
