/**
 * Krishi-Mantra - Seed Ads Data Script
 * Adds realistic advertising data for all ad placements
 *
 * Usage: node src/scripts/seedAdsData.js
 */

const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
const mongoose = require('mongoose');

// UI Models
const HomeScreenAds = require('../model/UIModel/HomeScreen/HomeScreenAd');
const HomeSlider = require('../model/UIModel/HomeScreen/HomeSliderModel');
const SplashModal = require('../model/UIModel/HomeScreen/SplashModel');
const FeedAds = require('../model/UIModel/FeedScreen/FeedAds');
const ReelAds = require('../model/UIModel/FeedScreen/ReelAds');
const NewsAds = require('../model/UIModel/NewsScreen/NewsAds');
const UIDisplay = require('../model/UIModel/UIDisplay');
const MarketplaceProduct = require('../model/MarketplaceProduct');

// ============================================
// HOME SLIDER DATA - Banner Carousel
// ============================================
const homeSlidersData = [
  {
    title: 'PM-KISAN 19th Installment',
    content: '₹2,000 सीधे आपके खाते में! eKYC करवाएं और पैसे पाएं। Check your PM-KISAN status now.',
    dirURL: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=1200',
    modal: false,
    prority: 1,
  },
  {
    title: 'Rabi Season 2026 - Best Varieties',
    content: 'गेहूं, चना, सरसों की नई high-yielding varieties। MSP rates announced - ₹2,585/quintal wheat!',
    dirURL: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=1200',
    modal: false,
    prority: 2,
  },
  {
    title: 'PMFBY Crop Insurance - Enroll Now',
    content: 'अपनी फसल का बीमा करवाएं। Premium मात्र 1.5-2%। Natural calamities से 100% protection।',
    dirURL: 'https://images.unsplash.com/photo-1560493676-04071c5f467b?w=1200',
    modal: false,
    prority: 3,
  },
  {
    title: 'IFFCO Nano Urea - Available Now',
    content: 'एक bottle = एक बोरी यूरिया! 40% cost saving। Order online, free delivery।',
    dirURL: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=1200',
    modal: false,
    prority: 4,
  },
  {
    title: 'Kisan Credit Card - 4% Interest',
    content: 'KCC से ₹3 लाख तक loan at 4% interest। Apply online in 5 minutes।',
    dirURL: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=1200',
    modal: false,
    prority: 5,
  },
  {
    title: 'Weather Alert - IMD Forecast',
    content: 'इस हफ्ते बारिश की संभावना। अपनी फसल की सुरक्षा करें। Real-time weather updates।',
    dirURL: 'https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=1200',
    modal: false,
    prority: 6,
  },
  {
    title: 'Mandi Prices Live',
    content: 'आज का भाव: गेहूं ₹2,450 | सोयाबीन ₹4,600 | कपास ₹7,500। Check all mandi prices।',
    dirURL: 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=1200',
    modal: false,
    prority: 7,
  },
  {
    title: 'Krishi Mantra Premium - Free Trial',
    content: '7 days free! Expert consultation, AI crop doctor, priority support। Upgrade now।',
    dirURL: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=1200',
    modal: true,
    prority: 8,
  },
];

// ============================================
// HOME SCREEN ADS DATA - Banner Ads
// ============================================
const homeScreenAdsData = [
  {
    title: 'Mahindra Tractors - No.1 in India',
    content: 'Mahindra 575 DI XP Plus - 45 HP, Power Steering, Dual Clutch। EMI starts ₹15,999/month। Book test drive today! 1800-209-5678',
    dirURL: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800',
    prority: 1,
  },
  {
    title: 'Bayer Crop Science - Protect Your Crops',
    content: 'Confidor, Nativo, Admire - Complete pest protection। Buy genuine products online। 20% off on first order। Free delivery!',
    dirURL: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=800',
    prority: 2,
  },
  {
    title: 'SBI Kisan Credit Card',
    content: 'Agriculture loan up to ₹3 Lakh at just 4% interest। No collateral required। Apply online - approval in 48 hours। Call 1800-11-2211',
    dirURL: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800',
    prority: 3,
  },
  {
    title: 'Jain Irrigation - Drip Systems',
    content: 'Save 60% water, increase 40% yield। Government subsidy 55%। Complete installation support। Free site survey!',
    dirURL: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
    prority: 4,
  },
  {
    title: 'HDFC Bank Kisan Gold Card',
    content: 'Flexible credit for farmers। Interest rate from 7%। Insurance cover included। Apply now - instant approval!',
    dirURL: 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800',
    prority: 5,
  },
  {
    title: 'Swaraj Tractors - Built for India',
    content: 'Swaraj 744 FE - 48 HP, Fuel efficient, Low maintenance। Exchange bonus ₹50,000। Finance available at 0% down payment!',
    dirURL: 'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=800',
    prority: 6,
  },
  {
    title: 'UPL - Crop Protection Solutions',
    content: 'Saaf, Ulala, Phoskill - Trusted by millions of farmers। Buy online, doorstep delivery। Agri expert support 24/7।',
    dirURL: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800',
    prority: 7,
  },
  {
    title: 'Reliance Foundation - Farmer Support',
    content: 'Free agriculture advisory। Weather alerts। Market prices। Download JioKrishi app। Supporting 10 lakh+ farmers।',
    dirURL: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=800',
    prority: 8,
  },
  {
    title: 'TAFE Tractors - Since 1960',
    content: 'Massey Ferguson 241 DI - 42 HP, Best in class mileage। Trusted by 3 generations। EMI from ₹14,500/month।',
    dirURL: 'https://images.unsplash.com/photo-1591086517675-d4f4c5e96d83?w=800',
    prority: 9,
  },
  {
    title: 'Coromandel Fertilizers - Gromor',
    content: 'NPK, DAP, Urea - Premium quality fertilizers। Soil health card based recommendations। Order bulk - special discounts!',
    dirURL: 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=800',
    prority: 10,
  },
];

// ============================================
// SPLASH MODAL DATA - App Open Popups
// ============================================
const splashModalsData = [
  {
    title: '🎉 New Feature: AI Crop Doctor',
    content: 'Upload photo of your crop disease - get instant diagnosis and treatment! Try it now in Crop Care section.',
    dirURL: 'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=600',
    modal: true,
  },
  {
    title: '⚡ Flash Sale - 30% Off Seeds',
    content: 'Limited time offer on wheat, mustard, gram seeds। Premium quality, certified varieties। Order before stock runs out!',
    dirURL: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=600',
    modal: true,
  },
  {
    title: '📢 PM-KISAN Alert',
    content: '19th installment released! Check if ₹2,000 credited to your account। Complete eKYC if pending।',
    dirURL: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=600',
    modal: true,
  },
  {
    title: '🌾 Rabi Sowing Time',
    content: 'Best time to sow wheat, mustard, gram। Check our crop calendar for variety recommendations and schedule।',
    dirURL: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=600',
    modal: true,
  },
  {
    title: '🏆 Refer & Earn ₹100',
    content: 'Invite fellow farmers to Krishi Mantra। Get ₹100 for each successful referral। Unlimited earnings!',
    dirURL: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=600',
    modal: true,
  },
];

// ============================================
// FEED ADS DATA - In-Feed Native Ads
// ============================================
const feedAdsData = [
  {
    title: 'Mahindra Tractors',
    content: '🚜 Mahindra 575 DI - India\'s No.1 Tractor! 45 HP power, low maintenance, best resale value। EMI starts ₹15,999। Book free demo today! #Tractor #Mahindra',
    dirURL: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800',
    impression: 45678,
    views: 12345,
  },
  {
    title: 'Bayer Confidor',
    content: '🛡️ Protect your crops from sucking pests! Confidor - Most trusted insecticide। Effective on aphids, jassids, whiteflies। Buy genuine - 20% off। #CropProtection #Bayer',
    dirURL: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=800',
    impression: 34567,
    views: 9876,
  },
  {
    title: 'SBI Kisan Credit Card',
    content: '💳 KCC loan at just 4% interest! Up to ₹3 Lakh without collateral। Instant approval, easy EMI। Apply online now। #KisanCreditCard #SBI',
    dirURL: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800',
    impression: 56789,
    views: 15678,
  },
  {
    title: 'Jain Drip Irrigation',
    content: '💧 Save water, increase yield! Drip irrigation - 60% water saving, 40% more production। Government subsidy 55%। Free installation। #DripIrrigation #WaterSaving',
    dirURL: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
    impression: 23456,
    views: 7890,
  },
  {
    title: 'IFFCO Nano Urea',
    content: '🌱 1 bottle = 1 bag urea! IFFCO Nano Urea - 40% cost saving, better absorption। Available at all cooperative stores। #NanoUrea #IFFCO',
    dirURL: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800',
    impression: 67890,
    views: 23456,
  },
  {
    title: 'Swaraj Tractors',
    content: '🚜 Swaraj 744 FE - Built for Indian farms! 48 HP, fuel efficient, powerful। Exchange bonus ₹50,000। 0% down payment finance। #Swaraj #Tractor',
    dirURL: 'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=800',
    impression: 34567,
    views: 11234,
  },
  {
    title: 'UPL Saaf Fungicide',
    content: '🍃 Complete disease control! Saaf - Best fungicide for rice, wheat, vegetables। Controls blast, blight, rust। Buy online - free delivery। #UPL #Fungicide',
    dirURL: 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=800',
    impression: 28765,
    views: 8901,
  },
  {
    title: 'Rallis Tata Manik',
    content: '🐛 Say goodbye to pests! Tata Manik - Powerful insecticide for cotton, rice, vegetables। Long lasting protection। Trusted by millions। #TataRallis #PestControl',
    dirURL: 'https://images.unsplash.com/photo-1599719500956-d158a26ab3ee?w=800',
    impression: 19876,
    views: 6543,
  },
  {
    title: 'HDFC Kisan Gold',
    content: '🏦 Flexible farm credit! HDFC Kisan Gold Card - Loan up to ₹10 Lakh। Interest from 7%। Insurance included। Apply in 5 minutes। #HDFC #FarmLoan',
    dirURL: 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800',
    impression: 41234,
    views: 13456,
  },
  {
    title: 'Sonalika Tractors',
    content: '🚜 Sonalika DI 745 III - Power packed performance! 50 HP, hydraulic system, AC cabin option। Best price guarantee। #Sonalika #Tractor',
    dirURL: 'https://images.unsplash.com/photo-1591086517675-d4f4c5e96d83?w=800',
    impression: 25678,
    views: 8765,
  },
  {
    title: 'Dhanuka Agritech',
    content: '🌾 Targa Super - Best weed killer! Selective herbicide for soybean, cotton, groundnut। Kills grassy weeds, safe for crops। #Dhanuka #Herbicide',
    dirURL: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=800',
    impression: 15678,
    views: 5432,
  },
  {
    title: 'Netafim Irrigation',
    content: '💧 Precision irrigation solutions! Netafim - World leader in drip technology। Increase yield by 50%। Expert support। #Netafim #SmartFarming',
    dirURL: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
    impression: 18765,
    views: 6234,
  },
  {
    title: 'Krishi Mantra Premium',
    content: '⭐ Upgrade to Premium! Unlimited expert consultations, AI crop doctor, priority support। First week FREE। Try now! #KrishiMantra #Premium',
    dirURL: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=800',
    impression: 78901,
    views: 34567,
  },
  {
    title: 'PI Industries',
    content: '🧪 Nominee Gold - Ultimate rice herbicide! Controls all weeds in paddy। One spray, complete solution। #PIIndustries #RiceFarming',
    dirURL: 'https://images.unsplash.com/photo-1536054024090-c2df1bd15e79?w=800',
    impression: 21345,
    views: 7654,
  },
  {
    title: 'Godrej Agrovet',
    content: '🐄 Best cattle feed! Godrej Agrovet - Increase milk production by 20%। Balanced nutrition, healthy animals। #GodrejAgrovet #DairyFarming',
    dirURL: 'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800',
    impression: 29876,
    views: 9012,
  },
];

// ============================================
// REEL ADS DATA - Video Ads
// ============================================
// Using W3Schools sample videos that work on iOS
const adVideoUrls = [
  'https://www.w3schools.com/html/mov_bbb.mp4',
  'https://www.w3schools.com/html/movie.mp4',
];

const reelAdsData = [
  {
    title: 'Mahindra Tractors - Power Demo',
    videoUrl: adVideoUrls[0],
    popUpView: {
      enabled: true,
      type: 'marketplace',
      image: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=400',
      popupTitle: 'Book Free Demo - Mahindra 575 DI',
    },
    impressions: 125678,
    views: 45678,
  },
  {
    title: 'Bayer - Crop Protection Tips',
    videoUrl: adVideoUrls[1],
    popUpView: {
      enabled: true,
      type: 'posts',
      image: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=400',
      popupTitle: 'Shop Bayer Products - 20% Off',
    },
    impressions: 98765,
    views: 34567,
  },
  {
    title: 'Jain Irrigation - Installation Guide',
    videoUrl: adVideoUrls[0],
    popUpView: {
      enabled: true,
      type: 'posts',
      image: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
      popupTitle: 'Get Free Survey - Drip System',
    },
    impressions: 67890,
    views: 23456,
  },
  {
    title: 'SBI KCC - Easy Application',
    videoUrl: adVideoUrls[1],
    popUpView: {
      enabled: true,
      type: 'posts',
      image: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400',
      popupTitle: 'Apply KCC Online Now',
    },
    impressions: 156789,
    views: 56789,
  },
  {
    title: 'IFFCO Nano Urea - How to Use',
    videoUrl: adVideoUrls[0],
    popUpView: {
      enabled: true,
      type: 'posts',
      image: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=400',
      popupTitle: 'Order Nano Urea Now',
    },
    impressions: 234567,
    views: 89012,
  },
  {
    title: 'Swaraj Tractors - Farmer Story',
    videoUrl: adVideoUrls[1],
    popUpView: {
      enabled: true,
      type: 'marketplace',
      image: 'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=400',
      popupTitle: 'Book Test Drive - Swaraj',
    },
    impressions: 87654,
    views: 32109,
  },
  {
    title: 'UPL - Pest Identification',
    videoUrl: adVideoUrls[0],
    popUpView: {
      enabled: true,
      type: 'posts',
      image: 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=400',
      popupTitle: 'Shop UPL Products',
    },
    impressions: 54321,
    views: 19876,
  },
  {
    title: 'PM-KISAN eKYC Tutorial',
    videoUrl: adVideoUrls[1],
    popUpView: {
      enabled: false,
    },
    impressions: 345678,
    views: 123456,
  },
  {
    title: 'Krishi Mantra Premium Features',
    videoUrl: adVideoUrls[0],
    popUpView: {
      enabled: true,
      type: 'posts',
      image: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=400',
      popupTitle: 'Try Premium Free for 7 Days',
    },
    impressions: 198765,
    views: 76543,
  },
  {
    title: 'Sonalika - Harvest Season',
    videoUrl: adVideoUrls[1],
    popUpView: {
      enabled: true,
      type: 'marketplace',
      image: 'https://images.unsplash.com/photo-1591086517675-d4f4c5e96d83?w=400',
      popupTitle: 'Sonalika Tractors - Best Price',
    },
    impressions: 65432,
    views: 24567,
  },
];

// ============================================
// NEWS ADS DATA - News Section Ads
// ============================================
const newsAdsData = [
  {
    title: 'Agri News Sponsor - Mahindra',
    content: 'Mahindra Farm Equipment - Empowering Indian Farmers since 1963। Tractors, Implements, Services। Visit mahindratractor.com',
    dirURL: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800',
    impression: 78901,
    views: 23456,
  },
  {
    title: 'Weather Sponsor - Skymet',
    content: 'Accurate weather forecasts for farmers। Skymet - India\'s leading weather company। Download app for hyperlocal updates।',
    dirURL: 'https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=800',
    impression: 56789,
    views: 18765,
  },
  {
    title: 'Market Prices - NCDEX',
    content: 'Trade agricultural commodities। NCDEX - Transparent price discovery। Hedge your crop risk। Start trading today।',
    dirURL: 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800',
    impression: 34567,
    views: 12345,
  },
  {
    title: 'Govt Scheme - PM Fasal Bima',
    content: 'Protect your crops at nominal premium। PMFBY - Comprehensive crop insurance। Apply before deadline। 100% claim settlement।',
    dirURL: 'https://images.unsplash.com/photo-1560493676-04071c5f467b?w=800',
    impression: 89012,
    views: 34567,
  },
  {
    title: 'Agri Finance - Samunnati',
    content: 'Collateral-free loans for farmers। Samunnati - Supporting 5 lakh+ farmers। Quick disbursement, flexible repayment।',
    dirURL: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800',
    impression: 45678,
    views: 15678,
  },
  {
    title: 'Organic Certification - APEDA',
    content: 'Get organic certification for your farm। APEDA approved agencies। Premium prices for organic produce। Export opportunity।',
    dirURL: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800',
    impression: 23456,
    views: 8901,
  },
  {
    title: 'FPO Registration - NABARD',
    content: 'Form Farmer Producer Organization। NABARD support available। Collective bargaining power। Better market access।',
    dirURL: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=800',
    impression: 34567,
    views: 11234,
  },
  {
    title: 'Soil Testing - Govt Labs',
    content: 'Free soil testing at Krishi Vigyan Kendras। Get fertilizer recommendations। Improve soil health। Increase yield।',
    dirURL: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
    impression: 67890,
    views: 21234,
  },
  {
    title: 'Agri Startup - AgriBazaar',
    content: 'Sell directly to buyers। AgriBazaar - Digital mandi platform। Better prices, instant payment। No middlemen।',
    dirURL: 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=800',
    impression: 54321,
    views: 17654,
  },
  {
    title: 'Insurance - ICICI Lombard',
    content: 'Comprehensive farm insurance। ICICI Lombard - Equipment, livestock, crop coverage। Easy claim process। 24/7 support।',
    dirURL: 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=800',
    impression: 41234,
    views: 14567,
  },
];

// ============================================
// MAIN SEED FUNCTION
// ============================================
async function seedAdsData() {
  try {
    const mongoUrl = process.env.MONGODB_URL;
    if (!mongoUrl) {
      throw new Error('MONGODB_URL environment variable is not set');
    }

    console.log('🌱 Connecting to MongoDB...');
    await mongoose.connect(mongoUrl);
    console.log('✅ Connected to MongoDB');

    // Clear existing ads data
    console.log('\n🗑️  Clearing existing ads data...');
    await Promise.all([
      HomeScreenAds.deleteMany({}),
      HomeSlider.deleteMany({}),
      SplashModal.deleteMany({}),
      FeedAds.deleteMany({}),
      ReelAds.deleteMany({}),
      NewsAds.deleteMany({}),
    ]);
    console.log('✅ Existing ads data cleared');

    // 1. Create Home Sliders
    console.log('\n🖼️  Creating home sliders...');
    const createdSliders = await HomeSlider.insertMany(homeSlidersData);
    console.log(`✅ Created ${createdSliders.length} home sliders`);

    // 2. Create Home Screen Ads
    console.log('\n📢 Creating home screen ads...');
    const createdHomeAds = await HomeScreenAds.insertMany(homeScreenAdsData);
    console.log(`✅ Created ${createdHomeAds.length} home screen ads`);

    // 3. Create Splash Modals
    console.log('\n🎯 Creating splash modals...');
    const createdSplash = await SplashModal.insertMany(splashModalsData);
    console.log(`✅ Created ${createdSplash.length} splash modals`);

    // 4. Create Feed Ads
    console.log('\n📝 Creating feed ads...');
    const feedAdsToCreate = feedAdsData.map(ad => ({
      ...ad,
      createdAt: new Date().toISOString(),
    }));
    const createdFeedAds = await FeedAds.insertMany(feedAdsToCreate);
    console.log(`✅ Created ${createdFeedAds.length} feed ads`);

    // 5. Create Reel Ads
    console.log('\n🎬 Creating reel ads...');
    // Get a marketplace product for linking (if exists)
    const marketplaceProduct = await MarketplaceProduct.findOne();

    const reelAdsToCreate = reelAdsData.map(ad => {
      const adData = {
        title: ad.title,
        videoUrl: ad.videoUrl,
        impressions: ad.impressions,
        views: ad.views,
        viewTracking: [],
        createdAt: new Date(),
      };

      if (ad.popUpView.enabled) {
        adData.popUpView = {
          enabled: true,
          type: ad.popUpView.type,
          image: ad.popUpView.image,
          popupTitle: ad.popUpView.popupTitle,
        };
        if (marketplaceProduct && ad.popUpView.type === 'marketplace') {
          adData.popUpView.productId = marketplaceProduct._id;
        }
      } else {
        adData.popUpView = { enabled: false };
      }

      return adData;
    });
    const createdReelAds = await ReelAds.insertMany(reelAdsToCreate);
    console.log(`✅ Created ${createdReelAds.length} reel ads`);

    // 6. Create News Ads
    console.log('\n📰 Creating news ads...');
    const newsAdsToCreate = newsAdsData.map(ad => ({
      ...ad,
      createdAt: new Date().toISOString(),
    }));
    const createdNewsAds = await NewsAds.insertMany(newsAdsToCreate);
    console.log(`✅ Created ${createdNewsAds.length} news ads`);

    // 7. Update UI Display settings
    console.log('\n⚙️  Updating UI display settings...');
    await UIDisplay.findOneAndUpdate(
      {},
      {
        Slider: true,
        SplashSreen: true,
        HomeScreenAdOne: true,
        HomeScreenAdTwo: true,
        HomeScreenAdThree: true,
        HomeScreenAdFour: true,
        FeedAds: true,
        ReelAds: true,
        NewsAds: true,
      },
      { upsert: true }
    );
    console.log('✅ UI display settings updated');

    // Summary
    console.log('\n' + '='.repeat(50));
    console.log('🎉 ADS DATA SEEDING COMPLETE!');
    console.log('='.repeat(50));
    console.log(`
📊 Summary:
   - Home Sliders: ${createdSliders.length}
   - Home Screen Ads: ${createdHomeAds.length}
   - Splash Modals: ${createdSplash.length}
   - Feed Ads: ${createdFeedAds.length}
   - Reel Ads: ${createdReelAds.length}
   - News Ads: ${createdNewsAds.length}

📍 Ad Placements:
   - Home Screen: Carousel banners + Native ads
   - Feed: In-feed native ads (every 5th post)
   - Reels: Video ads with popup CTAs
   - News: Sponsored content ads
   - Splash: App open modals/promotions
    `);

    await mongoose.connection.close();
    console.log('✅ Database connection closed');
    process.exit(0);

  } catch (error) {
    console.error('❌ Error seeding ads data:', error);
    process.exit(1);
  }
}

// Run the seed function
seedAdsData();
