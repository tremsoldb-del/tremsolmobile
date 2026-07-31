import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tremsolapp/custom_ad/ad_model.dart';


Future<List<Ad>> fetchAds() async {
  QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('ads').get();
  return snapshot.docs
      .map((doc) => Ad.fromFirestore(doc.data() as Map<String, dynamic>))
      .toList();
}
