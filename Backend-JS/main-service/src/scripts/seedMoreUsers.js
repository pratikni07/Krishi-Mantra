/**
 * Krishi-Mantra - Add 100 More Users Script
 * Adds 100 realistic Indian farmer users
 *
 * Usage: node src/scripts/seedMoreUsers.js
 */

const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const User = require('../model/User');
const UserDetail = require('../model/UserDetail');

// Indian states with their districts and coordinates
const statesData = [
  { state: 'Punjab', districts: ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Mohali', 'Sangrur', 'Ferozepur'], lat: 31.1471, lng: 75.3412 },
  { state: 'Haryana', districts: ['Karnal', 'Hisar', 'Rohtak', 'Panipat', 'Sonipat', 'Ambala', 'Sirsa', 'Kurukshetra'], lat: 29.0588, lng: 76.0856 },
  { state: 'Uttar Pradesh', districts: ['Lucknow', 'Kanpur', 'Varanasi', 'Agra', 'Meerut', 'Allahabad', 'Gorakhpur', 'Bareilly', 'Mathura', 'Jhansi'], lat: 26.8467, lng: 80.9462 },
  { state: 'Madhya Pradesh', districts: ['Indore', 'Bhopal', 'Jabalpur', 'Gwalior', 'Ujjain', 'Sagar', 'Rewa', 'Satna', 'Dewas', 'Vidisha'], lat: 22.9734, lng: 78.6569 },
  { state: 'Maharashtra', districts: ['Pune', 'Nagpur', 'Nashik', 'Aurangabad', 'Kolhapur', 'Sangli', 'Solapur', 'Ahmednagar', 'Satara', 'Jalgaon'], lat: 19.7515, lng: 75.7139 },
  { state: 'Gujarat', districts: ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Junagadh', 'Mehsana', 'Anand', 'Kutch', 'Kheda'], lat: 22.2587, lng: 71.1924 },
  { state: 'Rajasthan', districts: ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer', 'Bikaner', 'Alwar', 'Bharatpur', 'Sikar', 'Chittorgarh'], lat: 27.0238, lng: 74.2179 },
  { state: 'Karnataka', districts: ['Bengaluru', 'Mysuru', 'Hubli', 'Mangaluru', 'Belagavi', 'Davangere', 'Ballari', 'Tumkur', 'Shimoga', 'Raichur'], lat: 15.3173, lng: 75.7139 },
  { state: 'Tamil Nadu', districts: ['Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem', 'Tirunelveli', 'Erode', 'Vellore', 'Thanjavur', 'Dindigul'], lat: 11.1271, lng: 78.6569 },
  { state: 'Andhra Pradesh', districts: ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool', 'Tirupati', 'Kadapa', 'Anantapur', 'Rajahmundry', 'Eluru'], lat: 15.9129, lng: 79.7400 },
  { state: 'Telangana', districts: ['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar', 'Khammam', 'Mahbubnagar', 'Nalgonda', 'Adilabad', 'Medak', 'Rangareddy'], lat: 18.1124, lng: 79.0193 },
  { state: 'West Bengal', districts: ['Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri', 'Bardhaman', 'Malda', 'Kharagpur', 'Haldia', 'Murshidabad'], lat: 22.9868, lng: 87.8550 },
  { state: 'Bihar', districts: ['Patna', 'Gaya', 'Muzaffarpur', 'Bhagalpur', 'Darbhanga', 'Purnia', 'Begusarai', 'Samastipur', 'Nalanda', 'Vaishali'], lat: 25.0961, lng: 85.3131 },
  { state: 'Odisha', districts: ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Berhampur', 'Sambalpur', 'Puri', 'Balasore', 'Jharsuguda', 'Koraput', 'Angul'], lat: 20.9517, lng: 85.0985 },
  { state: 'Jharkhand', districts: ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Hazaribagh', 'Deoghar', 'Giridih', 'Ramgarh', 'Dumka', 'Chaibasa'], lat: 23.6102, lng: 85.2799 },
  { state: 'Chhattisgarh', districts: ['Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Durg', 'Rajnandgaon', 'Raigarh', 'Jagdalpur', 'Ambikapur', 'Dhamtari'], lat: 21.2787, lng: 81.8661 },
  { state: 'Assam', districts: ['Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Nagaon', 'Tinsukia', 'Tezpur', 'Bongaigaon', 'Dhubri', 'Karimganj'], lat: 26.2006, lng: 92.9376 },
  { state: 'Kerala', districts: ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kollam', 'Kannur', 'Alappuzha', 'Palakkad', 'Malappuram', 'Kottayam'], lat: 10.8505, lng: 76.2711 },
  { state: 'Uttarakhand', districts: ['Dehradun', 'Haridwar', 'Nainital', 'Udham Singh Nagar', 'Almora', 'Pithoragarh', 'Pauri Garhwal', 'Tehri Garhwal', 'Chamoli', 'Rudraprayag'], lat: 30.0668, lng: 79.0193 },
  { state: 'Himachal Pradesh', districts: ['Shimla', 'Kangra', 'Mandi', 'Solan', 'Sirmaur', 'Kullu', 'Una', 'Hamirpur', 'Bilaspur', 'Chamba'], lat: 31.1048, lng: 77.1734 },
];

// Common Indian first names (male and female)
const maleFirstNames = [
  'Rajesh', 'Suresh', 'Ramesh', 'Mukesh', 'Dinesh', 'Mahesh', 'Ganesh', 'Naresh', 'Rakesh', 'Yogesh',
  'Amit', 'Sumit', 'Rohit', 'Mohit', 'Ajit', 'Ranjit', 'Sanjay', 'Vijay', 'Ajay', 'Vinay',
  'Arun', 'Varun', 'Tarun', 'Kiran', 'Ravi', 'Sanjiv', 'Rajiv', 'Pankaj', 'Deepak', 'Alok',
  'Sunil', 'Anil', 'Manoj', 'Pramod', 'Vinod', 'Ashok', 'Santosh', 'Prakash', 'Subhash', 'Girish',
  'Rampal', 'Shyam', 'Mohan', 'Sohan', 'Rohan', 'Krishna', 'Gopal', 'Balram', 'Hari', 'Om',
  'Bhagwan', 'Jagdish', 'Satish', 'Harish', 'Manish', 'Nilesh', 'Paresh', 'Ritesh', 'Jitesh', 'Hitesh',
  'Devendra', 'Narendra', 'Surendra', 'Virendra', 'Dharmendra', 'Gajendra', 'Rajendra', 'Mahendra', 'Jogendra', 'Upendra',
  'Brijesh', 'Lokesh', 'Umesh', 'Kamlesh', 'Sudhir', 'Randhir', 'Raghav', 'Madhav', 'Keshav', 'Tushar',
];

const femaleFirstNames = [
  'Sunita', 'Anita', 'Kavita', 'Savita', 'Suman', 'Kiran', 'Meena', 'Reena', 'Seema', 'Neeta',
  'Geeta', 'Sita', 'Radha', 'Lata', 'Usha', 'Asha', 'Rekha', 'Shobha', 'Prabha', 'Sudha',
  'Priya', 'Divya', 'Pooja', 'Ritu', 'Neha', 'Swati', 'Preeti', 'Jyoti', 'Aarti', 'Sangeeta',
  'Mamta', 'Kusum', 'Pushpa', 'Kamla', 'Saroj', 'Sarita', 'Shanti', 'Parvati', 'Durga', 'Lakshmi',
  'Bhavna', 'Sapna', 'Archana', 'Vandana', 'Sadhana', 'Kalpana', 'Alka', 'Vibha', 'Nisha', 'Ranjana',
];

// Common Indian last names by region
const lastNames = [
  // North India
  'Singh', 'Sharma', 'Verma', 'Gupta', 'Kumar', 'Yadav', 'Jat', 'Chauhan', 'Rajput', 'Thakur',
  'Mishra', 'Tripathi', 'Pandey', 'Dubey', 'Tiwari', 'Srivastava', 'Saxena', 'Agarwal', 'Jain', 'Bansal',
  // West India
  'Patel', 'Shah', 'Desai', 'Mehta', 'Joshi', 'Kulkarni', 'Patil', 'Jadhav', 'Shinde', 'Pawar',
  // South India
  'Reddy', 'Naidu', 'Rao', 'Raju', 'Choudhary', 'Nair', 'Menon', 'Pillai', 'Iyer', 'Iyengar',
  // East India
  'Das', 'Ghosh', 'Bose', 'Sen', 'Chatterjee', 'Banerjee', 'Mukherjee', 'Roy', 'Dutta', 'Sarkar',
];

// Farming interests
const farmingInterests = [
  ['wheat', 'rice', 'irrigation', 'tractor'],
  ['cotton', 'soybean', 'organic farming', 'drip irrigation'],
  ['sugarcane', 'potato', 'sprinkler', 'fertilizers'],
  ['paddy', 'banana', 'coconut', 'vermicompost'],
  ['vegetables', 'tomato', 'onion', 'polyhouse'],
  ['groundnut', 'mustard', 'pulses', 'seed treatment'],
  ['mango', 'citrus', 'horticulture', 'grafting'],
  ['dairy farming', 'cattle', 'fodder', 'milk production'],
  ['poultry', 'goat farming', 'piggery', 'livestock'],
  ['fish farming', 'aquaculture', 'prawn', 'pond management'],
  ['chili', 'turmeric', 'ginger', 'spice farming'],
  ['tea', 'coffee', 'cardamom', 'plantation'],
  ['apple', 'cherry', 'walnut', 'hill farming'],
  ['grapes', 'pomegranate', 'fig', 'vineyard'],
  ['maize', 'jowar', 'bajra', 'millets'],
  ['mushroom', 'beekeeping', 'sericulture', 'allied farming'],
  ['flower cultivation', 'rose', 'marigold', 'floriculture'],
  ['medicinal plants', 'herbs', 'ayurvedic', 'aromatic plants'],
  ['organic certification', 'natural farming', 'zero budget', 'sustainable'],
  ['farm mechanization', 'combine harvester', 'rotavator', 'implements'],
];

// Generate 100 users
function generateUsers() {
  const users = [];

  for (let i = 0; i < 100; i++) {
    const isMale = Math.random() > 0.35; // 65% male, 35% female (realistic for Indian farming)
    const firstName = isMale
      ? maleFirstNames[Math.floor(Math.random() * maleFirstNames.length)]
      : femaleFirstNames[Math.floor(Math.random() * femaleFirstNames.length)];
    const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];

    const stateInfo = statesData[Math.floor(Math.random() * statesData.length)];
    const district = stateInfo.districts[Math.floor(Math.random() * stateInfo.districts.length)];

    // Add some randomness to coordinates (within ~50km)
    const latOffset = (Math.random() - 0.5) * 1;
    const lngOffset = (Math.random() - 0.5) * 1;

    const interests = farmingInterests[Math.floor(Math.random() * farmingInterests.length)];
    const experience = Math.floor(Math.random() * 30) + 2; // 2-32 years
    const rating = (Math.random() * 2 + 3).toFixed(1); // 3.0-5.0

    // Account type distribution: 85% user, 10% consultant, 3% marketplace, 2% admin
    let accountType = 'user';
    const typeRandom = Math.random();
    if (typeRandom > 0.98) accountType = 'admin';
    else if (typeRandom > 0.95) accountType = 'marketplace';
    else if (typeRandom > 0.85) accountType = 'consultant';

    const phoneNo = 9000000000 + Math.floor(Math.random() * 999999999);
    const emailName = `${firstName.toLowerCase()}.${lastName.toLowerCase()}${i + 11}`;

    users.push({
      name: `${firstName} ${lastName}`,
      firstName,
      lastName,
      email: `${emailName}@gmail.com`,
      phoneNo,
      accountType,
      image: `https://randomuser.me/api/portraits/${isMale ? 'men' : 'women'}/${(i % 99) + 1}.jpg`,
      isActive: Math.random() > 0.05, // 95% active
      details: {
        address: `Village ${district}, Dist. ${district}, ${stateInfo.state}`,
        location: {
          type: 'Point',
          coordinates: [stateInfo.lng + lngOffset, stateInfo.lat + latOffset]
        },
        interests,
        experience,
        rating: parseFloat(rating),
      },
    });
  }

  return users;
}

async function seedMoreUsers() {
  try {
    const mongoUrl = process.env.MONGODB_URL;
    if (!mongoUrl) {
      throw new Error('MONGODB_URL environment variable is not set');
    }

    console.log('🌱 Connecting to MongoDB...');
    await mongoose.connect(mongoUrl);
    console.log('✅ Connected to MongoDB');

    const additionalUsers = generateUsers();

    console.log('\n👥 Adding 100 more users...');

    const hashedPassword = await bcrypt.hash('KrishiMantra@123', 10);
    let createdCount = 0;
    let skippedCount = 0;

    for (const userData of additionalUsers) {
      try {
        const { details, ...userInfo } = userData;

        // Check if email already exists
        const existingUser = await User.findOne({ email: userInfo.email });
        if (existingUser) {
          skippedCount++;
          continue;
        }

        // Create user
        const user = await User.create({
          ...userInfo,
          password: hashedPassword,
        });

        // Create user details
        const userDetail = await UserDetail.create({
          userId: user._id,
          ...details,
        });

        // Link user details
        user.additionalDetails = userDetail._id;
        await user.save();

        createdCount++;

        if (createdCount % 10 === 0) {
          console.log(`   ✓ Created ${createdCount} users...`);
        }
      } catch (err) {
        console.log(`   ⚠ Skipped user ${userData.email}: ${err.message}`);
        skippedCount++;
      }
    }

    // Get total count
    const totalUsers = await User.countDocuments();

    console.log(`\n✅ Added ${createdCount} new users (${skippedCount} skipped)`);
    console.log(`📊 Total users in database: ${totalUsers}`);

    // Show distribution
    const userCount = await User.countDocuments({ accountType: 'user' });
    const consultantCount = await User.countDocuments({ accountType: 'consultant' });
    const marketplaceCount = await User.countDocuments({ accountType: 'marketplace' });
    const adminCount = await User.countDocuments({ accountType: 'admin' });

    console.log(`
📈 User Distribution:
   - Farmers (user): ${userCount}
   - Consultants: ${consultantCount}
   - Marketplace: ${marketplaceCount}
   - Admins: ${adminCount}

🔑 Password for all users: KrishiMantra@123
    `);

    await mongoose.connection.close();
    console.log('✅ Database connection closed');
    process.exit(0);

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

seedMoreUsers();
