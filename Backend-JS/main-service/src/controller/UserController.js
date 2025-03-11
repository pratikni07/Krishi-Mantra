// controllers/UserController.js (adding to existing file)
const User = require("../model/User");
const UserDetail = require("../model/UserDetail");

// Update main user profile
exports.updateUserProfile = async (req, res) => {
  try {
    const userId = req.user._id;
    const { name, firstName, lastName, phoneNo, image } = req.body;

    // Validate input
    if (!userId) {
      return res.status(400).json({ message: "User ID is required" });
    }

    // Find and update user
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      {
        name,
        firstName,
        lastName,
        phoneNo,
        image,
      },
      {
        new: true, // Return updated document
        runValidators: true, // Run model validations
      }
    ).select("-password"); // Exclude password from response

    if (!updatedUser) {
      return res.status(404).json({ message: "User not found" });
    }

    res.status(200).json({
      message: "User profile updated successfully",
      user: updatedUser,
    });
  } catch (error) {
    console.error("Error updating user profile:", error);
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};
// Update user additional details
exports.updateUserDetails = async (req, res) => {
  try {
    const userId = req.user._id;
    const { address, location, interests, profilePic } = req.body;

    // Find existing user details or create new
    let userDetails = await UserDetail.findOne({ userId });

    if (!userDetails) {
      // Create new user details if not exists
      userDetails = new UserDetail({
        userId,
        address,
        location,
        interests,
        profilePic,
      });
    } else {
      // Update existing user details
      userDetails.address = address || userDetails.address;
      userDetails.location = location || userDetails.location;
      userDetails.interests = interests || userDetails.interests;
      userDetails.profilePic = profilePic || userDetails.profilePic;
    }

    // Save updated/new user details
    await userDetails.save();

    // Update user's additional details reference
    await User.findByIdAndUpdate(userId, {
      additionalDetails: userDetails._id,
    });

    res.status(200).json({
      message: "User details updated successfully",
      userDetails,
    });
  } catch (error) {
    console.error("Error updating user details:", error);
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};
// Update user subscription details (optional)
exports.updateSubscription = async (req, res) => {
  try {
    const userId = req.user._id;
    const { subscriptionType, transactionDetails, endDate } = req.body;

    // Find user details
    let userDetails = await UserDetail.findOne({ userId });

    if (!userDetails) {
      return res.status(404).json({ message: "User details not found" });
    }

    // Update subscription details
    userDetails.subscription = {
      type: subscriptionType || userDetails.subscription.type,
      transactionDetails:
        transactionDetails || userDetails.subscription.transactionDetails,
      endDate: endDate || userDetails.subscription.endDate,
      purchasedDate: new Date(),
    };

    await userDetails.save();

    res.status(200).json({
      message: "Subscription updated successfully",
      subscription: userDetails.subscription,
    });
  } catch (error) {
    console.error("Error updating subscription:", error);
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};
exports.getUserByPage = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    console.log("Fetching users with page:", page, "and limit:", limit);

    const users = await User.find()
      .populate("additionalDetails")
      .skip(skip)
      .limit(limit)
      .select("-password"); // Exclude password field

    const totalUsers = await User.countDocuments();
    console.log(users);

    res.status(200).json({
      users: users.map((user) => ({
        _id: user._id,
        name: user.name,
        firstName: user.firstName,
        lastName: user.lastName,
        phoneNo: user.phoneNo,
        accountType: user.accountType,
        image: user.image,
        additionalDetails: {
          subscription: user.additionalDetails?.subscription,
          location: user.additionalDetails?.location,
          address: user.additionalDetails?.address,
        },
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      })),
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(totalUsers / limit),
        totalUsers,
        hasNextPage: page * limit < totalUsers,
        hasPreviousPage: page > 1,
      },
    });
  } catch (error) {
    console.error("Error fetching users:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

exports.getUserById = async (req, res) => {
  try {
    const userId = req.user._id;
    const user = await User.findById(userId);
    res.status(200).json({
      user,
      message: "User By Id",
    });
  } catch (error) {
    console.error("Error fetching  By Id user:", error);
    res.status(500).json({ message: "Server error" });
  }
};

// get consultant according to latitude and langitude

// exports.getConsultant = async (req, res) => {
//   try {
//     const { latitude, longitude } = req.body;
//     console.log(latitude, longitude, "requested");

//     // Find consultants near the user's location
//     const consultants = await UserDetail.find({
//       location: {
//         $near: {
//           $geometry: {
//             type: "Point",
//             coordinates: [longitude, latitude],
//           },
//           $maxDistance: 10000,
//         },
//       },
//     })
//       .populate({
//         path: "userId",
//         match: { accountType: "consultant" },
//         select: "name image",
//       })
//       .populate({
//         path: "company",
//         select: "name logo",
//       })
//       .exec();

//     const filteredConsultants = consultants
//       .filter((consultant) => consultant.userId !== null)
//       .map((consultant) => ({
//         id: consultant._id,
//         userName: consultant.userId.name,
//         profilePhotoId: consultant.userId.image,
//         experience: consultant.experience,
//         rating: consultant.rating,
//         company: consultant.company
//           ? {
//               name: consultant.company.name,
//               logo: consultant.company.logo,
//             }
//           : null,
//       }));

//     res.status(200).json({
//       consultants: filteredConsultants,
//       message: "Consultants found",
//     });
//   } catch (error) {
//     console.error("Error fetching consultants:", error);
//     res.status(500).json({ message: "Server error" });
//   }
// };

// exports.getConsultant = async (req, res) => {
//   try {
//     // const { latitude, longitude } = req.body;
//     // console.log(latitude, longitude, "requested");

//     // Find consultants near the user's location
//     const consultants = await UserDetail.find()
//       .populate({
//         path: "userId",
//         match: { accountType: "consultant" },
//         select: "name image",
//       })
//       .populate({
//         path: "company",
//         select: "name logo",
//       })
//       .exec();

//     const filteredConsultants = consultants
//       .filter((consultant) => consultant.userId !== null)
//       .map((consultant) => ({
//         id: consultant._id,
//         userName: consultant.userId.name,
//         profilePhotoId: consultant.userId.image,
//         experience: consultant.experience,
//         rating: consultant.rating,
//         company: consultant.company
//           ? {
//               name: consultant.company.name,
//               logo: consultant.company.logo,
//             }
//           : null,
//       }));

//     res.status(200).json({
//       consultants: filteredConsultants,
//       message: "Consultants found",
//     });
//   } catch (error) {
//     console.error("Error fetching consultants:", error);
//     res.status(500).json({ message: "Server error" });
//   }
// };

exports.getConsultant = async (req, res) => {
  try {
    const consultants = await User.find({ accountType: "consultant" })
      .populate("additionalDetails")
      .lean();

    // Map consultants and check for undefined values before accessing properties
    const formattedConsultants = consultants
      .map((consultant) => {
        if (!consultant) {
          return null;
        }
        return {
          _id: consultant._id,
          userName: consultant.name || null,
          firstName: consultant.firstName || null,
          lastName: consultant.lastName || null,
          profilePhotoId: consultant.image || null,
          phoneNo: consultant.phoneNo || null,
          // Only access additionalDetails if it exists
          experience: consultant.additionalDetails
            ? consultant.additionalDetails.experience
            : null,
          rating: consultant.additionalDetails
            ? consultant.additionalDetails.rating
            : null,
          company: consultant.company
            ? {
                name: consultant.company.name,
                logo: consultant.company.logo,
              }
            : null,

          // Add any other fields you need
        };
      })
      .filter(Boolean); // Remove any null entries

    res.status(200).json({
      consultants: formattedConsultants,
      message: "Consultants found",
    });
  } catch (error) {
    console.error("Error fetching consultants:", error);
    return res.status(500).json({
      success: false,
      message: "Failed to fetch consultants",
      error: error.message,
    });
  }
};
