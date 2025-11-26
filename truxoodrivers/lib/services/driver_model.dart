class DriverModel {
  String? fullName;
  String? phoneNumber;
  String? email;
  String? address;

  String? vehicleType;
  String? vehicleNumber;
  String? drivingLicenseNumber;
  String? licenseImageUrl;
  String? aadharNumber;
  String? aadharImageUrl;
  String? profileImageUrl;

  String? experienceYears;
  String? panNumber;
  String? panImageUrl;

  // Constructor
  DriverModel({
    this.fullName,
    this.phoneNumber,
    this.email,
    this.address,
    this.vehicleType,
    this.vehicleNumber,
    this.drivingLicenseNumber,
    this.licenseImageUrl,
    this.aadharNumber,
    this.aadharImageUrl,
    this.profileImageUrl,
    this.experienceYears,
    this.panNumber,
    this.panImageUrl,
  });

  // Convert model → Map (for Firebase)
  Map<String, dynamic> toMap() {
    return {
      "fullName": fullName,
      "phoneNumber": phoneNumber,
      "email": email,
      "address": address,
      "vehicleType": vehicleType,
      "vehicleNumber": vehicleNumber,
      "drivingLicenseNumber": drivingLicenseNumber,
      "licenseImageUrl": licenseImageUrl,
      "aadharNumber": aadharNumber,
      "aadharImageUrl": aadharImageUrl,
      "profileImageUrl": profileImageUrl,
      "experienceYears": experienceYears,
      "panNumber": panNumber,
      "panImageUrl": panImageUrl,
    };
  }

  // Convert Firebase Map → Model  
  factory DriverModel.fromMap(Map<String, dynamic> map) {
    return DriverModel(
      fullName: map["fullName"],
      phoneNumber: map["phoneNumber"],
      email: map["email"],
      address: map["address"],
      vehicleType: map["vehicleType"],
      vehicleNumber: map["vehicleNumber"],
      drivingLicenseNumber: map["drivingLicenseNumber"],
      licenseImageUrl: map["licenseImageUrl"],
      aadharNumber: map["aadharNumber"],
      aadharImageUrl: map["aadharImageUrl"],
      profileImageUrl: map["profileImageUrl"],
      experienceYears: map["experienceYears"],
      panNumber: map["panNumber"],
      panImageUrl: map["panImageUrl"],
    );
  }
}
