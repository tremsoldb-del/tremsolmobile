class Ad {
  final String image;
  final String redirectUrl;

  Ad({required this.image, required this.redirectUrl});

  factory Ad.fromFirestore(Map<String, dynamic> data) {
    return Ad(
      image: data['image'] ?? '',
      redirectUrl: data['redirect_url'] ?? '',
    );
  }
}
