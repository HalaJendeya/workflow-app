import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workflow_app/core/data/local_collection.dart';

enum MeetingStatus { scheduled, live, waiting, overdue, ended, cancelled }

enum MeetingFeature { chat, screen, whiteboard, files }

/// Presentation model for the Meetings frames (643:38772, 643:37740).
class Meeting implements Identified {
  const new({
    required this.id,
    required this.title,
    required this.description,
    required this.company,
    required this.code,
    required this.start,
    required this.end,
    required this.status,
    required this.participants,
    this.isPublic = true,
    this.invitationOnly = false,
    this.features = const {MeetingFeature.chat},
    this.createdBy = 'System',
    this.maxParticipants = 100,
    this.project,
  });

  @override
  final String id;
  final String title;
  final String description;
  final String company;
  final String code;
  final DateTime start;
  final DateTime end;
  final MeetingStatus status;
  final List<String> participants;
  final bool isPublic;
  final bool invitationOnly;
  final Set<MeetingFeature> features;
  final String createdBy;
  final int maxParticipants;
  final String? project;

  Duration get duration => end.difference(start);

  bool isOn(DateTime day) =>
      start.year == day.year &&
      start.month == day.month &&
      start.day == day.day;

  Meeting copyWith({MeetingStatus? status, List<String>? participants}) =>
      Meeting(
        id: id,
        title: title,
        description: description,
        company: company,
        code: code,
        start: start,
        end: end,
        status: status ?? this.status,
        participants: participants ?? this.participants,
        isPublic: isPublic,
        invitationOnly: invitationOnly,
        features: features,
        createdBy: createdBy,
        maxParticipants: maxParticipants,
        project: project,
      );
}

DateTime _at(int dayOffset, int h, [int m = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + dayOffset, h, m);
}

final meetingsProvider =
    NotifierProvider<LocalCollection<Meeting>, List<Meeting>>(
      () => LocalCollection<Meeting>(
        () => [
          Meeting(
            id: 'm1',
            title: 'Retrospective',
            description: 'Sprint retrospective',
            company: 'Creative Minds Agency',
            code: 'ZUC-287-6LJ',
            start: _at(0, 16),
            end: _at(0, 17),
            status: MeetingStatus.waiting,
            participants: const ['Rania El-Masri'],
            invitationOnly: true,
          ),
          Meeting(
            id: 'm2',
            title: 'Sprint Planning',
            description: 'Plan sprint 25 scope',
            company: 'Innovatech Solutions',
            code: 'BHU-232-CEK',
            start: _at(0, 17, 30),
            end: _at(0, 18, 30),
            status: MeetingStatus.live,
            participants: const ['Rania El-Masri', 'Karim Abdullah'],
            features: const {
              MeetingFeature.chat,
              MeetingFeature.screen,
              MeetingFeature.whiteboard,
            },
          ),
          Meeting(
            id: 'm3',
            title: 'Q3 Product Review',
            description: 'Quarterly product roadmap review',
            company: 'Advanced Tech Company',
            code: 'WF-2847',
            start: _at(3, 10),
            end: _at(3, 11),
            status: MeetingStatus.overdue,
            participants: const ['Ahmed', 'Sara', 'Liam', 'Amara'],
          ),
          Meeting(
            id: 'm4',
            title: 'Daily Standup',
            description: 'Daily team sync',
            company: 'Advanced Tech Company',
            code: 'WF-2848',
            start: _at(1, 9),
            end: _at(1, 9, 15),
            status: MeetingStatus.scheduled,
            participants: const [
              'Ahmed',
              'Sara',
              'Liam',
              'Amara',
              'Omar',
              'Lina',
            ],
          ),
        ],
      ),
    );
