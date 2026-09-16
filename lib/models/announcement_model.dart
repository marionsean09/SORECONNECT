class AnnouncementModel {

  final String title;
  final String content;
  final String? imageBase64;
  final String? imageMimeType;

  AnnouncementModel({
    required this.title,
    required this.content,
    this.imageBase64,
    this.imageMimeType,
  });

  Map<String, dynamic> toMap() {

    return {
      'title': title,
      'content': content,
      'imageBase64': imageBase64,
      'imageMimeType': imageMimeType,
    };
  }
}