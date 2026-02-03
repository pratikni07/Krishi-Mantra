/**
 * Krishi-Mantra - Add More Feed Posts Script
 * Adds 50 more realistic farming feed posts
 *
 * Usage: node src/scripts/seedMoreFeeds.js
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env.development') });
const mongoose = require('mongoose');

const Feed = require('../model/FeedModel');
const Comment = require('../model/CommetModel');
const Like = require('../model/LikeModel');
const Tag = require('../model/Tags');

// Realistic Indian farming posts in Hindi/English mix
const postTemplates = [
  {
    description: 'Wheat field update',
    content: 'गेहूं में पहली सिंचाई कर दी। मौसम बहुत अच्छा है इस बार। उम्मीद है 50 क्विंटल प्रति एकड़ मिलेगा। HD-3226 किस्म लगाई है। #Wheat #गेहूं #RabiSeason',
    mediaUrl: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=800',
  },
  {
    description: 'Organic farming success',
    content: 'जैविक खेती से मेरी आमदनी दोगुनी हो गई! पिछले 3 साल से कोई रासायनिक खाद नहीं डाली। अब प्रीमियम रेट मिलता है। सब्जियां दिल्ली के ऑर्गेनिक स्टोर में जाती हैं। #OrganicFarming #JaivikKheti',
    mediaUrl: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800',
  },
  {
    description: 'New tractor arrived',
    content: 'Finally! Swaraj 744 FE आ गया। 48 HP, AC cabin, power steering। अब खेती में मजा आएगा। EMI ₹22,000 per month। किसान भाई ट्रैक्टर जरूर लें, मजदूरी बचती है। #Tractor #Swaraj #FarmMechanization',
    mediaUrl: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800',
  },
  {
    description: 'Cotton picking started',
    content: 'कपास की चुनाई शुरू! इस बार 20 क्विंटल प्रति एकड़ की उम्मीद। BT Cotton लगाई थी, कीड़ा बिल्कुल नहीं लगा। मंडी में ₹7,500 प्रति क्विंटल भाव चल रहा है। #Cotton #कपास #Gujarat',
    mediaUrl: 'https://images.unsplash.com/photo-1599719500956-d158a26ab3ee?w=800',
  },
  {
    description: 'Drip irrigation installation',
    content: 'ड्रिप लगवा लिया 5 एकड़ में! सरकारी सब्सिडी 55% मिली। ₹45,000 में पूरा सिस्टम। पानी की 60% बचत होगी। Vegetables में बहुत फायदा होगा। #DripIrrigation #WaterSaving',
    mediaUrl: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
  },
  {
    description: 'Potato harvesting',
    content: 'आलू निकालना शुरू! 300 क्विंटल प्रति एकड़ yield आई। Kufri Pukhraj variety लगाई थी। Cold storage में रखूंगा, 3 महीने बाद अच्छा भाव मिलेगा। #Potato #आलू #UP',
    mediaUrl: 'https://images.unsplash.com/photo-1518977676601-b53f82ber1b?w=800',
  },
  {
    description: 'Sugarcane field',
    content: 'गन्ने की फसल तैयार! Co-0238 variety में 500 क्विंटल प्रति एकड़ expected। शुगर मिल का टोकन मिल गया। ₹380 प्रति क्विंटल रेट। #Sugarcane #गन्ना #UttarPradesh',
    mediaUrl: 'https://images.unsplash.com/photo-1597916829826-02e5bb4a54e0?w=800',
  },
  {
    description: 'Soybean harvest',
    content: 'सोयाबीन थ्रेशिंग पूरी! 15 क्विंटल प्रति एकड़ मिला। JS-9560 variety best है MP के लिए। मंडी में ₹4,600 प्रति क्विंटल भाव। खुश हूं इस साल की फसल से। #Soybean #सोयाबीन #MP',
    mediaUrl: 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=800',
  },
  {
    description: 'Tomato farming',
    content: 'टमाटर में bumper production! Polyhouse में उगाया, 80 टन प्रति एकड़। Off-season में ₹60/kg भाव मिला। Total income ₹48 लाख। Polyhouse farming is the future! #Tomato #टमाटर #Polyhouse',
    mediaUrl: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=800',
  },
  {
    description: 'PM-KISAN received',
    content: 'PM-KISAN का पैसा आ गया! ₹2,000 सीधे bank में। अब तक ₹38,000 मिल चुके हैं इस scheme से। सभी किसान भाई eKYC करवा लें। Government schemes का फायदा उठाओ! #PMKisan #DBT',
    mediaUrl: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800',
  },
  {
    description: 'Paddy transplanting',
    content: 'धान की रोपाई पूरी! SRI method से लगाया। एक पौधे से 45 कल्ले निकले। पारंपरिक तरीके से 15-20 ही निकलते थे। 40% ज्यादा yield expected। #Paddy #SRI #धान',
    mediaUrl: 'https://images.unsplash.com/photo-1536054024090-c2df1bd15e79?w=800',
  },
  {
    description: 'Mango orchard',
    content: 'आम के बाग में फूल आ गए! Alphonso और Kesar variety। इस साल 10 टन production expected। Export quality mangoes। Dubai और Europe में जाएंगे। #Mango #आम #Horticulture',
    mediaUrl: 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=800',
  },
  {
    description: 'Dairy farming update',
    content: 'डेयरी में अब 15 गाय और 10 भैंस। रोज 200 लीटर दूध। Amul को सप्लाई करता हूं। Monthly income ₹1.5 लाख। Farming + Dairy = Double income! #DairyFarming #Milk #Amul',
    mediaUrl: 'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800',
  },
  {
    description: 'Onion storage',
    content: 'प्याज store कर दिया! 100 टन cold storage में। अभी ₹15/kg है, 3 महीने बाद ₹40+ होगा। Storage charges ₹2/kg/month। Patience is key in farming! #Onion #प्याज #Storage',
    mediaUrl: 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=800',
  },
  {
    description: 'Turmeric processing',
    content: 'हल्दी की processing शुरू! Boiling, drying, polishing सब यहीं करता हूं। Raw हल्दी ₹50/kg, processed ₹150/kg। Value addition से triple income! #Turmeric #हल्दी #ValueAddition',
    mediaUrl: 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=800',
  },
  {
    description: 'Mustard flowering',
    content: 'सरसों में पीले फूल! बहुत खूबसूरत लग रहा खेत। Pusa Bold variety, 20 क्विंटल प्रति एकड़ expected। तेल निकालने की अपनी मशीन है। #Mustard #सरसों #Rajasthan',
    mediaUrl: 'https://images.unsplash.com/photo-1557800636-894a64c1696f?w=800',
  },
  {
    description: 'Grape vineyard',
    content: 'अंगूर तैयार! Thompson Seedless variety, export quality। Nashik से Dubai जाएंगे। ₹80/kg export rate। Grape farming में future है Maharashtra में। #Grapes #अंगूर #Export',
    mediaUrl: 'https://images.unsplash.com/photo-1537640538966-79f369143f8f?w=800',
  },
  {
    description: 'Fish farming profit',
    content: 'मछली पालन से लाखों की कमाई! 2 एकड़ तालाब में Rohu, Catla, Mrigal। 6 महीने में 5 टन production। ₹3 लाख profit। Integrated farming best है! #FishFarming #मछली',
    mediaUrl: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800',
  },
  {
    description: 'Vermicompost unit',
    content: 'Vermicompost unit से extra income! हर महीने 2 टन खाद बनती है। ₹8/kg में बेचता हूं। ₹16,000 monthly income, zero investment after setup। #Vermicompost #OrganicFertilizer',
    mediaUrl: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
  },
  {
    description: 'Solar pump installed',
    content: 'Solar pump लगवा लिया! 5 HP, government subsidy 60%। अब बिजली का झंझट खत्म। Free पानी, unlimited irrigation। Best investment for farmers! #SolarPump #RenewableEnergy',
    mediaUrl: 'https://images.unsplash.com/photo-1509391366360-2e959784a276?w=800',
  },
  {
    description: 'Chili harvest',
    content: 'मिर्च की तुड़ाई! Guntur Sannam variety, 50 क्विंटल dry chili expected। मंडी में ₹18,000 प्रति क्विंटल। Andhra की मिर्च world famous! #Chili #मिर्च #Guntur',
    mediaUrl: 'https://images.unsplash.com/photo-1583119022894-919a68a3d0e3?w=800',
  },
  {
    description: 'Banana cultivation',
    content: 'केले का बाग! Grand Naine variety, tissue culture plants। 40 टन प्रति एकड़ expected। 12 महीने में ready। Export to Middle East। #Banana #केला #TissueCulture',
    mediaUrl: 'https://images.unsplash.com/photo-1603833665858-e61d17a86224?w=800',
  },
  {
    description: 'Mushroom farming',
    content: 'Mushroom farming से ₹50,000/month! 10x10 room में शुरू किया। Oyster mushroom, 3 weeks में ready। Hotels और restaurants में supply। Low investment, high return! #Mushroom #मशरूम',
    mediaUrl: 'https://images.unsplash.com/photo-1504545102780-26774c1bb073?w=800',
  },
  {
    description: 'Combine harvester',
    content: 'Combine से गेहूं की कटाई! 1 घंटे में 1 एकड़। पहले 10 मजदूर लगते थे, अब machine से 1 दिन में 20 एकड़। ₹1,800/acre rental charges। Mechanization is must! #Combine #Harvest',
    mediaUrl: 'https://images.unsplash.com/photo-1591086517675-d4f4c5e96d83?w=800',
  },
  {
    description: 'Greenhouse farming',
    content: 'Greenhouse में capsicum! Year round production, premium prices। 50 टन प्रति एकड़। Big Bazaar और Reliance Fresh को direct supply। ₹12 लाख annual income। #Greenhouse #Capsicum',
    mediaUrl: 'https://images.unsplash.com/photo-1585500001445-17a9ada7e9a1?w=800',
  },
  {
    description: 'Cumin cultivation',
    content: 'जीरे की बुवाई पूरी! GC-4 variety, Rajasthan का white gold। 8 क्विंटल प्रति एकड़ expected। MSP ₹7,500/quintal। Water requirement कम, profit ज्यादा! #Cumin #जीरा',
    mediaUrl: 'https://images.unsplash.com/photo-1599909533016-b472b8db86f5?w=800',
  },
  {
    description: 'Goat farming',
    content: 'बकरी पालन में success! 50 बकरियों से शुरू किया, अब 200 हैं। Sirohi और Beetal breed। Eid पर double rate। ₹5 लाख annual profit। #GoatFarming #बकरी',
    mediaUrl: 'https://images.unsplash.com/photo-1524024973431-2ad916746881?w=800',
  },
  {
    description: 'Crop insurance claim',
    content: 'PMFBY का claim मिल गया! बाढ़ से फसल खराब हुई थी। ₹85,000 का insurance claim 45 दिन में। सभी किसान crop insurance जरूर करवाएं! #PMFBY #CropInsurance',
    mediaUrl: 'https://images.unsplash.com/photo-1560493676-04071c5f467b?w=800',
  },
  {
    description: 'Maize silage making',
    content: 'Maize silage बनाना शुरू! Dairy के लिए best feed। 6 महीने तक store रहता है। Milk production 20% बढ़ जाता है। Progressive dairy farming! #Maize #Silage #DairyFeed',
    mediaUrl: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=800',
  },
  {
    description: 'Pomegranate orchard',
    content: 'अनार का बाग ready! Bhagwa variety, 15 टन प्रति एकड़। Export quality, EU certified। ₹80/kg export rate। Maharashtra का red gold! #Pomegranate #अनार #Export',
    mediaUrl: 'https://images.unsplash.com/photo-1615484477778-ca3b77940c25?w=800',
  },
];

// Comment templates
const commentTemplates = [
  'बहुत बढ़िया! 👍',
  'कौन सी variety लगाई थी?',
  'खर्चा कितना आया total?',
  'Subsidy कैसे मिली?',
  'मेरे यहां भी यही problem है',
  'Very informative post!',
  'Success story! Congratulations!',
  'किस mandi में बेचा?',
  'Irrigation schedule क्या था?',
  'Seeds कहां से लिए?',
  'Pesticide कौन सा use किया?',
  'Climate यहां suit करेगा?',
  'अगला video बनाओ इसका',
  'Contact number share करो',
  'Training कहां से ली?',
];

// Generate random user data for posts
function getRandomUser(index) {
  const names = [
    'Rajesh Sharma', 'Sunita Verma', 'Rampal Singh', 'Geeta Devi', 'Mukesh Patel',
    'Kamla Yadav', 'Suresh Kumar', 'Lakshmi Reddy', 'Dinesh Jat', 'Parvati Naidu',
    'Anil Gupta', 'Savita Chauhan', 'Vinod Mishra', 'Rekha Pandey', 'Prakash Das'
  ];
  const name = names[index % names.length];
  const isMale = !name.includes('Sunita') && !name.includes('Geeta') && !name.includes('Kamla') &&
                 !name.includes('Lakshmi') && !name.includes('Parvati') && !name.includes('Savita') && !name.includes('Rekha');

  return {
    id: (index + 100).toString(),
    name,
    profilePhoto: `https://randomuser.me/api/portraits/${isMale ? 'men' : 'women'}/${(index % 99) + 1}.jpg`,
    location: {
      latitude: 20 + Math.random() * 12, // India lat range
      longitude: 72 + Math.random() * 20, // India lng range
    }
  };
}

async function seedMoreFeeds() {
  try {
    const mongoUrl = process.env.MONGODB_URI || process.env.MONGODB_URL;
    if (!mongoUrl) {
      throw new Error('MONGODB_URI environment variable is not set');
    }

    console.log('🌱 Connecting to MongoDB...');
    await mongoose.connect(mongoUrl);
    console.log('✅ Connected to MongoDB');

    console.log('\n📝 Adding 50 more feed posts...');

    let createdFeeds = 0;
    let createdComments = 0;
    let createdLikes = 0;

    for (let i = 0; i < 50; i++) {
      const template = postTemplates[i % postTemplates.length];
      const user = getRandomUser(i);

      // Create feed
      const feed = await Feed.create({
        userId: user.id,
        userName: user.name,
        profilePhoto: user.profilePhoto,
        description: template.description,
        content: template.content,
        mediaUrl: template.mediaUrl,
        like: { count: Math.floor(Math.random() * 500) + 50 },
        comment: { count: Math.floor(Math.random() * 50) + 5 },
        views: { count: Math.floor(Math.random() * 3000) + 200, lastViewed: new Date() },
        location: {
          type: 'Point',
          coordinates: [user.location.longitude, user.location.latitude],
          latitude: user.location.latitude,
          longitude: user.location.longitude,
        },
        isDeleted: false,
      });
      createdFeeds++;

      // Add 2-5 comments
      const numComments = Math.floor(Math.random() * 4) + 2;
      for (let j = 0; j < numComments; j++) {
        const commenter = getRandomUser(i + j + 10);
        await Comment.create({
          userId: commenter.id,
          userName: commenter.name,
          profilePhoto: commenter.profilePhoto,
          feed: feed._id,
          content: commentTemplates[Math.floor(Math.random() * commentTemplates.length)],
          parentComment: null,
          likes: { count: Math.floor(Math.random() * 15), users: [] },
          replies: [],
          replyCount: 0,
          depth: 0,
          isDeleted: false,
        });
        createdComments++;
      }

      // Add 3-8 likes
      const numLikes = Math.floor(Math.random() * 6) + 3;
      const usedIds = new Set();
      for (let k = 0; k < numLikes; k++) {
        const liker = getRandomUser(i + k + 50);
        if (!usedIds.has(liker.id)) {
          usedIds.add(liker.id);
          await Like.create({
            userId: liker.id,
            userName: liker.name,
            profilePhoto: liker.profilePhoto,
            feed: feed._id,
          });
          createdLikes++;
        }
      }

      if ((i + 1) % 10 === 0) {
        console.log(`   ✓ Created ${i + 1} posts...`);
      }
    }

    // Update tags
    console.log('\n🏷️  Updating tags...');
    const feeds = await Feed.find({});
    const tagMap = new Map();

    for (const feed of feeds) {
      const hashtags = feed.content.match(/#[a-zA-Z0-9_\u0900-\u097F]+/g) || [];
      for (const hashtag of hashtags) {
        const tagName = hashtag.slice(1).toLowerCase();
        if (!tagMap.has(tagName)) {
          tagMap.set(tagName, { feedIds: [feed._id], engagement: feed.like.count + feed.views.count });
        } else {
          const existing = tagMap.get(tagName);
          if (!existing.feedIds.includes(feed._id)) {
            existing.feedIds.push(feed._id);
            existing.engagement += feed.like.count + feed.views.count;
          }
        }
      }
    }

    // Update or create tags
    for (const [name, data] of tagMap) {
      await Tag.findOneAndUpdate(
        { name },
        {
          $set: {
            feedId: data.feedIds,
            feedCount: data.feedIds.length,
            totalEngagement: data.engagement,
            lastActivity: new Date(),
          }
        },
        { upsert: true }
      );
    }

    const totalFeeds = await Feed.countDocuments();
    const totalComments = await Comment.countDocuments();
    const totalLikes = await Like.countDocuments();
    const totalTags = await Tag.countDocuments();

    console.log(`
✅ Feed data added successfully!

📊 New Records:
   - Feeds: ${createdFeeds}
   - Comments: ${createdComments}
   - Likes: ${createdLikes}

📈 Total in Database:
   - Feeds: ${totalFeeds}
   - Comments: ${totalComments}
   - Likes: ${totalLikes}
   - Tags: ${totalTags}
    `);

    await mongoose.connection.close();
    console.log('✅ Database connection closed');
    process.exit(0);

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

seedMoreFeeds();
