class User {
  String name;
  String bloodType;
  String height;
  String weight;
  String profileImage;
  String email;
  String phone;
  String emergencyContact;

  User({
    required this.name,
    required this.bloodType,
    required this.height,
    required this.weight,
    required this.profileImage,
    this.email = "",
    this.phone = "",
    this.emergencyContact = "",
  });
}

User currentUser = User(
  name: "Loading...",
  bloodType: "N/A",
  height: "N/A",
  weight: "N/A",
  profileImage: "",
);
