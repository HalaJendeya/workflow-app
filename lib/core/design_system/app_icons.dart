import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icons exported from the Figma file as SVG (Iconly set and custom icons).
enum AppIcon {
  navHome('nav_home'),
  navCompanies('nav_companies'),
  navInvoices('nav_invoices'),
  navTasks('nav_tasks'),
  navProjects('nav_projects'),
  navSprints('nav_sprints'),
  navChat('nav_chat'),
  navMore('nav_more'),
  notification('notification'),
  search('search'),
  sliders('sliders'),
  message('message'),
  lock('lock'),
  hide('hide'),
  checkboxChecked('checkbox_checked'),
  profile('profile'),
  accountClient('account_client'),
  accountEmployee('account_employee'),
  statusDot('status_dot');

  new(this.file);
  final String file;

  String get asset => 'assets/icons/$file.svg';
}

/// Renders an [AppIcon]. Pass [color] to recolor a single-color icon (for
/// example selected navigation items); otherwise the Figma colors are kept.
class SvgIcon extends StatelessWidget {
  const new(this.icon, {this.size = 24, this.color, super.key});

  final AppIcon icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    icon.asset,
    width: size,
    height: size,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}
