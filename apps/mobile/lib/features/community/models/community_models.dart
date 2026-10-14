// Plain data models mirroring /api/v1/community responses.

DateTime _dt(Object? v) => DateTime.parse(v as String).toLocal();

/// Backend `@db.Date` values arrive as UTC midnight. Rebuild from the UTC
/// components so the calendar day never shifts with the device timezone.
DateTime _dateOnly(Object? v) {
  final d = DateTime.parse(v as String).toUtc();
  return DateTime(d.year, d.month, d.day);
}

class CommunitySummary {
  const CommunitySummary({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.role,
    required this.status,
    required this.memberCount,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String role; // admin | member
  final String status; // active | on_hold | pending
  final int memberCount;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  bool get isAdmin => role == 'admin';
  bool get isPending => status == 'pending';

  factory CommunitySummary.fromJson(Map<String, dynamic> j) {
    final last = j['lastMessage'] as Map<String, dynamic>?;
    return CommunitySummary(
      id: j['id'] as String,
      name: j['name'] as String,
      description: j['description'] as String?,
      avatarUrl: j['avatarUrl'] as String?,
      role: j['role'] as String,
      status: j['status'] as String,
      memberCount: (j['memberCount'] as num).toInt(),
      lastMessagePreview: last == null
          ? null
          : (last['body'] as String?) ?? _kindLabel(last['kind'] as String),
      lastMessageAt: last == null ? null : _dt(last['createdAt']),
    );
  }
}

String _kindLabel(String kind) => switch (kind) {
      'media' => 'Attachment',
      'notepad_share' => 'Shared a notepad',
      'challenge_event' => 'New challenge',
      _ => 'Message',
    };

/// Result row of the name search / invite-code preview.
class CommunitySearchResult {
  const CommunitySearchResult({
    required this.id,
    required this.name,
    this.description,
    required this.memberCount,
    required this.requireApproval,
  });

  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final bool requireApproval;

  factory CommunitySearchResult.fromJson(Map<String, dynamic> j) =>
      CommunitySearchResult(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        memberCount:
            ((j['_count'] as Map<String, dynamic>)['members'] as num).toInt(),
        requireApproval: j['requireApproval'] as bool,
      );
}

class CommunityDetail {
  const CommunityDetail({
    required this.id,
    required this.name,
    this.description,
    required this.isPublic,
    required this.requireApproval,
    required this.membersCanChat,
    required this.membersCanInvite,
    required this.memberCount,
    this.inviteCode,
    required this.role,
    required this.status,
    required this.shareReport,
  });

  final String id;
  final String name;
  final String? description;
  final bool isPublic;
  final bool requireApproval;
  final bool membersCanChat;
  final bool membersCanInvite;
  final int memberCount;
  final String? inviteCode;
  final String role;
  final String status;
  final bool shareReport;

  bool get isAdmin => role == 'admin';
  bool get canPost => isAdmin || membersCanChat;

  factory CommunityDetail.fromJson(Map<String, dynamic> j) {
    final me = j['me'] as Map<String, dynamic>;
    return CommunityDetail(
      id: j['id'] as String,
      name: j['name'] as String,
      description: j['description'] as String?,
      isPublic: j['isPublic'] as bool,
      requireApproval: j['requireApproval'] as bool,
      membersCanChat: j['membersCanChat'] as bool,
      membersCanInvite: j['membersCanInvite'] as bool,
      memberCount: (j['memberCount'] as num).toInt(),
      inviteCode: j['inviteCode'] as String?,
      role: me['role'] as String,
      status: me['status'] as String,
      shareReport: me['shareReport'] as bool,
    );
  }
}

class CommunityMemberInfo {
  const CommunityMemberInfo({
    required this.userId,
    required this.name,
    required this.role,
    required this.status,
    this.shareReport,
    required this.joinedAt,
  });

  final String userId;
  final String name;
  final String role;
  final String status; // active | on_hold | pending | left
  final bool? shareReport; // only present for admin / self
  final DateTime joinedAt;

  factory CommunityMemberInfo.fromJson(Map<String, dynamic> j) =>
      CommunityMemberInfo(
        userId: j['userId'] as String,
        name: j['name'] as String,
        role: j['role'] as String,
        status: j['status'] as String,
        shareReport: j['shareReport'] as bool?,
        joinedAt: _dt(j['joinedAt']),
      );
}

class ChatAuthor {
  const ChatAuthor({required this.id, required this.name});
  final String id;
  final String name;
}

class ReplyPreview {
  const ReplyPreview({required this.authorName, this.body});
  final String authorName;
  final String? body;
}

class CommunityMessage {
  const CommunityMessage({
    required this.id,
    required this.kind,
    required this.author,
    required this.createdAt,
    required this.deleted,
    this.body,
    this.mediaType,
    this.mediaName,
    this.mediaUrl,
    this.payload,
    this.replyTo,
  });

  final String id;
  final String kind; // text | update | media | notepad_share | challenge_event
  final ChatAuthor author;
  final DateTime createdAt;
  final bool deleted;
  final String? body;
  final String? mediaType; // image | video | document
  final String? mediaName;
  final String? mediaUrl;
  final Map<String, dynamic>? payload;
  final ReplyPreview? replyTo;

  factory CommunityMessage.fromJson(Map<String, dynamic> j) {
    final a = j['author'] as Map<String, dynamic>;
    final r = j['replyTo'] as Map<String, dynamic>?;
    return CommunityMessage(
      id: j['id'] as String,
      kind: j['kind'] as String,
      author: ChatAuthor(id: a['id'] as String, name: a['name'] as String),
      createdAt: _dt(j['createdAt']),
      deleted: j['deleted'] as bool,
      body: j['body'] as String?,
      mediaType: j['mediaType'] as String?,
      mediaName: j['mediaName'] as String?,
      mediaUrl: j['mediaUrl'] as String?,
      payload: j['payload'] as Map<String, dynamic>?,
      replyTo: r == null
          ? null
          : ReplyPreview(
              authorName: r['authorName'] as String,
              body: r['body'] as String?,
            ),
    );
  }
}

class ChallengeProgress {
  const ChallengeProgress({
    required this.startDate,
    required this.status,
    required this.completedDays,
    required this.totalDays,
  });

  final DateTime startDate;
  final String status; // active | completed | abandoned
  final int completedDays;
  final int totalDays;

  double get fraction =>
      totalDays == 0 ? 0 : (completedDays / totalDays).clamp(0, 1).toDouble();
}

class ChallengeSummary {
  const ChallengeSummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.totalDays,
    required this.status,
    required this.creatorName,
    required this.participantCount,
    this.mine,
  });

  final String id;
  final String kind; // personal | group
  final String title;
  final String description;
  final int totalDays;
  final String status; // open | closed
  final String creatorName;
  final int participantCount;
  final ChallengeProgress? mine;

  bool get isGroup => kind == 'group';

  factory ChallengeSummary.fromJson(Map<String, dynamic> j) {
    final m = j['mine'] as Map<String, dynamic>?;
    final total = (j['totalDays'] as num).toInt();
    return ChallengeSummary(
      id: j['id'] as String,
      kind: j['kind'] as String,
      title: j['title'] as String,
      description: j['description'] as String,
      totalDays: total,
      status: j['status'] as String,
      creatorName: (j['creator'] as Map<String, dynamic>)['name'] as String,
      participantCount: (j['participantCount'] as num).toInt(),
      mine: m == null
          ? null
          : ChallengeProgress(
              startDate: _dateOnly(m['startDate']),
              status: m['status'] as String,
              completedDays: (m['completedDays'] as num).toInt(),
              totalDays: total,
            ),
    );
  }
}

class ParticipantInfo {
  const ParticipantInfo({
    required this.userId,
    required this.name,
    required this.completedDays,
    required this.status,
  });

  final String userId;
  final String name;
  final int completedDays;
  final String status;
}

class ChallengeDetail {
  const ChallengeDetail({
    required this.id,
    required this.communityId,
    required this.kind,
    required this.title,
    required this.description,
    required this.totalDays,
    required this.status,
    required this.creatorId,
    this.startDate,
    this.myStatus,
    required this.dayNotes,
    required this.completedDayNumbers,
    required this.participants,
  });

  final String id;
  /// Null for personal challenges (they belong to the user, not a community).
  final String? communityId;
  final String kind;
  final String title;
  final String description;
  final int totalDays;
  final String status;
  final String creatorId;
  final DateTime? startDate; // null when the caller is not participating
  final String? myStatus;

  /// Notepad text per challenge day (1-based); missing = nothing written.
  final Map<int, String> dayNotes;
  final Set<int> completedDayNumbers;
  final List<ParticipantInfo> participants;

  bool get isGroup => kind == 'group';
  bool get joined => startDate != null;
  int get completedDays => completedDayNumbers.length;

  factory ChallengeDetail.fromJson(Map<String, dynamic> j) {
    final mine = j['mine'] as Map<String, dynamic>?;
    final checkins = (mine?['checkins'] as List<dynamic>? ?? const [])
        .map((e) => ((e as Map<String, dynamic>)['dayNumber'] as num).toInt())
        .toSet();
    return ChallengeDetail(
      id: j['id'] as String,
      communityId: j['communityId'] as String?,
      kind: j['kind'] as String,
      title: j['title'] as String,
      description: j['description'] as String,
      totalDays: (j['totalDays'] as num).toInt(),
      status: j['status'] as String,
      creatorId: j['creatorId'] as String,
      startDate: mine == null ? null : _dateOnly(mine['startDate']),
      myStatus: mine?['status'] as String?,
      dayNotes: {
        for (final e in (mine?['dayNotes'] as List<dynamic>? ?? const []))
          ((e as Map<String, dynamic>)['dayNumber'] as num).toInt():
              e['notes'] as String,
      },
      completedDayNumbers: checkins,
      participants: (j['participants'] as List<dynamic>)
          .map((e) {
            final p = e as Map<String, dynamic>;
            return ParticipantInfo(
              userId: p['userId'] as String,
              name: p['name'] as String,
              completedDays: (p['completedDays'] as num).toInt(),
              status: p['status'] as String,
            );
          })
          .toList(),
    );
  }
}

class MemberReport {
  const MemberReport({
    required this.name,
    required this.status,
    required this.from,
    required this.to,
    required this.frozen,
    this.goal,
    required this.workoutCount,
    required this.workoutMinutes,
    required this.caloriesBurned,
    required this.loggedDays,
    this.avgCalories,
    this.avgProteinG,
    this.startKg,
    this.latestKg,
    this.changeKg,
    required this.streakDays,
    required this.challenges,
  });

  final String name;
  final String status;
  final DateTime from;
  final DateTime to;
  final bool frozen;
  final String? goal;
  final int workoutCount;
  final int workoutMinutes;
  final int caloriesBurned;
  final int loggedDays;
  final int? avgCalories;
  final int? avgProteinG;
  final double? startKg;
  final double? latestKg;
  final double? changeKg;
  final int streakDays;
  final List<ChallengeSummaryRow> challenges;

  factory MemberReport.fromJson(Map<String, dynamic> j) {
    final member = j['member'] as Map<String, dynamic>;
    final w = j['window'] as Map<String, dynamic>;
    final wo = j['workouts'] as Map<String, dynamic>;
    final n = j['nutrition'] as Map<String, dynamic>;
    final wt = j['weight'] as Map<String, dynamic>;
    return MemberReport(
      name: member['name'] as String,
      status: member['status'] as String,
      from: _dt(w['from']),
      to: _dt(w['to']),
      frozen: w['frozen'] as bool,
      goal: j['goal'] as String?,
      workoutCount: (wo['count'] as num).toInt(),
      workoutMinutes: (wo['totalMinutes'] as num).toInt(),
      caloriesBurned: (wo['caloriesBurned'] as num).toInt(),
      loggedDays: (n['loggedDays'] as num).toInt(),
      avgCalories: (n['avgCalories'] as num?)?.toInt(),
      avgProteinG: (n['avgProteinG'] as num?)?.toInt(),
      startKg: (wt['startKg'] as num?)?.toDouble(),
      latestKg: (wt['latestKg'] as num?)?.toDouble(),
      changeKg: (wt['changeKg'] as num?)?.toDouble(),
      streakDays: (j['streakDays'] as num).toInt(),
      challenges: (j['challenges'] as List<dynamic>).map((e) {
        final c = e as Map<String, dynamic>;
        return ChallengeSummaryRow(
          title: c['title'] as String,
          kind: c['kind'] as String,
          completedDays: (c['completedDays'] as num).toInt(),
          totalDays: (c['totalDays'] as num).toInt(),
          status: c['status'] as String,
        );
      }).toList(),
    );
  }
}

class ChallengeSummaryRow {
  const ChallengeSummaryRow({
    required this.title,
    required this.kind,
    required this.completedDays,
    required this.totalDays,
    required this.status,
  });

  final String title;
  final String kind;
  final int completedDays;
  final int totalDays;
  final String status;
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.done,
    required this.repeatDaily,
    required this.isCopy,
  });

  final String id;
  final String title;
  final bool done;
  final bool repeatDaily;
  final bool isCopy;

  TodoItem copyWith({bool? done, String? title}) => TodoItem(
        id: id,
        title: title ?? this.title,
        done: done ?? this.done,
        repeatDaily: repeatDaily,
        isCopy: isCopy,
      );

  factory TodoItem.fromJson(Map<String, dynamic> j) => TodoItem(
        id: j['id'] as String,
        title: j['title'] as String,
        done: j['done'] as bool,
        repeatDaily: j['repeatDaily'] as bool,
        isCopy: j['templateId'] != null,
      );
}

/// Local calendar date as YYYY-MM-DD — the format the API expects.
String localDateString([DateTime? d]) {
  final x = d ?? DateTime.now();
  final mm = x.month.toString().padLeft(2, '0');
  final dd = x.day.toString().padLeft(2, '0');
  return '${x.year}-$mm-$dd';
}
