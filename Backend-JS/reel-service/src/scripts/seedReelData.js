/**
 * Krishi-Mantra Reel Service Seed Data Script
 * Adds realistic farming reels and video tutorials
 *
 * Usage: node src/scripts/seedReelData.js
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env') });
const mongoose = require('mongoose');

// Models - Reel Service
const Reel = require('../models/Reel');
const VideoTutorial = require('../models/VideoTutorial');
const ReelComment = require('../models/CommentModal');
const ReelLike = require('../models/LikeModel');
const ReelTag = require('../models/Tags');

// ============================================
// USERS DATA (Same as other services for consistency)
// ============================================
const usersData = [
  {
    id: '1',
    name: 'Ramesh Kumar Patel',
    profilePhoto: 'https://randomuser.me/api/portraits/men/1.jpg',
    location: { latitude: 22.3039, longitude: 70.8022 },
  },
  {
    id: '2',
    name: 'Sunita Devi',
    profilePhoto: 'https://randomuser.me/api/portraits/women/2.jpg',
    location: { latitude: 30.9010, longitude: 75.8573 },
  },
  {
    id: '3',
    name: 'Venkatesh Reddy',
    profilePhoto: 'https://randomuser.me/api/portraits/men/3.jpg',
    location: { latitude: 17.3850, longitude: 78.4867 },
  },
  {
    id: '4',
    name: 'Mahendra Singh Yadav',
    profilePhoto: 'https://randomuser.me/api/portraits/men/4.jpg',
    location: { latitude: 26.9260, longitude: 81.1857 },
  },
  {
    id: '5',
    name: 'Lakshmi Narayanan',
    profilePhoto: 'https://randomuser.me/api/portraits/women/5.jpg',
    location: { latitude: 10.7870, longitude: 79.1378 },
  },
  {
    id: '6',
    name: 'Balwinder Singh',
    profilePhoto: 'https://randomuser.me/api/portraits/men/6.jpg',
    location: { latitude: 30.3398, longitude: 76.3869 },
  },
  {
    id: '7',
    name: 'Anita Sharma',
    profilePhoto: 'https://randomuser.me/api/portraits/women/7.jpg',
    location: { latitude: 22.7196, longitude: 75.8577 },
  },
  {
    id: '8',
    name: 'Prakash Chandra Joshi',
    profilePhoto: 'https://randomuser.me/api/portraits/men/8.jpg',
    location: { latitude: 30.3165, longitude: 78.0322 },
  },
  {
    id: '9',
    name: 'Meera Bai',
    profilePhoto: 'https://randomuser.me/api/portraits/women/9.jpg',
    location: { latitude: 26.2389, longitude: 73.0243 },
  },
  {
    id: '10',
    name: 'Govind Das',
    profilePhoto: 'https://randomuser.me/api/portraits/men/10.jpg',
    location: { latitude: 22.5726, longitude: 88.3639 },
  },
];

// ============================================
// REELS DATA - Short farming videos
// ============================================
// Sample video URLs - using verified working public MP4 files
// W3Schools videos are small and load quickly on iOS
const sampleVideos = [
  'https://www.w3schools.com/html/mov_bbb.mp4',
  'https://www.w3schools.com/html/movie.mp4',
  'https://www.w3schools.com/html/mov_bbb.mp4',
  'https://www.w3schools.com/html/movie.mp4',
  'https://www.w3schools.com/html/mov_bbb.mp4',
];

// Thumbnail images for reels - farming related images from Unsplash
const reelThumbnails = [
  'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=400', // Crop field
  'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=400', // Wheat field
  'https://images.unsplash.com/photo-1595855759920-86582396756a?w=400', // Chili peppers
  'https://images.unsplash.com/photo-1597916829826-02e5bb4a54e0?w=400', // Sugarcane
  'https://images.unsplash.com/photo-1536054024090-c2df1bd15e79?w=400', // Rice paddy
  'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=400', // Tractor
  'https://images.unsplash.com/photo-1599719500956-d158a26ab3ee?w=400', // Soybean field
  'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=400', // Apple tree
  'https://images.unsplash.com/photo-1599909533016-b472b8db86f5?w=400', // Spices/Cumin
  'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=400', // Fish
  'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=400', // Organic farm
  'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400', // Irrigation
  'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400', // Finance/PM Kisan
  'https://images.unsplash.com/photo-1603833665858-e61d17a86224?w=400', // Bananas
  'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=400', // Farm machinery
];

const reelsData = [
  {
    userIndex: 0,
    description: 'देखो कैसे 5 मिनट में पता लगाओ फसल में क्या कमी है! पत्ता देखकर पहचानो Nitrogen, Phosphorus, Potash की कमी। #FarmingTips #CropHealth',
    mediaUrl: sampleVideos[0],
    thumbnail: reelThumbnails[0],
    likes: 2345,
    views: 15670,
  },
  {
    userIndex: 1,
    description: 'गेहूं की बुवाई का सही तरीका। Line में बोने से 20% ज्यादा उत्पादन! Seed drill का proper use देखो। #Wheat #Sowing',
    mediaUrl: sampleVideos[1],
    thumbnail: reelThumbnails[1],
    likes: 1890,
    views: 12340,
  },
  {
    userIndex: 2,
    description: 'मिर्च में फूल झड़ने की समस्या? यह करो तुरंत बंद होगा! Boron spray का कमाल। #Chili #FlowerDrop',
    mediaUrl: sampleVideos[2],
    thumbnail: reelThumbnails[2],
    likes: 3456,
    views: 23450,
  },
  {
    userIndex: 3,
    description: 'गन्ने में बोरर का 100% इलाज! Trichogramma cards लगाओ, chemical बचाओ। Biological control का जादू। #Sugarcane #PestControl',
    mediaUrl: sampleVideos[3],
    thumbnail: reelThumbnails[3],
    likes: 2123,
    views: 18900,
  },
  {
    userIndex: 4,
    description: 'धान में खरपतवार खत्म करने का नया तरीका! एक spray से सब साफ। Best herbicide for paddy. #Paddy #Weeding',
    mediaUrl: sampleVideos[4],
    thumbnail: reelThumbnails[4],
    likes: 1567,
    views: 11230,
  },
  {
    userIndex: 5,
    description: 'ट्रैक्टर में डीजल कैसे बचाओ? 5 आसान तरीके। ₹500 रोज की बचत पक्की! #Tractor #DieselSaving',
    mediaUrl: sampleVideos[0],
    thumbnail: reelThumbnails[5],
    likes: 4567,
    views: 34560,
  },
  {
    userIndex: 6,
    description: 'सोयाबीन में Yellow Mosaic Virus का इलाज। सफेद मक्खी को ऐसे रोको। #Soybean #Virus',
    mediaUrl: sampleVideos[1],
    thumbnail: reelThumbnails[6],
    likes: 1234,
    views: 9870,
  },
  {
    userIndex: 7,
    description: 'सेब के पेड़ में कांट-छांट कैसे करें? Winter pruning का सही समय और तरीका। #Apple #Pruning',
    mediaUrl: sampleVideos[2],
    thumbnail: reelThumbnails[7],
    likes: 890,
    views: 7650,
  },
  {
    userIndex: 8,
    description: 'जीरे में पाले से बचाव! एक spray से फसल बच जाएगी। Sulphur का कमाल। #Cumin #FrostProtection',
    mediaUrl: sampleVideos[3],
    thumbnail: reelThumbnails[8],
    likes: 1456,
    views: 10890,
  },
  {
    userIndex: 9,
    description: 'मछली का चारा घर पर बनाओ। ₹20 kg में बनेगा, बाजार में ₹60 का मिलता है। #FishFarming #FeedMaking',
    mediaUrl: sampleVideos[4],
    thumbnail: reelThumbnails[9],
    likes: 2789,
    views: 19870,
  },
  {
    userIndex: 0,
    description: 'जैविक कीटनाशक घर पर बनाओ! नीम + लहसुन + मिर्च का काढ़ा। सब कीड़े भागेंगे। #Organic #Pesticide',
    mediaUrl: sampleVideos[0],
    thumbnail: reelThumbnails[10],
    likes: 5678,
    views: 45670,
  },
  {
    userIndex: 2,
    description: 'ड्रिप में जाम की समस्या? ऐसे करो cleaning। 10 मिनट में line साफ। #DripIrrigation #Maintenance',
    mediaUrl: sampleVideos[1],
    thumbnail: reelThumbnails[11],
    likes: 1678,
    views: 12340,
  },
  {
    userIndex: 3,
    description: 'PM-KISAN के पैसे नहीं आए? ऐसे करो eKYC और status check। Step by step guide। #PMKisan #eKYC',
    mediaUrl: sampleVideos[2],
    thumbnail: reelThumbnails[12],
    likes: 6789,
    views: 56780,
  },
  {
    userIndex: 4,
    description: 'केले में Panama Wilt से बचाव। एक बार आया तो पूरा बाग खत्म। Prevention tips। #Banana #Disease',
    mediaUrl: sampleVideos[3],
    thumbnail: reelThumbnails[13],
    likes: 2345,
    views: 18760,
  },
  {
    userIndex: 5,
    description: 'रोटावेटर के blades कब बदलें? ऐसे check करो condition। टाइम पर बदलोगे तो diesel बचेगा। #Rotavator #Maintenance',
    mediaUrl: sampleVideos[4],
    thumbnail: reelThumbnails[14],
    likes: 1890,
    views: 14560,
  },
];

// ============================================
// VIDEO TUTORIALS DATA - Long-form educational content
// Based on popular Indian farming YouTube channels
// ============================================
const videoTutorialsData = [
  {
    userIndex: 0,
    title: 'Complete Guide: Organic Cotton Farming | जैविक कपास की खेती A to Z',
    description: 'Learn complete organic cotton cultivation from land preparation to harvesting. Includes pest management, fertilizer schedule, and marketing tips. जैविक कपास की खेती का पूरा गाइड - जमीन तैयारी से लेकर कटाई तक।',
    thumbnail: 'https://images.unsplash.com/photo-1599719500956-d158a26ab3ee?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    videoType: 'youtube',
    duration: 2400,
    tags: ['organic', 'cotton', 'farming', 'कपास', 'जैविक खेती'],
    category: 'Crop Cultivation',
    views: 45670,
    likes: 3456,
  },
  {
    userIndex: 1,
    title: 'Wheat Cultivation: HD-3226 Variety Complete Guide | गेहूं की नई किस्म',
    description: 'HD-3226 wheat variety cultivation guide. High yielding, disease resistant variety suitable for Punjab, Haryana, UP. Sowing time, seed rate, irrigation schedule covered. पंजाब, हरियाणा, UP के लिए बेस्ट गेहूं की किस्म।',
    thumbnail: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=wheat-guide',
    videoType: 'youtube',
    duration: 1800,
    tags: ['wheat', 'hd3226', 'गेहूं', 'rabi', 'पंजाब'],
    category: 'Crop Cultivation',
    views: 67890,
    likes: 5678,
  },
  {
    userIndex: 2,
    title: 'Drip Irrigation Installation | ड्रिप सिंचाई कैसे लगाएं Step by Step',
    description: 'Complete drip irrigation installation guide. From design to installation, everything covered. How to get 55% government subsidy. ड्रिप इरिगेशन का पूरा सेटअप और सरकारी सब्सिडी कैसे लें।',
    thumbnail: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=drip-irrigation',
    videoType: 'youtube',
    duration: 3600,
    tags: ['drip', 'irrigation', 'सिंचाई', 'subsidy', 'water saving'],
    category: 'Farm Technology',
    views: 89012,
    likes: 7890,
  },
  {
    userIndex: 3,
    title: 'Sugarcane Farming: 500 Quintal/Acre | गन्ने की खेती में कमाल',
    description: 'How to achieve 500 quintal per acre sugarcane yield. Variety selection, trench planting, ratoon management. Success story from UP. गन्ने में 500 क्विंटल प्रति एकड़ उत्पादन कैसे लें।',
    thumbnail: 'https://images.unsplash.com/photo-1597916829826-02e5bb4a54e0?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=sugarcane-farming',
    videoType: 'youtube',
    duration: 2700,
    tags: ['sugarcane', 'गन्ना', 'high yield', 'UP', 'trench'],
    category: 'Crop Cultivation',
    views: 56789,
    likes: 4567,
  },
  {
    userIndex: 4,
    title: 'SRI Method Rice Cultivation | धान की SRI विधि से खेती',
    description: 'System of Rice Intensification (SRI) complete guide. 40-50% more yield with 30% less water. Step by step implementation. धान में SRI विधि से 40% ज्यादा उत्पादन।',
    thumbnail: 'https://images.unsplash.com/photo-1536054024090-c2df1bd15e79?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=sri-rice',
    videoType: 'youtube',
    duration: 2100,
    tags: ['rice', 'sri', 'धान', 'paddy', 'water saving'],
    category: 'Crop Cultivation',
    views: 78901,
    likes: 6789,
  },
  {
    userIndex: 5,
    title: 'Tractor Buying Guide 2026 | ट्रैक्टर खरीदने से पहले जरूर देखें',
    description: 'Complete tractor buying guide. HP selection, brand comparison, loan process, EMI calculation. How to test drive and negotiate. ट्रैक्टर खरीदने की पूरी जानकारी - HP, Brand, Loan, EMI।',
    thumbnail: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=tractor-guide',
    videoType: 'youtube',
    duration: 3000,
    tags: ['tractor', 'ट्रैक्टर', 'buying guide', 'mahindra', 'swaraj'],
    category: 'Farm Machinery',
    views: 123456,
    likes: 12345,
  },
  {
    userIndex: 6,
    title: 'Soybean Pest Management | सोयाबीन में कीट प्रबंधन',
    description: 'Complete pest management in soybean. Identification and control of major pests - stem fly, leaf miner, pod borer, whitefly. सोयाबीन के प्रमुख कीट और उनका नियंत्रण।',
    thumbnail: 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=soybean-pest',
    videoType: 'youtube',
    duration: 1500,
    tags: ['soybean', 'pest', 'सोयाबीन', 'कीट', 'IPM'],
    category: 'Pest Management',
    views: 34567,
    likes: 2890,
  },
  {
    userIndex: 7,
    title: 'Apple Farming in Hills | पहाड़ों में सेब की खेती',
    description: 'Complete apple cultivation guide for Uttarakhand, HP, Kashmir. Variety selection, planting, pruning, pest management, and marketing. पहाड़ी क्षेत्रों में सेब की successful खेती।',
    thumbnail: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=apple-farming',
    videoType: 'youtube',
    duration: 2400,
    tags: ['apple', 'सेब', 'horticulture', 'uttarakhand', 'hills'],
    category: 'Horticulture',
    views: 45678,
    likes: 3789,
  },
  {
    userIndex: 8,
    title: 'Cumin Cultivation | जीरे की खेती - Rajasthan का White Gold',
    description: 'Cumin farming complete guide. Land preparation, sowing, irrigation, disease management. How Rajasthan farmers earn lakhs from cumin. जीरे से लाखों की कमाई।',
    thumbnail: 'https://images.unsplash.com/photo-1599909533016-b472b8db86f5?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=cumin-farming',
    videoType: 'youtube',
    duration: 1800,
    tags: ['cumin', 'जीरा', 'rajasthan', 'spice', 'रबी'],
    category: 'Crop Cultivation',
    views: 56789,
    likes: 4567,
  },
  {
    userIndex: 9,
    title: 'Fish Farming for Beginners | मछली पालन कैसे शुरू करें',
    description: 'Complete fish farming guide for beginners. Pond construction, species selection, feeding, disease management. How to earn ₹2 lakh from 1 acre pond. मछली पालन से कमाई।',
    thumbnail: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=fish-farming',
    videoType: 'youtube',
    duration: 2700,
    tags: ['fish', 'मछली', 'pisciculture', 'pond', 'aquaculture'],
    category: 'Allied Activities',
    views: 98765,
    likes: 8765,
  },
  {
    userIndex: 0,
    title: 'Vermicompost Making at Home | वर्मीकम्पोस्ट बनाने का आसान तरीका',
    description: 'How to make vermicompost at home. Low investment business idea. Earn ₹8000/ton. Step by step process with investment details. वर्मीकम्पोस्ट बनाकर कमाई करें।',
    thumbnail: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=vermicompost',
    videoType: 'youtube',
    duration: 1500,
    tags: ['vermicompost', 'organic', 'जैविक खाद', 'business', 'earthworm'],
    category: 'Organic Farming',
    views: 87654,
    likes: 7654,
  },
  {
    userIndex: 2,
    title: 'Turmeric Processing & Marketing | हल्दी की प्रोसेसिंग और मार्केटिंग',
    description: 'Value addition in turmeric. Boiling, drying, polishing, powder making. How to get ₹200/kg for processed turmeric. हल्दी में value addition से दोगुनी कमाई।',
    thumbnail: 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=400',
    videoUrl: 'https://www.youtube.com/watch?v=turmeric-processing',
    videoType: 'youtube',
    duration: 2100,
    tags: ['turmeric', 'हल्दी', 'processing', 'marketing', 'value addition'],
    category: 'Post Harvest',
    views: 65432,
    likes: 5432,
  },
];

// ============================================
// MAIN SEED FUNCTION
// ============================================
async function seedReelDatabase() {
  try {
    // Connect to MongoDB
    const mongoUrl = process.env.MONGODB_URI || process.env.MONGODB_URL;
    if (!mongoUrl) {
      throw new Error('MONGODB_URI environment variable is not set');
    }

    console.log('🌱 Connecting to MongoDB...');
    await mongoose.connect(mongoUrl);
    console.log('✅ Connected to MongoDB');

    // Clear existing data
    console.log('\n🗑️  Clearing existing reel data...');
    await Promise.all([
      Reel.deleteMany({}),
      VideoTutorial.deleteMany({}),
      ReelComment.deleteMany({}),
      ReelLike.deleteMany({}),
      ReelTag.deleteMany({}),
    ]);
    console.log('✅ Existing reel data cleared');

    // 1. Create Reels
    console.log('\n🎬 Creating reels...');
    const createdReels = [];
    for (const reelData of reelsData) {
      const user = usersData[reelData.userIndex];

      // Generate random users who liked
      const likedUsers = usersData
        .filter((_, i) => Math.random() > 0.5)
        .map(u => u.id);

      const reel = await Reel.create({
        userId: user.id,
        userName: user.name,
        profilePhoto: user.profilePhoto,
        description: reelData.description,
        mediaUrl: reelData.mediaUrl,
        thumbnail: reelData.thumbnail,
        like: {
          count: reelData.likes,
          users: likedUsers,
        },
        comment: { count: Math.floor(Math.random() * 50) + 10 },
        location: {
          type: 'Point',
          coordinates: [user.location.longitude, user.location.latitude],
        },
        isActive: true,
        viewCount: reelData.views,
      });
      createdReels.push(reel);
    }
    console.log(`✅ Created ${createdReels.length} reels`);

    // 2. Create Video Tutorials
    console.log('\n📹 Creating video tutorials...');
    const createdVideos = [];
    for (const videoData of videoTutorialsData) {
      const user = usersData[videoData.userIndex];

      const video = await VideoTutorial.create({
        userId: user.id,
        userName: user.name,
        profilePhoto: user.profilePhoto,
        title: videoData.title,
        description: videoData.description,
        thumbnail: videoData.thumbnail,
        videoUrl: videoData.videoUrl,
        videoType: videoData.videoType,
        duration: videoData.duration,
        tags: videoData.tags,
        category: videoData.category,
        visibility: 'public',
        likes: {
          count: videoData.likes,
          users: usersData.filter(() => Math.random() > 0.6).map(u => u.id),
        },
        views: {
          count: videoData.views,
          unique: usersData.filter(() => Math.random() > 0.3).map(u => u.id),
        },
        comments: { count: Math.floor(Math.random() * 30) + 5 },
        isActive: true,
      });
      createdVideos.push(video);
    }
    console.log(`✅ Created ${createdVideos.length} video tutorials`);

    // 3. Create Comments for Reels
    console.log('\n💬 Creating reel comments...');
    const reelCommentTexts = [
      'बहुत काम की जानकारी! 👍',
      'यह तरीका try करूंगा।',
      'कौन सी कंपनी की दवाई है?',
      'मेरे यहां भी यही problem है।',
      'Great tips! Very helpful.',
      'Video बहुत informative है।',
      'इसकी cost कितनी आएगी?',
      'Share करता हूं सब किसानों को।',
      'Best farming channel! 🌾',
      'अगला video जल्दी लाओ।',
    ];

    let totalReelComments = 0;
    for (const reel of createdReels) {
      const numComments = Math.floor(Math.random() * 5) + 2;
      for (let i = 0; i < numComments; i++) {
        const randomUser = usersData[Math.floor(Math.random() * usersData.length)];
        const randomComment = reelCommentTexts[Math.floor(Math.random() * reelCommentTexts.length)];

        await ReelComment.create({
          userId: randomUser.id,
          userName: randomUser.name,
          profilePhoto: randomUser.profilePhoto,
          reel: reel._id,
          content: randomComment,
          parentComment: null,
          likes: { count: Math.floor(Math.random() * 15), users: [] },
          replies: [],
          depth: 0,
          isDeleted: false,
        });
        totalReelComments++;
      }
    }
    console.log(`✅ Created ${totalReelComments} reel comments`);

    // 4. Create Likes for Reels
    console.log('\n❤️  Creating reel likes...');
    let totalReelLikes = 0;
    for (const reel of createdReels) {
      const numLikes = Math.floor(Math.random() * 6) + 2;
      const usedUsers = new Set();

      for (let i = 0; i < numLikes && usedUsers.size < usersData.length; i++) {
        let randomUser;
        do {
          randomUser = usersData[Math.floor(Math.random() * usersData.length)];
        } while (usedUsers.has(randomUser.id));

        usedUsers.add(randomUser.id);

        await ReelLike.create({
          userId: randomUser.id,
          userName: randomUser.name,
          profilePhoto: randomUser.profilePhoto,
          reel: reel._id,
        });
        totalReelLikes++;
      }
    }
    console.log(`✅ Created ${totalReelLikes} reel likes`);

    // 5. Create Tags
    console.log('\n🏷️  Creating reel tags...');
    const allTags = new Map();

    for (const reel of createdReels) {
      const hashtags = reel.description.match(/#[a-zA-Z0-9_\u0900-\u097F]+/g) || [];
      for (const hashtag of hashtags) {
        const tagName = hashtag.slice(1).toLowerCase();
        if (!allTags.has(tagName)) {
          allTags.set(tagName, { reels: [reel._id], count: 1 });
        } else {
          const existing = allTags.get(tagName);
          existing.reels.push(reel._id);
          existing.count++;
        }
      }
    }

    const tagDocs = [];
    for (const [name, data] of allTags) {
      tagDocs.push({
        name,
        reels: data.reels,
        count: data.count,
        lastUsed: new Date(),
      });
    }
    await ReelTag.insertMany(tagDocs);
    console.log(`✅ Created ${tagDocs.length} reel tags`);

    // Summary
    console.log('\n' + '='.repeat(50));
    console.log('🎉 REEL SEED DATA COMPLETE!');
    console.log('='.repeat(50));
    console.log(`
Summary:
- Reels: ${createdReels.length}
- Video Tutorials: ${createdVideos.length}
- Reel Comments: ${totalReelComments}
- Reel Likes: ${totalReelLikes}
- Reel Tags: ${tagDocs.length}
    `);

    await mongoose.connection.close();
    console.log('✅ Database connection closed');
    process.exit(0);

  } catch (error) {
    console.error('❌ Error seeding reel database:', error);
    process.exit(1);
  }
}

// Run the seed function
seedReelDatabase();
