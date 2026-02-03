/**
 * Krishi-Mantra Feed Service Seed Data Script
 * Adds realistic farming feed posts, comments, likes, and tags
 *
 * Usage: node src/scripts/seedFeedData.js
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env.development') });
const mongoose = require('mongoose');

// Models - Feed Service
const Feed = require('../model/FeedModel');
const Comment = require('../model/CommetModel');
const Like = require('../model/LikeModel');
const Tag = require('../model/Tags');
const UserInterest = require('../model/userInterest');

// ============================================
// USERS DATA (Same as main-service for consistency)
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
// FEED POSTS DATA - Realistic Farming Content
// ============================================
const feedsData = [
  {
    userIndex: 0,
    description: 'My organic cotton field',
    content: 'गर्व का पल! मेरी जैविक कपास की फसल इस साल 25 क्विंटल प्रति एकड़ उत्पादन दे रही है। पिछले 3 साल से रासायनिक खाद बंद कर दी। अब सिर्फ वर्मीकम्पोस्ट और जीवामृत का उपयोग करता हूं। किसान साथी भी प्राकृतिक खेती अपनाएं! #OrganicFarming #Cotton #किसान #JaivikKheti',
    mediaUrl: 'https://images.unsplash.com/photo-1599719500956-d158a26ab3ee?w=800',
    likes: 156,
    comments: 23,
    views: 890,
  },
  {
    userIndex: 1,
    description: 'Wheat sowing complete',
    content: 'रबी सीजन 2026 की शुरुआत हो गई! आज 15 एकड़ में गेहूं की बुवाई पूरी की। HD-3226 किस्म लगाई है जो 115 दिन में तैयार होती है। MSP ₹2,585 मिलने की उम्मीद है। सभी किसान भाइयों को शुभकामनाएं! 🌾 #Wheat #RabiSeason #Punjab #गेहूं',
    mediaUrl: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=800',
    likes: 234,
    comments: 45,
    views: 1560,
  },
  {
    userIndex: 2,
    description: 'Drip irrigation success',
    content: 'ड्रिप इरिगेशन से मिर्च की खेती में क्रांति! पहले 8 क्विंटल मिलता था, अब 15 क्विंटल प्रति एकड़। पानी की बचत 60% और खाद की बचत 40%। सरकारी सब्सिडी 55% मिली थी। तेलंगाना के किसान साथी जरूर लगाएं! #DripIrrigation #Chili #WaterSaving',
    mediaUrl: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
    likes: 312,
    comments: 56,
    views: 2100,
  },
  {
    userIndex: 3,
    description: 'Sugarcane harvesting begins',
    content: 'गन्ने की कटाई शुरू! इस बार 450 क्विंटल प्रति एकड़ की उम्मीद है। Co-0238 किस्म ने कमाल किया। शुगर मिल का रेट ₹360 प्रति क्विंटल मिल रहा है। UP के किसान भाई अपना अनुभव शेयर करें। #Sugarcane #गन्ना #UttarPradesh',
    mediaUrl: 'https://images.unsplash.com/photo-1597916829826-02e5bb4a54e0?w=800',
    likes: 189,
    comments: 34,
    views: 1230,
  },
  {
    userIndex: 4,
    description: 'Paddy transplanting done',
    content: 'SRI विधि से धान की रोपाई पूरी। एक पौधे से 40-50 कल्ले निकलते हैं। पारंपरिक तरीके से 15-20 ही निकलते थे। 20% ज्यादा उत्पादन और 30% कम पानी। तमिलनाडु के किसान यह विधि जरूर अपनाएं! #SRI #Paddy #Rice #TamilNadu',
    mediaUrl: 'https://images.unsplash.com/photo-1536054024090-c2df1bd15e79?w=800',
    likes: 267,
    comments: 41,
    views: 1780,
  },
  {
    userIndex: 5,
    description: 'New tractor delivery',
    content: 'आज मेरी नई Mahindra 575 DI आ गई! 45 HP, पावर स्टीयरिंग, डुअल क्लच। EMI ₹18,000 प्रति महीना। पुराना वाला 12 साल चला। किसान साथी ट्रैक्टर लेने से पहले टेस्ट ड्राइव जरूर करें। #Tractor #Mahindra #FarmMechanization',
    mediaUrl: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800',
    likes: 445,
    comments: 78,
    views: 3200,
  },
  {
    userIndex: 6,
    description: 'Soybean bumper harvest',
    content: 'सोयाबीन की बम्पर फसल! 18 क्विंटल प्रति एकड़ मिला। JS-9560 किस्म और सही समय पर बुवाई का कमाल। मंडी में ₹4,800 प्रति क्विंटल भाव मिला। #Soybean #सोयाबीन #MadhyaPradesh #Kharif',
    mediaUrl: 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=800',
    likes: 178,
    comments: 29,
    views: 980,
  },
  {
    userIndex: 7,
    description: 'Apple orchard update',
    content: 'पहाड़ी खेती में सफलता! Royal Delicious सेब की 200 पेटी का उत्पादन। ऑर्गेनिक तरीके से उगाया। दिल्ली मंडी में ₹2,500 प्रति पेटी मिला। उत्तराखंड के किसान सेब की खेती में नई तकनीक अपनाएं। #Apple #Uttarakhand #Horticulture',
    mediaUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=800',
    likes: 298,
    comments: 52,
    views: 1650,
  },
  {
    userIndex: 8,
    description: 'Desert farming miracle',
    content: 'राजस्थान में ड्रिप से अनार की खेती! सूखे इलाके में भी 8 टन प्रति एकड़ उत्पादन। Bhagwa किस्म लगाई थी। फल का साइज और रंग बेहतरीन। एक्सपोर्ट क्वालिटी। #Pomegranate #Rajasthan #DesertFarming',
    mediaUrl: 'https://images.unsplash.com/photo-1615484477778-ca3b77940c25?w=800',
    likes: 356,
    comments: 63,
    views: 2340,
  },
  {
    userIndex: 9,
    description: 'Fish farming success',
    content: 'मछली पालन से आमदनी दोगुनी! 1 एकड़ तालाब में रोहू, कतला, मृगल का पालन। 6 महीने में 30 क्विंटल मछली। ₹1.5 लाख का शुद्ध मुनाफा। पश्चिम बंगाल में मछली की बहुत मांग है। #FishFarming #Pisciculture #WestBengal',
    mediaUrl: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800',
    likes: 223,
    comments: 47,
    views: 1890,
  },
  {
    userIndex: 0,
    description: 'Vermicompost making',
    content: 'घर पर वर्मीकम्पोस्ट बनाना सीखें! 3 महीने में 1 टन खाद तैयार। लागत मात्र ₹2,000, बाजार में ₹8,000 में बिकती है। गोबर + कचरा + केंचुआ = काला सोना। वीडियो जल्द आएगा। #Vermicompost #OrganicFertilizer #SustainableFarming',
    mediaUrl: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800',
    likes: 412,
    comments: 89,
    views: 2780,
  },
  {
    userIndex: 2,
    description: 'Turmeric cultivation tips',
    content: 'हल्दी की खेती में कमाल का मुनाफा! 100 क्विंटल प्रति एकड़ कच्ची हल्दी। सूखी हल्दी 25 क्विंटल मिली। मंडी में ₹12,000 प्रति क्विंटल भाव। Selam और Rajapuri किस्म बेस्ट हैं। #Turmeric #हल्दी #Telangana #SpiceFarming',
    mediaUrl: 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=800',
    likes: 287,
    comments: 54,
    views: 1670,
  },
  {
    userIndex: 3,
    description: 'Government scheme benefit',
    content: 'PM-KISAN का 19वां किस्त आ गया! ₹2,000 सीधे खाते में। 3 साल में ₹36,000 मिले। PMFBY से भी पिछले साल ₹45,000 का claim मिला था। सभी किसान इन योजनाओं का लाभ जरूर लें। #PMKisan #PMFBY #GovtScheme',
    mediaUrl: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800',
    likes: 534,
    comments: 112,
    views: 4560,
  },
  {
    userIndex: 4,
    description: 'Banana cultivation',
    content: 'केले की टिशू कल्चर खेती! Grand Naine किस्म से 35 टन प्रति एकड़। 12 महीने में फसल तैयार। एक्सपोर्ट क्वालिटी केला। तमिलनाडु में केला किसानों के लिए सुनहरा मौका। #Banana #TissueCulture #Export',
    mediaUrl: 'https://images.unsplash.com/photo-1603833665858-e61d17a86224?w=800',
    likes: 198,
    comments: 36,
    views: 1120,
  },
  {
    userIndex: 5,
    description: 'Combine harvester',
    content: 'कंबाइन हार्वेस्टर से गेहूं की कटाई! 1 घंटे में 1 एकड़ कटाई। मजदूरी का खर्चा 80% कम। किराए पर ₹1,800 प्रति एकड़ में मिल जाता है। पंजाब में मशीनीकरण का कमाल। #CombineHarvester #WheatHarvest #Punjab',
    mediaUrl: 'https://images.unsplash.com/photo-1591086517675-d4f4c5e96d83?w=800',
    likes: 367,
    comments: 71,
    views: 2890,
  },
];

// ============================================
// COMMENTS DATA
// ============================================
const commentsData = [
  { content: 'बहुत बढ़िया जानकारी! मैं भी यह तरीका अपनाऊंगा।' },
  { content: 'कौन सी दवाई spray करते हो भाई?' },
  { content: 'सब्सिडी कैसे मिली? प्रोसेस बताओ।' },
  { content: 'मेरे यहां भी यही समस्या है। क्या करूं?' },
  { content: 'बहुत मेहनत की है आपने। सलाम!' },
  { content: 'किस कंपनी का बीज लगाया था?' },
  { content: 'खर्चा कितना आया पूरी फसल में?' },
  { content: 'मेरे यहां भी ऐसे ही रिजल्ट मिले।' },
  { content: 'वीडियो बनाओ इसका detailed।' },
  { content: 'Mandi ka address share karo.' },
  { content: 'Excellent! Organic farming is the future.' },
  { content: 'सिंचाई कितने दिन बाद करते हो?' },
  { content: 'मौसम का असर कैसा रहा इस बार?' },
  { content: 'Next year मैं भी यही लगाऊंगा।' },
  { content: 'Soil testing कहां से कराया?' },
];

// ============================================
// MAIN SEED FUNCTION
// ============================================
async function seedFeedDatabase() {
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
    console.log('\n🗑️  Clearing existing feed data...');
    await Promise.all([
      Feed.deleteMany({}),
      Comment.deleteMany({}),
      Like.deleteMany({}),
      Tag.deleteMany({}),
      UserInterest.deleteMany({}),
    ]);
    console.log('✅ Existing feed data cleared');

    // 1. Create Feeds
    console.log('\n📝 Creating feed posts...');
    const createdFeeds = [];
    for (const feedData of feedsData) {
      const user = usersData[feedData.userIndex];
      const feed = await Feed.create({
        userId: user.id,
        userName: user.name,
        profilePhoto: user.profilePhoto,
        description: feedData.description,
        content: feedData.content,
        mediaUrl: feedData.mediaUrl,
        like: { count: feedData.likes },
        comment: { count: feedData.comments },
        views: { count: feedData.views, lastViewed: new Date() },
        location: {
          type: 'Point',
          coordinates: [user.location.longitude, user.location.latitude],
          latitude: user.location.latitude,
          longitude: user.location.longitude,
        },
        isDeleted: false,
      });
      createdFeeds.push(feed);
    }
    console.log(`✅ Created ${createdFeeds.length} feed posts`);

    // 2. Create Comments for each feed
    console.log('\n💬 Creating comments...');
    let totalComments = 0;
    for (const feed of createdFeeds) {
      // Add 2-5 comments per feed
      const numComments = Math.floor(Math.random() * 4) + 2;
      for (let i = 0; i < numComments; i++) {
        const randomUser = usersData[Math.floor(Math.random() * usersData.length)];
        const randomComment = commentsData[Math.floor(Math.random() * commentsData.length)];

        await Comment.create({
          userId: randomUser.id,
          userName: randomUser.name,
          profilePhoto: randomUser.profilePhoto,
          feed: feed._id,
          content: randomComment.content,
          parentComment: null,
          likes: { count: Math.floor(Math.random() * 20), users: [] },
          replies: [],
          replyCount: 0,
          depth: 0,
          isDeleted: false,
        });
        totalComments++;
      }
    }
    console.log(`✅ Created ${totalComments} comments`);

    // 3. Create Likes for each feed
    console.log('\n❤️  Creating likes...');
    let totalLikes = 0;
    for (const feed of createdFeeds) {
      // Add random likes from different users
      const numLikes = Math.floor(Math.random() * 8) + 2;
      const usedUsers = new Set();

      for (let i = 0; i < numLikes && usedUsers.size < usersData.length; i++) {
        let randomUser;
        do {
          randomUser = usersData[Math.floor(Math.random() * usersData.length)];
        } while (usedUsers.has(randomUser.id));

        usedUsers.add(randomUser.id);

        await Like.create({
          userId: randomUser.id,
          userName: randomUser.name,
          profilePhoto: randomUser.profilePhoto,
          feed: feed._id,
        });
        totalLikes++;
      }
    }
    console.log(`✅ Created ${totalLikes} likes`);

    // 4. Create/Update Tags
    console.log('\n🏷️  Creating tags...');
    const allTags = new Map();

    for (const feed of createdFeeds) {
      // Extract hashtags from content
      const hashtags = feed.content.match(/#[a-zA-Z0-9_\u0900-\u097F]+/g) || [];

      for (const hashtag of hashtags) {
        const tagName = hashtag.slice(1).toLowerCase();

        if (!allTags.has(tagName)) {
          allTags.set(tagName, { feedIds: [feed._id], engagement: feed.like.count + feed.views.count });
        } else {
          const existing = allTags.get(tagName);
          existing.feedIds.push(feed._id);
          existing.engagement += feed.like.count + feed.views.count;
        }
      }
    }

    const tagDocs = [];
    for (const [name, data] of allTags) {
      tagDocs.push({
        name,
        feedId: data.feedIds,
        feedCount: data.feedIds.length,
        totalEngagement: data.engagement,
        lastActivity: new Date(),
      });
    }
    await Tag.insertMany(tagDocs);
    console.log(`✅ Created ${tagDocs.length} tags`);

    // 5. Create User Interests
    console.log('\n🎯 Creating user interests...');
    for (const user of usersData) {
      const interests = [
        { tag: 'organic farming', score: Math.random() * 100, lastInteraction: new Date() },
        { tag: 'wheat', score: Math.random() * 100, lastInteraction: new Date() },
        { tag: 'tractor', score: Math.random() * 100, lastInteraction: new Date() },
        { tag: 'irrigation', score: Math.random() * 100, lastInteraction: new Date() },
      ];

      await UserInterest.create({
        userId: user.id,
        location: {
          latitude: user.location.latitude,
          longitude: user.location.longitude,
          lastUpdated: new Date(),
        },
        interests,
        recentViews: createdFeeds.slice(0, 5).map(f => ({ feedId: f._id, viewedAt: new Date() })),
        categories: ['agriculture', 'farming', 'organic'],
        engagementLevel: 'high',
        lastActive: new Date(),
      });
    }
    console.log(`✅ Created ${usersData.length} user interests`);

    // Summary
    console.log('\n' + '='.repeat(50));
    console.log('🎉 FEED SEED DATA COMPLETE!');
    console.log('='.repeat(50));
    console.log(`
Summary:
- Feed Posts: ${createdFeeds.length}
- Comments: ${totalComments}
- Likes: ${totalLikes}
- Tags: ${tagDocs.length}
- User Interests: ${usersData.length}
    `);

    await mongoose.connection.close();
    console.log('✅ Database connection closed');
    process.exit(0);

  } catch (error) {
    console.error('❌ Error seeding feed database:', error);
    process.exit(1);
  }
}

// Run the seed function
seedFeedDatabase();
