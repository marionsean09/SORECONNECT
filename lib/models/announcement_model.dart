class AnnouncementModel {

  final String title;
  final String content;

  AnnouncementModel({
    required this.title,
    required this.content,
  });

  Map<String, dynamic> toMap() {

    return {
      'title': title,
      'content': content,
    };
  }
}