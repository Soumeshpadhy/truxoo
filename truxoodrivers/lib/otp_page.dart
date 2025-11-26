import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'driver_side_home.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  final Map<String, dynamic> driverData; // ✅ FIX: ADDED REQUIRED PARAMETER
  
  const OtpPage({
    super.key, 
    required this.phoneNumber,
    required this.driverData, // ✅ FIX: ADDED TO CONSTRUCTOR
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with TickerProviderStateMixin {
  
  // --- UI/Animation Variables ---
  static const Duration _animationDuration = Duration(milliseconds: 800);
  static const int _otpLength = 6; 
  static const double _largeScreenBreakpoint = 600;
  static const double _smallScreenBreakpoint = 360;
  static const double _inputWidthRatio = 0.8;
  static const double _maxInputWidth = 289.0;
  static const double _paddingRatio = 0.04;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late List<AnimationController> _digitControllers;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late List<Animation<double>> _digitAnimations;

  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 30;
  Timer? _resendTimer;
  
  // --- FIREBASE/BACKEND Variables ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId; 
  
  // ⚠️ NOTE: Changed placeholder to common Android Emulator IP
  static const String _baseUrl = 'http://10.0.2.2:3000'; 
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    
    // START OTP PROCESS AS SOON AS THE PAGE LOADS
    _sendOtp(isResend: false);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }
  
  // ------------------------------------
  // --- FIREBASE AND BACKEND LOGIC ---
  // ------------------------------------
  
  Future<void> _sendOtp({bool isResend = true}) async {
    if (isResend) {
      _resetResendTimer();
      _otpController.clear();
      setState(() => _isLoading = true);
    }
    
    // Ensure the E.164 format: +<country code><phone number>
    // **ADJUST THE COUNTRY CODE (+91) AS NEEDED FOR YOUR PROJECT.**
    final fullPhoneNumber = '+91${widget.phoneNumber}';
    print('Attempting to send OTP to: $fullPhoneNumber'); // Debug Log

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        timeout: const Duration(seconds: 60), 
        
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId; 
          if (mounted) {
            setState(() => _isLoading = false);
            _startResendTimer(); 
            if (isResend) {
              _showSuccessSnackBar('New OTP sent successfully!');
            }
            print('✅ Code Sent successfully. Verification ID: $_verificationId'); // Debug Log
          }
        },

        verificationCompleted: (PhoneAuthCredential credential) async {
          if (mounted) {
            print('✅ Auto-verification complete.'); // Debug Log
            await _auth.signInWithCredential(credential);
            _onVerificationSuccess();
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            
            // 🛑 CRITICAL DEBUGGING LINE: Log the exact Firebase error code
            print('🛑 Firebase Verification Failed: Code: ${e.code}, Message: ${e.message}');
            
            String message = 'Verification failed. Please check the number.';
            if (e.code == 'invalid-phone-number') {
              message = 'The provided phone number is not valid.';
            } else if (e.code == 'app-not-authorized') {
              message = 'App not authorized. Check SHA keys or bundle ID in Firebase.';
            } else if (e.code == 'operation-not-allowed') {
              message = 'Phone sign-in disabled or billing issue. Check Firebase Console.';
            }

            _showErrorSnackBar(message);
          }
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          print('⏰ Auto retrieval timeout. Verification ID saved: $_verificationId'); // Debug Log
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('🛑 General Error during OTP send: $e'); // Debug Log
        _showErrorSnackBar('An error occurred. Check network connection.');
      }
    }
  }

  void _resendOtp() async {
    if (_canResend && !_isLoading) {
      HapticFeedback.lightImpact();
      _sendOtp(isResend: true);
    }
  }

  void _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != _otpLength) {
      _showErrorSnackBar('Please enter the exact $_otpLength-digit OTP');
      return;
    }

    if (_verificationId == null) {
      _showErrorSnackBar('Verification process not started. Please resend the OTP.');
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      // 1. Create the credential using the stored ID and user input
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      
      // 2. Sign in/Verify the user
      await _auth.signInWithCredential(credential);

      // 3. Success handling
      await _onVerificationSuccess();
      
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = 'Invalid OTP. Please check the code and try again.';
        if (e.code == 'invalid-verification-code') {
          message = 'The code you entered is incorrect.';
        }
        _showErrorSnackBar(message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('An unexpected error occurred during verification.');
      }
    }
  }

  Future<void> _updateBackendVerificationStatus(String mobileNumber) async {
    final url = Uri.parse('$_baseUrl/verify-driver');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile': mobileNumber}),
      );

      if (response.statusCode != 200) {
        print('Backend update failed (Status ${response.statusCode}): ${response.body}');
      } else {
        print('Backend update successful for $mobileNumber');
      }
    } catch (e) {
      print('Network error updating backend status: $e');
    }
  }
  
  Future<void> _onVerificationSuccess() async {
      // 1. Call your Node.js backend to set the 'is_verified' flag in Firestore
      await _updateBackendVerificationStatus(widget.phoneNumber);
      
      if (mounted) {
       setState(() => _isLoading = false);
       HapticFeedback.mediumImpact();
       
       // Navigate to the main screen using MaterialPageRoute for standard transition
       Navigator.pushReplacement(
         context,
         MaterialPageRoute(
           builder: (context) => const DriverSideHome(),
         ),
       );
      }
  }
  
  // ------------------------------------
  // --- UI/ANIMATION METHODS ---
  // ------------------------------------

  void _initializeAnimations() {
    _fadeController = AnimationController(duration: _animationDuration, vsync: this,);
    _scaleController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this,);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut,);
    _scaleAnimation = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut,);
    _digitControllers = List.generate(_otpLength, (index) {
      return AnimationController(duration: const Duration(milliseconds: 300), vsync: this,);
    });
    _digitAnimations = _digitControllers.map((controller) {
      return CurvedAnimation(parent: controller, curve: Curves.elasticOut,);
    }).toList();
  }

  void _startAnimations() {
    _fadeController.forward();
    for (int i = 0; i < _digitControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 200 + (i * 100)), () {
        if (mounted) {
          _digitControllers[i].forward();
        }
      });
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel(); 
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _resetResendTimer() {
    setState(() {
      _canResend = false;
      _resendCountdown = 30;
    });
  }

  void _animateDigitEntry(int index) {
    if (index < _digitControllers.length) {
      _digitControllers[index].forward().then((_) {
        _digitControllers[index].reverse();
      });
    }
  }

  @override
  void dispose() {
    _otpController.dispose(); 
    _focusNode.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _resendTimer?.cancel();
    
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    
    super.dispose();
  }

  Map<String, double> _getResponsiveSizes(double screenWidth, double screenHeight) {
    final isLargeScreen = screenWidth > _largeScreenBreakpoint;
    final isSmallScreen = screenWidth < _smallScreenBreakpoint;
    
    return {
      'headerFontSize': isLargeScreen ? 20.0 : (isSmallScreen ? 14.0 : 16.0),
      'digitFontSize': isLargeScreen ? 28.0 : (isSmallScreen ? 20.0 : 24.0),
      'labelFontSize': isLargeScreen ? 14.0 : (isSmallScreen ? 9.0 : 10.0),
      'buttonFontSize': isLargeScreen ? 18.0 : (isSmallScreen ? 14.0 : 16.0),
      'verticalSpacing': screenHeight * 0.03,
      'inputWidth': (screenWidth * _inputWidthRatio > _maxInputWidth) 
          ? _maxInputWidth 
          : screenWidth * _inputWidthRatio,
    };
  }

  // --- UI Build Methods ---

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final sizes = _getResponsiveSizes(screenWidth, screenHeight);
    
    return Scaffold(
      appBar: _buildAppBar(screenHeight, screenWidth > _largeScreenBreakpoint),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(screenWidth, sizes),
              SizedBox(height: sizes['verticalSpacing']!),
              _buildOtpInput(sizes),
              SizedBox(height: sizes['verticalSpacing']!),
              _buildResendSection(screenWidth, sizes),
              SizedBox(height: screenHeight * 0.03),
              _buildActionButtons(screenWidth, screenHeight, sizes),
              SizedBox(height: screenHeight * 0.02),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(double screenHeight, bool isLargeScreen) {
    return PreferredSize(
      preferredSize: Size.fromHeight(screenHeight * 0.08), 
      child: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: isLargeScreen ? 28 : 24,),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader(double screenWidth, Map<String, double> sizes) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * _paddingRatio),
      child: Center(
        child: Text(
          'Please Wait. We will auto verify OTP sent to +91 ${widget.phoneNumber}', 
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: sizes['headerFontSize'],
            height: 1.4,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpInput(Map<String, double> sizes) {
    final inputWidth = sizes['inputWidth']!;
    final digitBoxWidth = (inputWidth - 30) / _otpLength;
    
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: inputWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_otpLength, (index) {
                return AnimatedBuilder(
                  animation: _digitAnimations[index],
                  builder: (context, child) {
                    final hasValue = index < _otpController.text.length;
                    final isCurrent = index == _otpController.text.length;
                    
                    return Transform.scale(
                      scale: 1.0 + (_digitAnimations[index].value * 0.1),
                      child: Container(
                        width: digitBoxWidth,
                        height: digitBoxWidth * 1.2,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: hasValue 
                                  ? Colors.black 
                                  : (isCurrent ? Colors.blue : Colors.grey),
                              width: hasValue || isCurrent ? 2.0 : 1.0,
                            ),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            hasValue ? _otpController.text[index] : '',
                            key: ValueKey('$index-${hasValue ? _otpController.text[index] : ''}'),
                            style: TextStyle(
                              fontSize: sizes['digitFontSize'],
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),

          Positioned.fill(
            child: TextField(
              controller: _otpController,
              focusNode: _focusNode,
              autofocus: true, 
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done, 
              maxLength: _otpLength,
              enableInteractiveSelection: false, 
              showCursor: false, 
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 1, 
                height: 1, 
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: false, 
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_otpLength), 
              ],
              onChanged: (value) {
                setState(() {});
                
                if (value.isNotEmpty) {
                  HapticFeedback.selectionClick();
                  _animateDigitEntry(value.length - 1);
                }
                
                if (value.length == _otpLength) {
                  _focusNode.unfocus(); 
                  _verifyOtp(); // Auto-trigger verification
                }
              },
              onTap: () {
                if (!_focusNode.hasFocus) {
                  _focusNode.requestFocus();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendSection(double screenWidth, Map<String, double> sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: screenWidth * 0.09),
          child: Text(
            "Didn't receive OTP?",
            style: TextStyle(
              fontSize: sizes['labelFontSize'],
              color: Colors.grey[600],
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _canResend
                ? TextButton(
                    key: const ValueKey('resend'),
                    onPressed: _resendOtp,
                    child: Text(
                      'Resend OTP',
                      style: TextStyle(
                        fontSize: sizes['labelFontSize'],
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  )
                : Text(
                    key: const ValueKey('countdown'),
                    'Resend OTP in ${_resendCountdown}s',
                    style: TextStyle(
                      fontSize: sizes['labelFontSize'],
                      color: Colors.grey[600],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(double screenWidth, double screenHeight, Map<String, double> sizes) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: TextButton(
          onPressed: (_isLoading || _otpController.text.length != _otpLength) ? null : _verifyOtp,
          style: TextButton.styleFrom(
            backgroundColor: (_isLoading || _otpController.text.length != _otpLength) ? Colors.grey[300] : Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: Size(screenWidth * 0.8, screenHeight * 0.06),
            padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                  ),
                )
              : Text(
                  'Verify OTP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: sizes['buttonFontSize'],
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    HapticFeedback.heavyImpact(); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}