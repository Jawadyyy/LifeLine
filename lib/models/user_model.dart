class UserModel {
  final String name;
  final String bloodType;
  final String height;
  final String weight;
  final String profileImage;
  final String? email;
  final String? phone;
  final String? disease;
  final String? allergy;
  final String? address;
  final String? age;
  final String? emergencyText;
  final String? bmi;
  final bool isProfileComplete;

  UserModel({
    required this.name,
    required this.bloodType,
    required this.height,
    required this.weight,
    required this.profileImage,
    this.email,
    this.phone,
    this.disease,
    this.allergy,
    this.address,
    this.age,
    this.emergencyText,
    this.bmi,
    this.isProfileComplete = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      name: map['username'] ?? 'Loading...',
      bloodType: map['blood_group'] ?? 'N/A',
      height: map['height']?.toString() ?? 'N/A',
      weight: map['weight']?.toString() ?? 'N/A',
      profileImage: map['profile_image'] ?? '',
      email: map['email'],
      phone: map['phone'],
      disease: map['disease'],
      allergy: map['allergy'],
      address: map['home_address'],
      age: map['age'],
      emergencyText: map['emergency_text'],
      bmi: map['bmi'],
      isProfileComplete: map['isProfileComplete'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': name,
      'blood_group': bloodType,
      'height': height,
      'weight': weight,
      'profile_image': profileImage,
      'email': email,
      'phone': phone,
      'disease': disease,
      'allergy': allergy,
      'home_address': address,
      'age': age,
      'emergency_text': emergencyText,
      'bmi': bmi,
      'isProfileComplete': isProfileComplete,
    };
  }
}

UserModel currentUser = UserModel(
  name: "Loading...",
  bloodType: "N/A",
  height: "N/A",
  weight: "N/A",
  profileImage: "",
  email: "N/A",
  phone: "N/A",
  disease: "N/A",
  allergy: "N/A",
  address: "N/A",
  age: "N/A",
  emergencyText: "N/A",
  bmi: "N/A",
  isProfileComplete: false,
);
