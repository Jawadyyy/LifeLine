class User {
  String name;
  String bloodType;
  String height;
  String weight;
  String profileImage;
  String? email;
  String? phone;
  String? emergencyContact;
  String? disease;
  String? allergy;
  String? address;
  String? age;
  String? emergencyText;
  String? bmi;

  User({
    required this.name,
    required this.bloodType,
    required this.height,
    required this.weight,
    required this.profileImage,
    this.email,
    this.phone,
    this.emergencyContact,
    this.disease,
    this.allergy,
    this.address,
    this.age,
    this.emergencyText,
    this.bmi,
  });
}

User currentUser = User(
  name: "Loading...",
  bloodType: "N/A",
  height: "N/A",
  weight: "N/A",
  profileImage: "",
  bmi: "N/A",
);
