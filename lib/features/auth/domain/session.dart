/// Which half of the app the signed-in user works in.
///
/// The login response contract (`POST /api/v1/login`) documents only
/// `data.token`, `data.token_type`, `data.user.id` and
/// `data.user.company_id` — no role field. The portal is therefore chosen by
/// the user at sign-in and enforced by the server, which answers 403 on
/// role-prefixed routes the account cannot use. See the backend gap report.
enum Portal { client, employee }

class Session {
  const new({
    required this.token,
    required this.tokenType,
    required this.userId,
    required this.portal,
    this.companyId,
  });

  factory fromStorage(Map<String, String> values) {
    final portal = Portal.values.byName(values['portal']!);
    return Session(
      token: values['token']!,
      tokenType: values['token_type'] ?? 'Bearer',
      userId: int.parse(values['user_id']!),
      companyId: int.tryParse(values['company_id'] ?? ''),
      portal: portal,
    );
  }

  final String token;
  final String tokenType;
  final int userId;

  /// `data.user.company_id`; nullable because a client may not yet belong to
  /// a company.
  final int? companyId;
  final Portal portal;

  Map<String, String> toStorage() => {
    'token': token,
    'token_type': tokenType,
    'user_id': '$userId',
    if (companyId != null) 'company_id': '$companyId',
    'portal': portal.name,
  };
}

/// Result of `POST /api/v1/register` (201): `data.user.id`,
/// `data.verification_required`.
class RegistrationResult {
  const new({required this.userId, required this.verificationRequired});

  final int userId;
  final bool verificationRequired;
}
