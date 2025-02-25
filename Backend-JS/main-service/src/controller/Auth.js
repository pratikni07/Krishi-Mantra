const axios = require("axios");
const bcrypt = require("bcrypt");
const User = require("../model/User");
const OTP = require("../model/OTP");
const jwt = require("jsonwebtoken");
const otpGenerator = require("otp-generator");
const mailSender = require("../utils/mailSender");
const { passwordUpdated } = require("../mail/templates/passwordUpdate");

const UserDetail = require("../model/UserDetail");
require("dotenv").config();

// Signup Controller for Registering Users
exports.signup = async (req, res) => {
  try {
    const { name, phoneNo, otp } = req.body;

    // Check if required fields are present
    if (!name || !phoneNo || !otp) {
      return res.status(403).send({
        success: false,
        message: "Name, Phone Number, and OTP are required",
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ phoneNo });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "User already exists. Please log in to continue.",
      });
    }

    // Find the most recent OTP for the phone number
    const response = await OTP.find({ phoneNo })
      .sort({ createdAt: -1 })
      .limit(1);
    if (response.length === 0 || otp !== response[0].otp) {
      return res.status(400).json({
        success: false,
        message: "The OTP is not valid",
      });
    }

    // Create temporary additional details for the user
    const profileDetails = await UserDetail.create({});

    // Create a new user with temporary details
    const user = await User.create({
      name,
      phoneNo,
      additionalDetails: profileDetails._id,
      image: `https://api.dicebear.com/6.x/initials/svg?seed=${name}&backgroundColor=00897b,00acc1,039be5&backgroundType=solid`,
    });

    // Update the userId in additional details
    profileDetails.userId = user._id;
    await profileDetails.save();

    return res.status(200).json({
      success: true,
      user,
      message: "User registered successfully. Please complete your profile.",
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: "User cannot be registered. Please try again.",
    });
  }
};

// Login controller for authenticating users
exports.login = async (req, res) => {
  try {
    // Get email and password from request body
    const { email, password } = req.body;

    // Check if email or password is missing
    if (!email || !password) {
      // Return 400 Bad Request status code with error message
      return res.status(400).json({
        success: false,
        message: `Please Fill up All the Required Fields`,
      });
    }

    // Find user with provided email
    const user = await User.findOne({ email }).populate("additionalDetails");

    // If user not found with provided email
    if (!user) {
      // Return 401 Unauthorized status code with error message
      return res.status(401).json({
        success: false,
        message: `User is not Registered with Us Please SignUp to Continue`,
      });
    }

    // Generate JWT token and Compare Password
    if (await bcrypt.compare(password, user.password)) {
      const token = jwt.sign(
        { email: user.email, id: user._id, accountType: user.accountType },
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
      res.cookie("token", token, options).status(200).json({
        success: true,
        token,
        user,
        message: `User Login Success`,
      });
    } else {
      return res.status(401).json({
        success: false,
        message: `Password is incorrect`,
      });
    }
  } catch (error) {
    console.error(error);
    // Return 500 Internal Server Error status code with error message
    return res.status(500).json({
      success: false,
      message: `Login Failure Please Try Again`,
    });
  }
};

// Send OTP For Email Verification
exports.sendotp = async (req, res) => {
  try {
    const { email } = req.body;

    // Check if user is already present
    // Find user with provided email
    const checkUserPresent = await User.findOne({ email });
    // to be used in case of signup

    // If user found with provided email
    if (checkUserPresent) {
      // Return 401 Unauthorized status code with error message
      return res.status(401).json({
        success: false,
        message: `User is Already Registered`,
      });
    }

    var otp = otpGenerator.generate(6, {
      upperCaseAlphabets: false,
      lowerCaseAlphabets: false,
      specialChars: false,
    });
    const result = await OTP.findOne({ otp: otp });
    console.log("Result is Generate OTP Func");
    console.log("OTP", otp);
    console.log("Result", result);
    while (result) {
      otp = otpGenerator.generate(6, {
        upperCaseAlphabets: false,
      });
    }
    const otpPayload = { email, otp };
    const otpBody = await OTP.create(otpPayload);
    console.log("OTP Body", otpBody);

    res.status(200).json({
      success: true,
      message: `OTP Sent Successfully`,
      otp,
    });
  } catch (error) {
    console.log(error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
};

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
