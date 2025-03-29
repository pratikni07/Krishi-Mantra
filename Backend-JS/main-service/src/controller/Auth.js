const axios = require("axios");
const bcrypt = require("bcrypt");
const User = require("../model/User");
const OTP = require("../model/OTP");
const jwt = require("jsonwebtoken");
const otpGenerator = require("otp-generator");
const mailSender = require("../utils/mailSender");
const { passwordUpdated } = require("../mail/templates/passwordUpdate");
const WhatsAppOTP = require("../model/WhatsappOTP");

const UserDetail = require("../model/UserDetail");
require("dotenv").config();

// Signup Controller for Registering Users
// exports.signup = async (req, res) => {
//   try {
//     const { name, firstName, lastName, email, password, phoneNo, image, otp } =
//       req.body;

//     // Check if required fields are present
//     if (!name || !phoneNo || !otp || !email || !password) {
//       return res.status(400).json({
//         success: false,
//         message: "Name, Phone Number, OTP, Email, and Password are required",
//       });
//     }

//     // Check if user already exists by phone number
//     const existingUser = await User.findOne({ email });
//     if (existingUser) {
//       return res.status(400).json({
//         success: false,
//         message: "User already exists. Please log in to continue.",
//       });
//     }

//     // Check if email is already registered
//     const existingEmail = await User.findOne({ email });
//     if (existingEmail) {
//       return res.status(400).json({
//         success: false,
//         message: "Email is already registered. Please log in.",
//       });
//     }

//     // Find the most recent OTP for the phone number
//     const recentOtp = await OTP.findOne({ email }).sort({ createdAt: -1 });

//     if (!recentOtp || recentOtp.otp !== otp) {
//       return res.status(400).json({
//         success: false,
//         message: "Invalid OTP. Please try again.",
//       });
//     }

//     // Hash password before saving
//     const hashedPassword = await bcrypt.hash(password, 10);

//     // Create additional user details
//     const profileDetails = await UserDetail.create({});

//     // Create user
//     const user = await User.create({
//       name,
//       firstName,
//       lastName,
//       email,
//       password: hashedPassword,
//       phoneNo,
//       additionalDetails: profileDetails._id,
//       image:
//         image ||
//         `https://api.dicebear.com/6.x/initials/svg?seed=${name}&backgroundColor=00897b,00acc1,039be5&backgroundType=solid`,
//     });

//     // Update profile details with userId
//     profileDetails.userId = user._id;
//     await profileDetails.save();

//     return res.status(201).json({
//       success: true,
//       user,
//       message: "User registered successfully. Please complete your profile.",
//     });
//   } catch (error) {
//     console.error("Signup Error:", error);
//     return res.status(500).json({
//       success: false,
//       message: "User registration failed. Please try again later.",
//     });
//   }
// };

// Login controller for authenticating users
// exports.login = async (req, res) => {
//   try {
//     const { email, password } = req.body;
//     if (!email || !password) {
//       return res.status(400).json({
//         success: false,
//         message: `Please Fill up All the Required Fields`,
//       });
//     }
//     const user = await User.findOne({ email }).populate("additionalDetails");
//     if (!user) {
//       // Return 401 Unauthorized status code with error message
//       return res.status(401).json({
//         success: false,
//         message: `User is not Registered with Us Please SignUp to Continue`,
//       });
//     }

//     // Generate JWT token and Compare Password
//     if (await bcrypt.compare(password, user.password)) {
//       const token = jwt.sign(
//         { email: user.email, id: user._id, accountType: user.accountType },
//         process.env.JWT_SECRET,
//         {
//           expiresIn: "24h",
//         }
//       );

//       user.token = token;
//       user.password = undefined;
//       const options = {
//         expires: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
//         httpOnly: true,
//       };
//       res.cookie("token", token, options).status(200).json({
//         success: true,
//         token,
//         user,
//         message: `User Login Success`,
//       });
//     } else {
//       return res.status(401).json({
//         success: false,
//         message: `Password is incorrect`,
//       });
//     }
//   } catch (error) {
//     console.error(error);
//     // Return 500 Internal Server Error status code with error message
//     return res.status(500).json({
//       success: false,
//       message: `Login Failure Please Try Again`,
//     });
//   }
// };

// Send OTP For Email Verification
// exports.sendotp = async (req, res) => {
//   try {
//     const { email } = req.body;

//     // Check if user is already present
//     // Find user with provided email
//     const checkUserPresent = await User.findOne({ email });
//     // to be used in case of signup

//     // If user found with provided email
//     if (checkUserPresent) {
//       // Return 401 Unauthorized status code with error message
//       return res.status(401).json({
//         success: false,
//         message: `User is Already Registered`,
//       });
//     }

//     var otp = otpGenerator.generate(6, {
//       upperCaseAlphabets: false,
//       lowerCaseAlphabets: false,
//       specialChars: false,
//     });
//     const result = await OTP.findOne({ otp: otp });
//     console.log("Result is Generate OTP Func");
//     console.log("OTP", otp);
//     console.log("Result", result);
//     while (result) {
//       otp = otpGenerator.generate(6, {
//         upperCaseAlphabets: false,
//       });
//     }
//     const otpPayload = { email, otp };
//     const otpBody = await OTP.create(otpPayload);
//     console.log("OTP Body", otpBody);

//     res.status(200).json({
//       success: true,
//       message: `OTP Sent Successfully`,
//       otp,
//     });
//   } catch (error) {
//     console.log(error.message);
//     return res.status(500).json({ success: false, error: error.message });
//   }
// };

// Controller for Changing Password
exports.changePassword = async (req, res) => {
  try {
    // Get user data from req.user
    const userDetails = await User.findById(req.user.id);

    // Get old password, new password, and confirm new password from req.body
    const { oldPassword, newPassword, confirmNewPassword } = req.body;

    // Validate old password
    const isPasswordMatch = await bcrypt.compare(
      oldPassword,
      userDetails.password
    );
    if (oldPassword === newPassword) {
      return res.status(400).json({
        success: false,
        message: "New Password cannot be same as Old Password",
      });
    }

    if (!isPasswordMatch) {
      // If old password does not match, return a 401 (Unauthorized) error
      return res
        .status(401)
        .json({ success: false, message: "The password is incorrect" });
    }

    // Match new password and confirm new password
    if (newPassword !== confirmNewPassword) {
      // If new password and confirm new password do not match, return a 400 (Bad Request) error
      return res.status(400).json({
        success: false,
        message: "The password and confirm password does not match",
      });
    }

    // Update password
    const encryptedPassword = await bcrypt.hash(newPassword, 10);
    const updatedUserDetails = await User.findByIdAndUpdate(
      req.user.id,
      { password: encryptedPassword },
      { new: true }
    );

    // Send notification email
    try {
      const emailResponse = await mailSender(
        updatedUserDetails.email,
        "Study Notion - Password Updated",
        passwordUpdated(
          updatedUserDetails.email,
          `Password updated successfully for ${updatedUserDetails.firstName} ${updatedUserDetails.lastName}`
        )
      );
      console.log("Email sent successfully:", emailResponse.response);
    } catch (error) {
      // If there's an error sending the email, log the error and return a 500 (Internal Server Error) error
      console.error("Error occurred while sending email:", error);
      return res.status(500).json({
        success: false,
        message: "Error occurred while sending email",
        error: error.message,
      });
    }

    // Return success response
    return res
      .status(200)
      .json({ success: true, message: "Password updated successfully" });
  } catch (error) {
    // If there's an error updating the password, log the error and return a 500 (Internal Server Error) error
    console.error("Error occurred while updating password:", error);
    return res.status(500).json({
      success: false,
      message: "Error occurred while updating password",
      error: error.message,
    });
  }
};

exports.findUserIp = async (req, res) => {
  const ip = req.query.ip || req.connection.remoteAddress;
  const userId = req.query.userId; // Check if user is logged in by checking userId in query
  console.log(ip, userId);

  try {
    // Fetch the IP location data from GeoPlugin
    const response = await axios.get(
      `http://www.geoplugin.net/json.gp?ip=${ip}`
    );
    const locationData = response.data;
    console.log(locationData);

    // Extract latitude, longitude, and city
    const latitude = parseFloat(locationData.geoplugin_latitude);
    const longitude = parseFloat(locationData.geoplugin_longitude);
    const city = locationData.geoplugin_city;

    // If user is logged in, update their details
    if (userId) {
      const user = await User.findById(userId);

      if (user) {
        // Find or create UserDetail to store location data
        let userDetail = await UserDetail.findOne({ userId: userId });
        console.log(userDetail);

        if (!userDetail) {
          userDetail = new UserDetail({ userId: userId });
        }

        userDetail.location = {
          type: "Point",
          coordinates: [longitude, latitude],
        };
        userDetail.address = city;
        await userDetail.save();
        user.location = userDetail.location;
        await user.save();

        return res.status(200).json({
          success: true,
          message: "User location updated successfully",
          location: userDetail.location,
        });
      }

      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // If user is not logged in, only return the location
    return res.status(200).json({
      success: true,
      location: {
        latitude: latitude,
        longitude: longitude,
        city: city, // Include city in the response for non-logged-in users
      },
    });
  } catch (error) {
    console.error(error);
    res.status(500).send("Error fetching IP location");
  }
};

// New controller for initiating mobile verification (first step)
exports.initiateAuth = async (req, res) => {
  try {
    const { phoneNo } = req.body;

    if (!phoneNo) {
      return res.status(400).json({
        success: false,
        message: "Phone number is required",
      });
    }

    const existingUser = await User.findOne({ phoneNo });
    const isRegistered = existingUser ? true : false;

    const otp = otpGenerator.generate(6, {
      upperCaseAlphabets: false,
      lowerCaseAlphabets: false,
      specialChars: false,
    });

    const whatsappText = encodeURIComponent(`Your OTP is ${otp}`);
    const whatsappUrl = `https://wa.me/91${phoneNo}?text=${whatsappText}`;

    // Save OTP details
    const purpose = isRegistered ? "login" : "signup";
    await WhatsAppOTP.create({
      phoneNo,
      otp,
      whatsappUrl,
      purpose,
    });

    return res.status(200).json({
      success: true,
      message: "Authentication initiated",
      isRegistered,
      phoneNo,
    });
  } catch (error) {
    console.error("Authentication Initiation Error:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to initiate authentication. Please try again.",
    });
  }
};

// Admin endpoint to get pending OTP requests
exports.getPendingOTPs = async (req, res) => {
  try {
    const pendingOTPs = await WhatsAppOTP.find({ isSent: false })
      .sort({ createdAt: -1 })
      .limit(50);

    return res.status(200).json({
      success: true,
      data: pendingOTPs,
    });
  } catch (error) {
    console.error("Error fetching pending OTPs:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch pending OTPs",
    });
  }
};

// Admin endpoint to mark OTP as sent
exports.markOTPSent = async (req, res) => {
  try {
    const { otpId } = req.params;

    const otpRecord = await WhatsAppOTP.findByIdAndUpdate(
      otpId,
      { isSent: true },
      { new: true }
    );

    if (!otpRecord) {
      return res.status(404).json({
        success: false,
        message: "OTP record not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "OTP marked as sent",
      data: otpRecord,
    });
  } catch (error) {
    console.error("Error marking OTP as sent:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to update OTP status",
    });
  }
};

// Verify OTP and proceed with login/signup
exports.verifyOTP = async (req, res) => {
  try {
    const { phoneNo, otp } = req.body;

    if (!phoneNo || !otp) {
      return res.status(400).json({
        success: false,
        message: "Phone number and OTP are required",
      });
    }

    // Find the most recent OTP for the phone number
    const recentOtp = await WhatsAppOTP.findOne({ phoneNo, isSent: true }).sort(
      { createdAt: -1 }
    );

    if (!recentOtp || recentOtp.otp !== otp) {
      return res.status(400).json({
        success: false,
        message: "Invalid OTP. Please try again.",
      });
    }

    // Mark OTP as verified
    recentOtp.isVerified = true;
    await recentOtp.save();

    // Check if user exists
    const user = await User.findOne({ phoneNo }).populate("additionalDetails");

    if (user) {
      // User exists - handle login
      const token = jwt.sign(
        { phoneNo: user.phoneNo, id: user._id, accountType: user.accountType },
        process.env.JWT_SECRET,
        {
          expiresIn: "24h",
        }
      );

      user.token = token;
      user.password = undefined;

      const options = {
        expires: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
        httpOnly: true,
      };

      return res.cookie("token", token, options).status(200).json({
        success: true,
        token,
        user,
        message: "Login successful",
      });
    } else {
      return res.status(200).json({
        success: true,
        isRegistered: false,
        message: "Phone number verified. Please complete registration.",
        phoneNo,
      });
    }
  } catch (error) {
    console.error("OTP Verification Error:", error);
    return res.status(500).json({
      success: false,
      message: "OTP verification failed. Please try again.",
    });
  }
};

// Modified signup controller to return login-like response
exports.signupWithPhone = async (req, res) => {
  try {
    const { name, firstName, lastName, phoneNo, image } = req.body;

    console.log(req.body);
    // Check if required fields are present
    if (!name || !phoneNo) {
      return res.status(400).json({
        success: false,
        message: "Name, Phone Number, are required",
      });
    }

    // Verify the phone has been OTP-verified recently
    const verifiedOtp = await WhatsAppOTP.findOne({
      phoneNo,
      isVerified: true,
      purpose: "signup",
      createdAt: { $gt: new Date(Date.now() - 30 * 60 * 1000) },
    }).sort({ createdAt: -1 });

    if (!verifiedOtp) {
      return res.status(400).json({
        success: false,
        message: "Phone verification required before signup.",
      });
    }

    // Create additional user details
    const profileDetails = await UserDetail.create({});

    // Create user
    const user = await User.create({
      name,
      firstName,
      lastName,
      phoneNo,
      additionalDetails: profileDetails._id,
      image:
        image ||
        `https://api.dicebear.com/6.x/initials/svg?seed=${name}&backgroundColor=00897b,00acc1,039be5&backgroundType=solid`,
    });

    // Update profile details with userId
    profileDetails.userId = user._id;
    await profileDetails.save();

    // Generate JWT token like in login API
    const token = jwt.sign(
      {
        name: user.name,
        firstName: name.firstName,
        lastName: name.lastName,
        phoneNo: user.phoneNo,
        id: user._id,
        accountType: user.accountType,
        image: user.image,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: "24h",
      }
    );

    // Set cookie options
    const options = {
      expires: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      httpOnly: true,
    };

    return res.cookie("token", token, options).status(201).json({
      success: true,
      token,
      user,
      message: "User registered successfully.",
    });
  } catch (error) {
    console.error("Signup Error:", error);
    return res.status(500).json({
      success: false,
      message: "User registration failed. Please try again later.",
    });
  }
};

exports.adminLogin = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    // Find admin user
    const admin = await User.findOne({ email, accountType: "admin" }).populate("additionalDetails");
    
    if (!admin) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials or unauthorized access",
      });
    }

    // Verify password
    if (!admin.password) {
      return res.status(401).json({
        success: false,
        message: "Please use the password reset flow to set up your password",
      });
    }

    const isPasswordValid = await bcrypt.compare(password, admin.password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        email: admin.email, 
        id: admin._id, 
        accountType: admin.accountType 
      },
      process.env.JWT_SECRET,
      {
        expiresIn: "24h",
      }
    );

    // Remove sensitive data
    admin.password = undefined;
    admin.token = token;

    // Set cookie options
    const options = {
      expires: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      httpOnly: true,
    };

    return res.cookie("token", token, options).status(200).json({
      success: true,
      token,
      user: admin,
      message: "Admin logged in successfully",
    });

  } catch (error) {
    console.error("Admin Login Error:", error);
    return res.status(500).json({
      success: false,
      message: "Login failed. Please try again later.",
    });
  }
};
