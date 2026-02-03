/**
 * Krishi-Mantra Complete Seed Data Script
 * Adds realistic Indian farming data across all collections
 *
 * Usage: node src/scripts/seedData.js
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../../.env.development') });
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

// Models - Main Service
const User = require('../model/User');
const UserDetail = require('../model/UserDetail');
const Company = require('../model/Company');
const Products = require('../model/Products');
const News = require('../model/News');
const Scheme = require('../model/Scheme');
const Services = require('../model/Services');
const Testimonial = require('../model/Testinomial');
const MarketplaceProduct = require('../model/MarketplaceProduct');

// Crop Calendar Models
const Crop = require('../model/CropCalendar/Crop');
const Activity = require('../model/CropCalendar/Activity');
const CropCalendar = require('../model/CropCalendar/CropCalendar');
const Region = require('../model/CropCalendar/Region');

// UI Models
const HomeScreenAds = require('../model/UIModel/HomeScreen/HomeScreenAd');
const HomeSlider = require('../model/UIModel/HomeScreen/HomeSliderModel');
const SplashModal = require('../model/UIModel/HomeScreen/SplashModel');
const FeedAds = require('../model/UIModel/FeedScreen/FeedAds');
const ReelAds = require('../model/UIModel/FeedScreen/ReelAds');
const NewsAds = require('../model/UIModel/NewsScreen/NewsAds');
const UIDisplay = require('../model/UIModel/UIDisplay');

// ============================================
// USERS DATA - 10 Realistic Indian Farmers
// ============================================
const usersData = [
  {
    name: 'Ramesh Kumar Patel',
    firstName: 'Ramesh',
    lastName: 'Patel',
    email: 'ramesh.patel@gmail.com',
    phoneNo: 9876543210,
    accountType: 'user',
    image: 'https://randomuser.me/api/portraits/men/1.jpg',
    isActive: true,
    details: {
      address: 'Village Bhilwara, Dist. Rajkot, Gujarat',
      location: { type: 'Point', coordinates: [70.8022, 22.3039] },
      interests: ['organic farming', 'cotton', 'groundnut', 'drip irrigation'],
      experience: 15,
      rating: 4.5,
    },
  },
  {
    name: 'Sunita Devi',
    firstName: 'Sunita',
    lastName: 'Devi',
    email: 'sunita.devi@gmail.com',
    phoneNo: 9876543211,
    accountType: 'user',
    image: 'https://randomuser.me/api/portraits/women/2.jpg',
    isActive: true,
    details: {
      address: 'Village Nangal, Dist. Ludhiana, Punjab',
      location: { type: 'Point', coordinates: [75.8573, 30.9010] },
      interests: ['wheat', 'rice', 'dairy farming', 'tractor'],
      experience: 12,
      rating: 4.3,
    },
  },
  {
    name: 'Venkatesh Reddy',
    firstName: 'Venkatesh',
    lastName: 'Reddy',
    email: 'venkatesh.reddy@gmail.com',
    phoneNo: 9876543212,
    accountType: 'consultant',
    image: 'https://randomuser.me/api/portraits/men/3.jpg',
    isActive: true,
    details: {
      address: 'Village Mancherial, Dist. Hyderabad, Telangana',
      location: { type: 'Point', coordinates: [78.4867, 17.3850] },
      interests: ['chili', 'turmeric', 'sustainable farming', 'soil health'],
      experience: 20,
      rating: 4.8,
    },
  },
  {
    name: 'Mahendra Singh Yadav',
    firstName: 'Mahendra',
    lastName: 'Yadav',
    email: 'mahendra.yadav@gmail.com',
    phoneNo: 9876543213,
    accountType: 'user',
    image: 'https://randomuser.me/api/portraits/men/4.jpg',
    isActive: true,
    details: {
      address: 'Village Barabanki, Dist. Lucknow, Uttar Pradesh',
      location: { type: 'Point', coordinates: [81.1857, 26.9260] },
      interests: ['sugarcane', 'potato', 'wheat', 'sprinkler irrigation'],
      experience: 18,
      rating: 4.2,
    },
  },
  {
    name: 'Lakshmi Narayanan',
    firstName: 'Lakshmi',
    lastName: 'Narayanan',
    email: 'lakshmi.narayanan@gmail.com',
    phoneNo: 9876543214,
    accountType: 'user',
    image: 'https://randomuser.me/api/portraits/women/5.jpg',
    isActive: true,
    details: {
      address: 'Village Thanjavur, Dist. Thanjavur, Tamil Nadu',
      location: { type: 'Point', coordinates: [79.1378, 10.7870] },
      interests: ['paddy', 'banana', 'coconut', 'organic manure'],
      experience: 25,
      rating: 4.7,
    },
  },
  {
    name: 'Balwinder Singh',
    firstName: 'Balwinder',
    lastName: 'Singh',
    email: 'balwinder.singh@gmail.com',
    phoneNo: 9876543215,
    accountType: 'marketplace',
    image: 'https://randomuser.me/api/portraits/men/6.jpg',
    isActive: true,
    details: {
      address: 'Village Patiala, Dist. Patiala, Punjab',
      location: { type: 'Point', coordinates: [76.3869, 30.3398] },
      interests: ['tractor sales', 'agricultural equipment', 'combine harvester'],
      experience: 10,
      rating: 4.4,
    },
  },
  {
    name: 'Anita Sharma',
    firstName: 'Anita',
    lastName: 'Sharma',
    email: 'anita.sharma@gmail.com',
    phoneNo: 9876543216,
    accountType: 'user',
    image: 'https://randomuser.me/api/portraits/women/7.jpg',
    isActive: true,
    details: {
      address: 'Village Indore, Dist. Indore, Madhya Pradesh',
      location: { type: 'Point', coordinates: [75.8577, 22.7196] },
      interests: ['soybean', 'garlic', 'onion', 'vermicompost'],
      experience: 8,
      rating: 4.1,
    },
  },
  {
    name: 'Prakash Chandra Joshi',
    firstName: 'Prakash',
    lastName: 'Joshi',
    email: 'prakash.joshi@gmail.com',
    phoneNo: 9876543217,
    accountType: 'consultant',
    image: 'https://randomuser.me/api/portraits/men/8.jpg',
    isActive: true,
    details: {
      address: 'Village Dehradun, Dist. Dehradun, Uttarakhand',
      location: { type: 'Point', coordinates: [78.0322, 30.3165] },
      interests: ['apple', 'litchi', 'hill farming', 'polyhouse'],
      experience: 22,
      rating: 4.9,
    },
  },
  {
    name: 'Meera Bai',
    firstName: 'Meera',
    lastName: 'Bai',
    email: 'meera.bai@gmail.com',
    phoneNo: 9876543218,
    accountType: 'user',
    image: 'https://randomuser.me/api/portraits/women/9.jpg',
    isActive: true,
    details: {
      address: 'Village Jodhpur, Dist. Jodhpur, Rajasthan',
      location: { type: 'Point', coordinates: [73.0243, 26.2389] },
      interests: ['bajra', 'guar', 'cumin', 'desert farming'],
      experience: 14,
      rating: 4.3,
    },
  },
  {
    name: 'Govind Das',
    firstName: 'Govind',
    lastName: 'Das',
    email: 'govind.das@gmail.com',
    phoneNo: 9876543219,
    accountType: 'admin',
    image: 'https://randomuser.me/api/portraits/men/10.jpg',
    isActive: true,
    details: {
      address: 'Village Kolkata, Dist. Kolkata, West Bengal',
      location: { type: 'Point', coordinates: [88.3639, 22.5726] },
      interests: ['rice', 'jute', 'tea', 'fish farming'],
      experience: 30,
      rating: 4.6,
    },
  },
];

// ============================================
// COMPANIES DATA - Real Agri Companies
// Using reliable placeholder images for company logos
// ============================================
const companiesData = [
  {
    name: 'Bayer CropScience India',
    email: 'contact@bayer.in',
    address: {
      street: 'Bayer House, Central Avenue',
      city: 'Mumbai',
      state: 'Maharashtra',
      zip: '400051',
    },
    phone: '912225311234',
    website: 'https://www.bayer.in',
    description: 'Bayer CropScience is a global leader in crop protection and seeds, providing innovative solutions for sustainable agriculture. Offers pesticides, herbicides, and high-yielding hybrid seeds for Indian farmers.',
    logo: 'https://images.unsplash.com/photo-1560493676-04071c5f467b?w=200',
    rating: 4.5,
    reviews: [],
  },
  {
    name: 'UPL Limited',
    email: 'info@upl-ltd.com',
    address: {
      street: 'UPL House, 610 B Wing',
      city: 'Mumbai',
      state: 'Maharashtra',
      zip: '400018',
    },
    phone: '9122663800',
    website: 'https://www.upl-ltd.com',
    description: 'UPL is a leading global producer of sustainable agriculture products including crop protection chemicals, seeds, and post-harvest solutions. Focused on natural farming solutions.',
    logo: 'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=200',
    rating: 4.3,
    reviews: [],
  },
  {
    name: 'Tata Rallis India',
    email: 'contact@rallis.co.in',
    address: {
      street: '156/157 Nariman Bhavan',
      city: 'Mumbai',
      state: 'Maharashtra',
      zip: '400021',
    },
    phone: '9122666582',
    website: 'https://www.rallis.com',
    description: 'Rallis India Limited is a Tata Enterprise company providing crop care solutions including pesticides, fungicides, and plant growth nutrients. Pioneer in Indian agrochemical industry since 1854.',
    logo: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=200',
    rating: 4.4,
    reviews: [],
  },
  {
    name: 'Mahindra Agri Solutions',
    email: 'agri.solutions@mahindra.com',
    address: {
      street: 'Mahindra Towers, Worli',
      city: 'Mumbai',
      state: 'Maharashtra',
      zip: '400018',
    },
    phone: '9122249014',
    website: 'https://www.mahindraagri.com',
    description: 'Mahindra Agri Solutions provides end-to-end farming solutions including seeds, crop nutrition, crop protection, and farm mechanization. Part of Mahindra Group.',
    logo: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=200',
    rating: 4.6,
    reviews: [],
  },
  {
    name: 'Coromandel International',
    email: 'info@coromandel.murugappa.com',
    address: {
      street: 'Coromandel House, Sardar Patel Road',
      city: 'Secunderabad',
      state: 'Telangana',
      zip: '500003',
    },
    phone: '9140278420',
    website: 'https://www.coromandel.biz',
    description: 'Coromandel International is India\'s leading agri solutions company offering fertilizers, crop protection, specialty nutrients, and organic products under brands like Gromor and Mancozeb.',
    logo: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=200',
    rating: 4.2,
    reviews: [],
  },
  {
    name: 'IFFCO (Indian Farmers Fertiliser Cooperative)',
    email: 'contact@iffco.in',
    address: {
      street: 'IFFCO Sadan, C-1 District Centre',
      city: 'New Delhi',
      state: 'Delhi',
      zip: '110058',
    },
    phone: '9111265920',
    website: 'https://www.iffco.in',
    description: 'IFFCO is India\'s largest fertilizer cooperative manufacturing and marketing fertilizers including Urea, DAP, NPK, and specialty fertilizers for Indian farmers.',
    logo: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=200',
    rating: 4.7,
    reviews: [],
  },
  {
    name: 'Syngenta India',
    email: 'india.info@syngenta.com',
    address: {
      street: 'Amar Paradigm, IT Park',
      city: 'Pune',
      state: 'Maharashtra',
      zip: '411014',
    },
    phone: '9120666881',
    website: 'https://www.syngenta.co.in',
    description: 'Syngenta is a global agribusiness company providing seeds, crop protection, and digital solutions. Known for high-quality vegetable seeds and innovative crop protection products.',
    logo: 'https://images.unsplash.com/photo-1592982537447-7440770cbfc9?w=200',
    rating: 4.4,
    reviews: [],
  },
  {
    name: 'Dhanuka Agritech',
    email: 'info@dhanukaagritech.com',
    address: {
      street: '1st Floor, 14th Floor, Building 5A',
      city: 'Gurugram',
      state: 'Haryana',
      zip: '122002',
    },
    phone: '9112440340',
    website: 'https://www.dhanuka.com',
    description: 'Dhanuka Agritech is a leading Indian agrochemical company manufacturing insecticides, fungicides, herbicides, and plant growth regulators for sustainable crop protection.',
    logo: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=200',
    rating: 4.1,
    reviews: [],
  },
];

// ============================================
// PRODUCTS DATA - Real Agricultural Products
// Using reliable Unsplash images for product placeholders
// ============================================
const productsData = [
  {
    name: 'Confidor (Imidacloprid 17.8% SL)',
    image: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
    usage: 'Systemic insecticide for controlling sucking pests like aphids, jassids, whiteflies, and thrips in cotton, rice, and vegetables. Apply 100ml per acre mixed with 200L water.',
    companyIndex: 0, // Bayer
    cropIndex: 0, // Will link to wheat
  },
  {
    name: 'Saaf (Carbendazim 12% + Mancozeb 63% WP)',
    image: 'https://images.unsplash.com/photo-1585314062340-f1a5a7c9328d?w=400',
    usage: 'Combination fungicide for control of blast, sheath blight in rice, leaf spot in groundnut, and various fungal diseases. Use 500g per acre.',
    companyIndex: 1, // UPL
    cropIndex: 1, // Rice
  },
  {
    name: 'Tata Manik (Chlorpyrifos 20% EC)',
    image: 'https://images.unsplash.com/photo-1563514227147-6d2ff665a6a0?w=400',
    usage: 'Broad spectrum insecticide for control of termites, soil insects, caterpillars, and stem borers. Effective in cotton, rice, sugarcane, and vegetables.',
    companyIndex: 2, // Rallis
    cropIndex: 2, // Cotton
  },
  {
    name: 'Gromor 14-35-14',
    image: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=400',
    usage: 'Water soluble fertilizer for flowering and fruit setting stage. Rich in phosphorus for root development and flower induction. Apply through drip or foliar spray.',
    companyIndex: 4, // Coromandel
    cropIndex: 3, // Tomato
  },
  {
    name: 'IFFCO Nano Urea',
    image: 'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=400',
    usage: 'Revolutionary liquid nano fertilizer replacing conventional urea. One 500ml bottle equals one bag of urea. Spray 2-4ml per liter of water at critical growth stages.',
    companyIndex: 5, // IFFCO
    cropIndex: 0, // Wheat
  },
  {
    name: 'Cruiser (Thiamethoxam 30% FS)',
    image: 'https://images.unsplash.com/photo-1500595046743-cd271d694d30?w=400',
    usage: 'Seed treatment insecticide providing protection against early season pests. Treats seeds before sowing for protection up to 45 days. Use 3ml per kg seed.',
    companyIndex: 6, // Syngenta
    cropIndex: 4, // Soybean
  },
  {
    name: 'Areva (Thiamethoxam 25% WG)',
    image: 'https://images.unsplash.com/photo-1592982537447-7440770cbfc9?w=400',
    usage: 'Systemic insecticide for controlling jassids, aphids, and whiteflies. Unique translaminar action provides quick knockdown. Use 40g per acre.',
    companyIndex: 6, // Syngenta
    cropIndex: 2, // Cotton
  },
  {
    name: 'Targa Super (Quizalofop Ethyl 5% EC)',
    image: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=400',
    usage: 'Selective herbicide for control of grassy weeds in soybean, cotton, groundnut, and pulses. Apply 400ml per acre at 2-4 leaf stage of weeds.',
    companyIndex: 7, // Dhanuka
    cropIndex: 4, // Soybean
  },
];

// ============================================
// CROPS DATA - Major Indian Crops
// ============================================
const cropsData = [
  {
    name: 'Wheat',
    scientificName: 'Triticum aestivum',
    description: 'Wheat is the most important rabi crop in India, mainly grown in Punjab, Haryana, UP, MP, and Rajasthan. India is the second largest wheat producer globally.',
    growingPeriod: 120,
    seasons: [{ type: 'Rabi', startMonth: 10, endMonth: 3 }],
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Vehnäpelto_6.jpg/1200px-Vehnäpelto_6.jpg',
    status: 'active',
  },
  {
    name: 'Rice (Paddy)',
    scientificName: 'Oryza sativa',
    description: 'Rice is the staple food crop of India, primarily grown during Kharif season in West Bengal, UP, Punjab, Andhra Pradesh, and Tamil Nadu. Requires abundant water.',
    growingPeriod: 150,
    seasons: [{ type: 'Kharif', startMonth: 6, endMonth: 11 }],
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/61/Mature_rice_%28India%29_by_Augustus_Binu.jpg/1200px-Mature_rice_%28India%29_by_Augustus_Binu.jpg',
    status: 'active',
  },
  {
    name: 'Cotton',
    scientificName: 'Gossypium hirsutum',
    description: 'Cotton is the most important fiber crop in India, known as white gold. Major producing states include Gujarat, Maharashtra, Telangana, and Punjab.',
    growingPeriod: 180,
    seasons: [{ type: 'Kharif', startMonth: 5, endMonth: 12 }],
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/55/GreenCottonBowl.jpg/1200px-GreenCottonBowl.jpg',
    status: 'active',
  },
  {
    name: 'Tomato',
    scientificName: 'Solanum lycopersicum',
    description: 'Tomato is a major vegetable crop grown throughout India in all three seasons. Maharashtra, Karnataka, MP, and Andhra Pradesh are leading producers.',
    growingPeriod: 90,
    seasons: [
      { type: 'Kharif', startMonth: 6, endMonth: 9 },
      { type: 'Rabi', startMonth: 10, endMonth: 2 },
      { type: 'Zaid', startMonth: 3, endMonth: 5 },
    ],
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/89/Tomato_je.jpg/1200px-Tomato_je.jpg',
    status: 'active',
  },
  {
    name: 'Soybean',
    scientificName: 'Glycine max',
    description: 'Soybean is the leading oilseed crop in India, primarily grown in Madhya Pradesh, Maharashtra, and Rajasthan. Rich in protein and used for oil extraction.',
    growingPeriod: 100,
    seasons: [{ type: 'Kharif', startMonth: 6, endMonth: 10 }],
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Soybean.USDA.jpg/1200px-Soybean.USDA.jpg',
    status: 'active',
  },
  {
    name: 'Sugarcane',
    scientificName: 'Saccharum officinarum',
    description: 'Sugarcane is a major cash crop in India, with UP, Maharashtra, Karnataka, and Tamil Nadu being top producers. Used for sugar and ethanol production.',
    growingPeriod: 365,
    seasons: [
      { type: 'Kharif', startMonth: 7, endMonth: 8 },
      { type: 'Zaid', startMonth: 2, endMonth: 3 },
    ],
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Sugarcane_in_Mauritius.jpg/1200px-Sugarcane_in_Mauritius.jpg',
    status: 'active',
  },
  {
    name: 'Mustard',
    scientificName: 'Brassica juncea',
    description: 'Mustard is an important rabi oilseed crop grown mainly in Rajasthan, UP, Haryana, and MP. Seeds are used for oil extraction and as spice.',
    growingPeriod: 110,
    seasons: [{ type: 'Rabi', startMonth: 10, endMonth: 2 }],
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Brassica_juncea_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-168.jpg/800px-Brassica_juncea_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-168.jpg',
    status: 'active',
  },
  {
    name: 'Gram (Chickpea)',
    scientificName: 'Cicer arietinum',
    description: 'Gram or Chickpea is the most important pulse crop in India. Madhya Pradesh, Rajasthan, Maharashtra, and UP are major producing states. Rich in protein.',
    growingPeriod: 100,
    seasons: [{ type: 'Rabi', startMonth: 10, endMonth: 2 }],
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Sa-chickpea.jpg/1200px-Sa-chickpea.jpg',
    status: 'active',
  },
];

// ============================================
// ACTIVITIES DATA - Farming Activities
// ============================================
const activitiesData = [
  {
    name: 'Land Preparation',
    description: 'Plowing, leveling, and preparing the field for sowing. Includes removing weeds and previous crop residues.',
    category: 'Pre-planting',
    requiredTools: ['Tractor', 'Cultivator', 'Rotavator', 'Leveler'],
    precautions: ['Check soil moisture before plowing', 'Ensure proper depth of plowing', 'Remove large stones and debris'],
    status: 'active',
  },
  {
    name: 'Seed Treatment',
    description: 'Treating seeds with fungicides and insecticides before sowing to protect from soil-borne diseases and pests.',
    category: 'Pre-planting',
    requiredTools: ['Seed treating drum', 'Measuring cups', 'Protective gloves'],
    precautions: ['Use recommended dose only', 'Wear protective gear', 'Dry seeds in shade after treatment'],
    status: 'active',
  },
  {
    name: 'Sowing',
    description: 'Planting seeds at recommended depth and spacing using appropriate method - broadcasting, dibbling, or seed drill.',
    category: 'Planting',
    requiredTools: ['Seed drill', 'Dibbler', 'Planter'],
    precautions: ['Check seed germination percentage', 'Maintain proper row spacing', 'Ensure optimal soil moisture'],
    status: 'active',
  },
  {
    name: 'Irrigation',
    description: 'Providing water to crops at critical growth stages through flood, drip, or sprinkler irrigation methods.',
    category: 'Growth Management',
    requiredTools: ['Drip system', 'Sprinklers', 'Water pump', 'Pipes'],
    precautions: ['Avoid over-irrigation', 'Irrigate during early morning or evening', 'Check for clogging in drip system'],
    status: 'active',
  },
  {
    name: 'Fertilizer Application',
    description: 'Applying organic and inorganic fertilizers based on soil test recommendations and crop requirements.',
    category: 'Fertilization',
    requiredTools: ['Fertilizer spreader', 'Measuring equipment', 'Fertiigation unit'],
    precautions: ['Apply based on soil test', 'Avoid direct contact with seeds', 'Split doses for better efficiency'],
    status: 'active',
  },
  {
    name: 'Weeding',
    description: 'Removing unwanted plants that compete with crops for nutrients, water, and sunlight.',
    category: 'Maintenance',
    requiredTools: ['Khurpi', 'Hoe', 'Power weeder', 'Herbicide sprayer'],
    precautions: ['Weed at right stage', 'Avoid disturbing crop roots', 'Dispose weeds properly'],
    status: 'active',
  },
  {
    name: 'Pest Control',
    description: 'Monitoring and controlling insect pests using IPM practices, biological agents, or chemical pesticides.',
    category: 'Pest Control',
    requiredTools: ['Sprayer', 'Pheromone traps', 'Light traps', 'PPE kit'],
    precautions: ['Identify pest correctly', 'Use recommended doses', 'Follow waiting period before harvest'],
    status: 'active',
  },
  {
    name: 'Harvesting',
    description: 'Collecting mature crops at optimal stage for maximum yield and quality. Can be manual or mechanical.',
    category: 'Harvest',
    requiredTools: ['Sickle', 'Combine harvester', 'Thresher', 'Tarpaulin'],
    precautions: ['Harvest at right moisture', 'Avoid grain losses', 'Clean machinery before use'],
    status: 'active',
  },
];

// ============================================
// NEWS DATA - Real Farming News (Based on Current Information)
// ============================================
const newsData = [
  {
    content: 'Cabinet approves MSP hike for Rabi crops 2026-27! Wheat MSP increased to ₹2,585/quintal, Barley to ₹2,150, and Lentil to ₹7,000/quintal. This marks the highest percentage increase for barley at 8.58%. Farmers across India welcome the decision. #MSP #RabiCrops #किसान',
    image: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=800',
    tags: ['msp', 'wheat', 'rabi', 'government', 'किसान'],
    likes: 245,
    viewCount: 1520,
    isPublished: true,
  },
  {
    content: 'Madhya Pradesh launches "Farmer Welfare Year 2026" - CM Mohan Yadav announces wheat procurement at ₹2,600/quintal with plans to raise MSP to ₹2,700. MP becomes first state to dedicate entire year to farmer welfare. #MadhyaPradesh #FarmerWelfare',
    image: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=800',
    tags: ['madhya pradesh', 'farmer welfare', 'wheat', 'procurement'],
    likes: 189,
    viewCount: 980,
    isPublished: true,
  },
  {
    content: 'PM-KISAN scheme crosses 110 million farmer families! The direct benefit transfer program provides ₹6,000 annual support in three installments. Next installment due this month. Check your status at pmkisan.gov.in #PMKisan #DBT',
    image: 'https://images.unsplash.com/photo-1593113598332-cd288d649433?w=800',
    tags: ['pm kisan', 'dbt', 'government scheme', 'subsidy'],
    likes: 567,
    viewCount: 3200,
    isPublished: true,
  },
  {
    content: 'IFFCO Nano Urea revolutionizing Indian farming - One 500ml bottle equals one bag of conventional urea! 40% cost savings and better crop yield reported by farmers. Available at all cooperative stores. #NanoUrea #IFFCO #Innovation',
    image: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800',
    tags: ['nano urea', 'iffco', 'fertilizer', 'innovation'],
    likes: 334,
    viewCount: 1890,
    isPublished: true,
  },
  {
    content: 'Cotton prices surge to ₹24,915 per quintal in Rajkot market! Experts predict stable prices due to lower global production. Gujarat and Maharashtra farmers to benefit from favorable market conditions. #Cotton #MarketPrice #कपास',
    image: 'https://images.unsplash.com/photo-1599719500956-d158a26ab3ee?w=800',
    tags: ['cotton', 'market price', 'rajkot', 'gujarat'],
    likes: 212,
    viewCount: 1340,
    isPublished: true,
  },
  {
    content: 'Pradhan Mantri Fasal Bima Yojana achieves record enrollment - 4.19 crore farmers enrolled in 2024-25! Claims worth ₹2 lakh crore disbursed. New rule: 12% penalty for delayed payments from Kharif 2024. #PMFBY #CropInsurance',
    image: 'https://images.unsplash.com/photo-1560493676-04071c5f467b?w=800',
    tags: ['pmfby', 'crop insurance', 'fasal bima', 'government'],
    likes: 445,
    viewCount: 2560,
    isPublished: true,
  },
  {
    content: 'Organic farming boom in India! National Mission for Natural Farming certifies 50,000 farmers. Government promoting chemical-free agriculture with subsidies on bio-fertilizers and vermicompost units. #OrganicFarming #NaturalFarming',
    image: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800',
    tags: ['organic farming', 'natural farming', 'chemical free', 'sustainable'],
    likes: 398,
    viewCount: 2100,
    isPublished: true,
  },
  {
    content: 'Tomato prices drop to ₹15/kg in wholesale markets! Good monsoon and increased acreage leads to bumper production. Farmers advised to explore processing and cold storage options. #Tomato #VegetablePrice #टमाटर',
    image: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=800',
    tags: ['tomato', 'vegetable', 'market price', 'wholesale'],
    likes: 156,
    viewCount: 890,
    isPublished: true,
  },
  {
    content: 'New Kisan Credit Card scheme offers loans up to ₹1 lakh at 4-7% interest! Apply at any bank with land documents. Covers crop cultivation, dairy, poultry, and fisheries. #KCC #KisanCreditCard #FarmLoan',
    image: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800',
    tags: ['kisan credit card', 'farm loan', 'kcc', 'banking'],
    likes: 523,
    viewCount: 2890,
    isPublished: true,
  },
  {
    content: 'Weather Alert: IMD predicts good monsoon for 2026! Rainfall expected to be 102% of long period average. Farmers advised to prepare for Kharif sowing. Early varieties recommended for delayed monsoon regions. #Monsoon #IMD #मानसून',
    image: 'https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=800',
    tags: ['monsoon', 'weather', 'imd', 'kharif'],
    likes: 287,
    viewCount: 1560,
    isPublished: true,
  },
];

// ============================================
// GOVERNMENT SCHEMES DATA
// ============================================
const schemesData = [
  {
    title: 'Pradhan Mantri Kisan Samman Nidhi (PM-KISAN)',
    category: 'Income Support',
    description: 'Direct income support of ₹6,000 per year to all landholding farmer families, paid in three equal installments of ₹2,000 through DBT.',
    eligibility: [
      'All landholding farmer families',
      'Valid Aadhaar card',
      'Bank account linked with Aadhaar',
      'Land records in farmer\'s name',
    ],
    benefits: [
      '₹6,000 annual income support',
      'Direct transfer to bank account',
      'Three installments of ₹2,000 each',
      'No interest or repayment required',
    ],
    lastDate: 'Ongoing - No deadline',
    status: 'Active',
    applicationUrl: 'https://pmkisan.gov.in',
    documentRequired: ['Aadhaar Card', 'Bank Passbook', 'Land Records', 'Passport Photo'],
  },
  {
    title: 'Pradhan Mantri Fasal Bima Yojana (PMFBY)',
    category: 'Crop Insurance',
    description: 'Comprehensive crop insurance scheme covering yield losses due to natural calamities, pests, and diseases. Premium is only 2% for Kharif, 1.5% for Rabi crops.',
    eligibility: [
      'All farmers growing notified crops',
      'Both loanee and non-loanee farmers',
      'Sharecroppers and tenant farmers with land documents',
    ],
    benefits: [
      'Coverage against all natural risks',
      'Low premium - 2% Kharif, 1.5% Rabi',
      'Full sum insured claim payment',
      'Prevented sowing claims available',
      'Post-harvest losses covered for 14 days',
    ],
    lastDate: 'Before sowing season ends',
    status: 'Active',
    applicationUrl: 'https://pmfby.gov.in',
    documentRequired: ['Aadhaar Card', 'Bank Account', 'Land Records', 'Sowing Certificate'],
  },
  {
    title: 'Kisan Credit Card (KCC)',
    category: 'Credit/Loan',
    description: 'Flexible credit facility for farmers to meet cultivation expenses, post-harvest needs, and allied activities at subsidized interest rates.',
    eligibility: [
      'Owner cultivators',
      'Tenant farmers and sharecroppers',
      'Self Help Groups and Joint Liability Groups',
      'Farmers engaged in allied activities',
    ],
    benefits: [
      'Credit limit up to ₹3 lakh',
      'Interest rate 4-7% per annum',
      '2% interest subvention for timely repayment',
      'One-time documentation, multiple withdrawals',
      'Coverage for crop, dairy, fishery, and poultry',
    ],
    lastDate: 'Ongoing - Apply anytime',
    status: 'Active',
    applicationUrl: 'https://www.nabard.org',
    documentRequired: ['Aadhaar Card', 'PAN Card', 'Land Records', 'Passport Photo', 'Bank Statement'],
  },
  {
    title: 'Pradhan Mantri Krishi Sinchayee Yojana (PMKSY)',
    category: 'Irrigation',
    description: 'Scheme to expand cultivated area under irrigation, improve water use efficiency, and promote sustainable water conservation practices.',
    eligibility: [
      'All farmers with own land',
      'Farmers groups and cooperatives',
      'Preference to small and marginal farmers',
    ],
    benefits: [
      '55% subsidy for small farmers on micro-irrigation',
      '45% subsidy for other farmers',
      'Coverage for drip and sprinkler systems',
      'Support for water harvesting structures',
    ],
    lastDate: 'Ongoing',
    status: 'Active',
    applicationUrl: 'https://pmksy.gov.in',
    documentRequired: ['Aadhaar Card', 'Land Records', 'Bank Account', 'Quotation from vendor'],
  },
  {
    title: 'Soil Health Card Scheme',
    category: 'Soil Health',
    description: 'Scheme to issue soil health cards to farmers with crop-wise nutrient recommendations for improving soil fertility and productivity.',
    eligibility: [
      'All farmers',
      'No minimum land requirement',
      'Both individual and group applications accepted',
    ],
    benefits: [
      'Free soil testing',
      'Crop-wise fertilizer recommendations',
      'Information on soil type and nutrients',
      'Guidance for soil improvement',
    ],
    lastDate: 'Ongoing',
    status: 'Active',
    applicationUrl: 'https://soilhealth.dac.gov.in',
    documentRequired: ['Aadhaar Card', 'Land Details', 'Mobile Number'],
  },
  {
    title: 'PM Dhan Dhanya Krishi Yojana (PMDDKY)',
    category: 'Comprehensive Support',
    description: 'New flagship scheme merging 36 existing schemes to provide comprehensive support covering inputs, credit, storage, and capacity building.',
    eligibility: [
      'Small and marginal farmers with less than 2 hectares',
      'Priority to 100 low productivity districts',
      '1.7 crore target beneficiaries',
    ],
    benefits: [
      'Subsidies on hybrid seeds and bio-fertilizers',
      'Credit access ₹50,000 to ₹1 lakh at 4-7% interest',
      'Free/low-cost village-level storage',
      'Free training at Krishi Vigyan Kendras',
      'Cold chain access for perishables',
    ],
    lastDate: '2030-31 (6-year scheme)',
    status: 'Active',
    applicationUrl: 'https://agricoop.gov.in',
    documentRequired: ['Aadhaar Card', 'Land Records', 'Bank Account', 'Income Certificate'],
  },
];

// ============================================
// SERVICES DATA
// ============================================
const servicesData = [
  {
    title: 'Crop Care AI',
    image: 'https://cdn-icons-png.flaticon.com/512/2917/2917995.png',
    titleImage: 'https://cdn-icons-png.flaticon.com/512/2917/2917995.png',
    description: 'AI-powered crop disease detection and treatment recommendations. Upload photo of affected plant for instant diagnosis.',
    priority: 1,
  },
  {
    title: 'Weather Forecast',
    image: 'https://cdn-icons-png.flaticon.com/512/1779/1779940.png',
    titleImage: 'https://cdn-icons-png.flaticon.com/512/1779/1779940.png',
    description: 'Hyper-local weather forecasts for your farm location. 7-day predictions with farming activity recommendations.',
    priority: 2,
  },
  {
    title: 'Mandi Prices',
    image: 'https://cdn-icons-png.flaticon.com/512/2830/2830289.png',
    titleImage: 'https://cdn-icons-png.flaticon.com/512/2830/2830289.png',
    description: 'Real-time commodity prices from nearby mandis. Compare rates and find best market for your produce.',
    priority: 3,
  },
  {
    title: 'Expert Consultation',
    image: 'https://cdn-icons-png.flaticon.com/512/3774/3774299.png',
    titleImage: 'https://cdn-icons-png.flaticon.com/512/3774/3774299.png',
    description: 'Connect with agricultural experts for personalized advice. Video calls, chat support, and field visits available.',
    priority: 4,
  },
  {
    title: 'Government Schemes',
    image: 'https://cdn-icons-png.flaticon.com/512/2910/2910791.png',
    titleImage: 'https://cdn-icons-png.flaticon.com/512/2910/2910791.png',
    description: 'Browse and apply for government agricultural schemes. PM-KISAN, PMFBY, KCC and more with eligibility checker.',
    priority: 5,
  },
  {
    title: 'Crop Calendar',
    image: 'https://cdn-icons-png.flaticon.com/512/2693/2693507.png',
    titleImage: 'https://cdn-icons-png.flaticon.com/512/2693/2693507.png',
    description: 'Month-wise farming activities calendar for your crops. Get timely reminders for sowing, irrigation, and harvest.',
    priority: 6,
  },
  {
    title: 'Marketplace',
    image: 'https://cdn-icons-png.flaticon.com/512/3081/3081559.png',
    titleImage: 'https://cdn-icons-png.flaticon.com/512/3081/3081559.png',
    description: 'Buy and sell agricultural products, equipment, and inputs. Direct farmer-to-farmer and B2B transactions.',
    priority: 7,
  },
  {
    title: 'Farm Videos',
    image: 'https://cdn-icons-png.flaticon.com/512/1384/1384060.png',
    titleImage: 'https://cdn-icons-png.flaticon.com/512/1384/1384060.png',
    description: 'Watch farming tutorials and success stories from experienced farmers. Learn modern techniques in your language.',
    priority: 8,
  },
];

// ============================================
// REGIONS DATA - Major Agricultural Regions
// ============================================
const regionsData = [
  {
    name: 'Punjab Plains',
    state: 'Punjab',
    country: 'India',
    coordinates: { latitude: 30.9, longitude: 75.85 },
    climateType: 'Subtropical',
    elevation: 230,
    weatherPatterns: [
      { season: 'Summer', months: [4, 5, 6], averageTemperature: { min: 25, max: 42 }, averageRainfall: 30, averageHumidity: 40 },
      { season: 'Monsoon', months: [7, 8, 9], averageTemperature: { min: 25, max: 35 }, averageRainfall: 200, averageHumidity: 75 },
      { season: 'Winter', months: [11, 12, 1, 2], averageTemperature: { min: 5, max: 20 }, averageRainfall: 25, averageHumidity: 60 },
    ],
    soilTypes: [
      { name: 'Alluvial Soil', characteristics: ['Fertile', 'Well-drained', 'Rich in potash'], suitableCrops: [] },
    ],
    majorCrops: [],
    regionalGuidelines: [
      { title: 'Wheat Belt Practices', description: 'Punjab is known as India\'s wheat bowl. Follow recommended seed rate of 100kg/ha.', applicableSeasons: ['Rabi'] },
    ],
    status: 'active',
    metadata: { createdBy: 'System', lastUpdatedBy: 'System', version: 1 },
  },
  {
    name: 'Vidarbha',
    state: 'Maharashtra',
    country: 'India',
    coordinates: { latitude: 20.93, longitude: 77.75 },
    climateType: 'Semi-arid',
    elevation: 300,
    weatherPatterns: [
      { season: 'Summer', months: [3, 4, 5], averageTemperature: { min: 28, max: 45 }, averageRainfall: 15, averageHumidity: 25 },
      { season: 'Monsoon', months: [6, 7, 8, 9], averageTemperature: { min: 24, max: 32 }, averageRainfall: 150, averageHumidity: 80 },
      { season: 'Winter', months: [11, 12, 1, 2], averageTemperature: { min: 12, max: 30 }, averageRainfall: 10, averageHumidity: 45 },
    ],
    soilTypes: [
      { name: 'Black Cotton Soil', characteristics: ['High water retention', 'Rich in lime', 'Cracks when dry'], suitableCrops: [] },
    ],
    majorCrops: [],
    regionalGuidelines: [
      { title: 'Cotton Farming Best Practices', description: 'Vidarbha is a major cotton region. Use Bt cotton varieties for better pest resistance.', applicableSeasons: ['Kharif'] },
    ],
    status: 'active',
    metadata: { createdBy: 'System', lastUpdatedBy: 'System', version: 1 },
  },
  {
    name: 'Cauvery Delta',
    state: 'Tamil Nadu',
    country: 'India',
    coordinates: { latitude: 10.78, longitude: 79.13 },
    climateType: 'Tropical',
    elevation: 20,
    weatherPatterns: [
      { season: 'Summer', months: [3, 4, 5], averageTemperature: { min: 28, max: 38 }, averageRainfall: 40, averageHumidity: 65 },
      { season: 'Monsoon', months: [10, 11, 12], averageTemperature: { min: 24, max: 32 }, averageRainfall: 300, averageHumidity: 85 },
      { season: 'Winter', months: [1, 2], averageTemperature: { min: 22, max: 30 }, averageRainfall: 20, averageHumidity: 70 },
    ],
    soilTypes: [
      { name: 'Deltaic Alluvium', characteristics: ['Very fertile', 'High organic content', 'Excellent water retention'], suitableCrops: [] },
    ],
    majorCrops: [],
    regionalGuidelines: [
      { title: 'Rice Bowl of Tamil Nadu', description: 'The delta region is ideal for paddy. Practice System of Rice Intensification (SRI) for higher yields.', applicableSeasons: ['Kharif'] },
    ],
    status: 'active',
    metadata: { createdBy: 'System', lastUpdatedBy: 'System', version: 1 },
  },
];

// ============================================
// HOME SLIDER DATA
// ============================================
const homeSlidersData = [
  {
    title: 'PM-KISAN 19th Installment',
    content: 'Check your PM-KISAN status. Next installment coming soon!',
    dirURL: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=1200',
    modal: false,
    prority: 1,
  },
  {
    title: 'Rabi Season 2026',
    content: 'Time to prepare for Rabi crops. Check crop calendar for sowing dates.',
    dirURL: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=1200',
    modal: false,
    prority: 2,
  },
  {
    title: 'Crop Insurance Enrollment',
    content: 'Protect your crops with PMFBY. Premium as low as 1.5%.',
    dirURL: 'https://images.unsplash.com/photo-1560493676-04071c5f467b?w=1200',
    modal: false,
    prority: 3,
  },
  {
    title: 'Nano Urea Available',
    content: 'IFFCO Nano Urea - One bottle equals one bag. Save 40% on fertilizer costs.',
    dirURL: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=1200',
    modal: false,
    prority: 4,
  },
];

// ============================================
// HOME SCREEN ADS DATA
// ============================================
const homeScreenAdsData = [
  {
    title: 'Mahindra Tractors',
    content: 'India\'s No.1 Tractor Brand. EMI starts at ₹15,999/month. Book test drive now!',
    dirURL: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800',
    prority: 1,
  },
  {
    title: 'Bayer Crop Science',
    content: 'Protect your crops with Confidor. 100% genuine products. Order online.',
    dirURL: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=800',
    prority: 2,
  },
  {
    title: 'KCC Loan',
    content: 'Get Kisan Credit Card with limit up to ₹3 Lakh. Interest only 4%. Apply now!',
    dirURL: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800',
    prority: 3,
  },
];

// ============================================
// MARKETPLACE PRODUCTS DATA
// ============================================
const marketplaceProductsData = [
  {
    title: 'Mahindra 575 DI Tractor - 2022 Model',
    shortDescription: 'Well maintained 45 HP tractor with only 1200 hours. Perfect for medium farms.',
    detailedDescription: 'Selling my Mahindra 575 DI tractor in excellent condition. 45 HP engine, power steering, dual clutch. Only 1200 running hours. All documents available. Recently serviced with new tyres. Ideal for plowing, rotavator, and general farm work. Single owner, always garaged. Price negotiable for serious buyers.',
    media: [
      { type: 'image', url: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=800', isYoutubeVideo: false },
    ],
    priceRange: { min: 450000, max: 500000, currency: 'INR' },
    category: 'Tractors',
    condition: 'Used',
    location: 'Ludhiana, Punjab',
    views: 234,
    rating: 4.5,
    status: 'active',
    tags: ['tractor', 'mahindra', '575 di', 'punjab', 'farming equipment'],
  },
  {
    title: 'Drip Irrigation System - 2 Acre Complete Kit',
    shortDescription: 'Complete drip system for 2 acres with laterals, emitters, filters, and fittings.',
    detailedDescription: 'Brand new Jain Irrigation drip system kit for 2 acres. Includes: 16mm laterals (3000m), inline emitters (2 LPH), sand filter, screen filter, fertilizer tank, control valves, and all fittings. Government subsidy applicable - 55% for small farmers. Installation guidance provided. Ideal for vegetables, fruits, and row crops.',
    media: [
      { type: 'image', url: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800', isYoutubeVideo: false },
    ],
    priceRange: { min: 45000, max: 55000, currency: 'INR' },
    category: 'Irrigation',
    condition: 'New',
    location: 'Nashik, Maharashtra',
    views: 156,
    rating: 4.8,
    status: 'active',
    tags: ['drip irrigation', 'jain irrigation', 'subsidy', 'water saving'],
  },
  {
    title: 'Organic Vermicompost - 1 Ton',
    shortDescription: '100% organic vermicompost from earthworm cultivation. Rich in nutrients.',
    detailedDescription: 'Premium quality vermicompost prepared from agricultural waste using Eisenia fetida earthworms. NPK ratio: 1.5-2-1.5. Contains beneficial microorganisms. Free from chemical residues. Improves soil structure and water retention. Packed in 50kg bags. Bulk discount available. Delivery within 50km radius.',
    media: [
      { type: 'image', url: 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800', isYoutubeVideo: false },
    ],
    priceRange: { min: 6000, max: 8000, currency: 'INR' },
    category: 'Fertilizers',
    condition: 'New',
    location: 'Indore, Madhya Pradesh',
    views: 89,
    rating: 4.6,
    status: 'active',
    tags: ['vermicompost', 'organic', 'fertilizer', 'earthworm', 'sustainable'],
  },
  {
    title: 'Rotavator 7 Feet - Shaktiman',
    shortDescription: 'Heavy duty rotavator for 50+ HP tractors. Excellent for puddling and tillage.',
    detailedDescription: 'Shaktiman 7 feet rotavator in good working condition. 2 years old, blades replaced recently. Suitable for 50 HP and above tractors. Perfect for land preparation, puddling in paddy, and mixing crop residue. Gear driven, low maintenance. Reason for selling: upgraded to 9 feet model.',
    media: [
      { type: 'image', url: 'https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=800', isYoutubeVideo: false },
    ],
    priceRange: { min: 85000, max: 95000, currency: 'INR' },
    category: 'Farm Equipment',
    condition: 'Used',
    location: 'Karnal, Haryana',
    views: 167,
    rating: 4.3,
    status: 'active',
    tags: ['rotavator', 'shaktiman', 'tillage', 'farm equipment'],
  },
  {
    title: 'Desi Cow - Gir Breed (Pregnant)',
    shortDescription: '5 year old Gir cow, 4th lactation, currently 6 months pregnant.',
    detailedDescription: 'Pure Gir breed cow from registered dairy. 5 years old, healthy and active. Previous lactation yield: 12 liters/day peak. Currently 6 months pregnant (AI with Gir bull). Vaccinated and dewormed. All health certificates available. A2 milk quality confirmed through testing. Suitable for dairy farming and breeding.',
    media: [
      { type: 'image', url: 'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800', isYoutubeVideo: false },
    ],
    priceRange: { min: 120000, max: 150000, currency: 'INR' },
    category: 'Livestock',
    condition: 'Used',
    location: 'Mehsana, Gujarat',
    views: 312,
    rating: 4.9,
    status: 'active',
    tags: ['gir cow', 'desi cow', 'a2 milk', 'dairy', 'livestock'],
  },
];

// ============================================
// TESTIMONIALS DATA
// ============================================
const testimonialsData = [
  {
    testimonial: 'Krishi Mantra app helped me identify wheat rust disease early. The AI diagnosis feature saved my entire crop worth ₹2 lakhs. Highly recommended for all farmers!',
    rating: 5,
    name: 'Sukhdev Singh',
    profilePhoto: 'https://randomuser.me/api/portraits/men/11.jpg',
  },
  {
    testimonial: 'The mandi price feature is excellent. I now sell my cotton at the best price by comparing rates from different markets. Increased my income by 15%.',
    rating: 4,
    name: 'Ramabai Patil',
    profilePhoto: 'https://randomuser.me/api/portraits/women/12.jpg',
  },
  {
    testimonial: 'Weather forecasts are very accurate for my village. I plan irrigation and spraying based on app predictions. The crop calendar reminders are very useful.',
    rating: 5,
    name: 'Krishna Kumar',
    profilePhoto: 'https://randomuser.me/api/portraits/men/13.jpg',
  },
  {
    testimonial: 'Expert consultation feature connected me with a soil scientist who helped fix my nutrient deficiency problem. Video call option is very convenient.',
    rating: 5,
    name: 'Lakshmi Devi',
    profilePhoto: 'https://randomuser.me/api/portraits/women/14.jpg',
  },
  {
    testimonial: 'I learned about PM-KISAN and PMFBY schemes through this app. Successfully enrolled and received benefits. The application process guides are very helpful.',
    rating: 4,
    name: 'Bharat Yadav',
    profilePhoto: 'https://randomuser.me/api/portraits/men/15.jpg',
  },
];

// ============================================
// MAIN SEED FUNCTION
// ============================================
async function seedDatabase() {
  try {
    // Connect to MongoDB
    const mongoUrl = process.env.MONGODB_URL;
    if (!mongoUrl) {
      throw new Error('MONGODB_URL environment variable is not set');
    }

    console.log('🌱 Connecting to MongoDB...');
    await mongoose.connect(mongoUrl);
    console.log('✅ Connected to MongoDB');

    // Clear existing data (optional - comment out if you want to keep existing data)
    console.log('\n🗑️  Clearing existing data...');
    await Promise.all([
      User.deleteMany({}),
      UserDetail.deleteMany({}),
      Company.deleteMany({}),
      Products.deleteMany({}),
      News.deleteMany({}),
      Scheme.deleteMany({}),
      Services.deleteMany({}),
      Testimonial.deleteMany({}),
      Crop.deleteMany({}),
      Activity.deleteMany({}),
      CropCalendar.deleteMany({}),
      Region.deleteMany({}),
      HomeScreenAds.deleteMany({}),
      HomeSlider.deleteMany({}),
      SplashModal.deleteMany({}),
      FeedAds.deleteMany({}),
      MarketplaceProduct.deleteMany({}),
    ]);
    console.log('✅ Existing data cleared');

    // 1. Create Users
    console.log('\n👥 Creating users...');
    const createdUsers = [];
    for (const userData of usersData) {
      const { details, ...userInfo } = userData;

      // Hash password
      const hashedPassword = await bcrypt.hash('KrishiMantra@123', 10);

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

      createdUsers.push(user);
    }
    console.log(`✅ Created ${createdUsers.length} users`);

    // 2. Create Activities
    console.log('\n🔧 Creating activities...');
    const createdActivities = await Activity.insertMany(activitiesData);
    console.log(`✅ Created ${createdActivities.length} activities`);

    // 3. Create Crops
    console.log('\n🌾 Creating crops...');
    const createdCrops = await Crop.insertMany(cropsData);
    console.log(`✅ Created ${createdCrops.length} crops`);

    // 4. Create Companies
    console.log('\n🏢 Creating companies...');
    const createdCompanies = await Company.insertMany(companiesData);
    console.log(`✅ Created ${createdCompanies.length} companies`);

    // 5. Create Products (linking to companies and crops)
    console.log('\n📦 Creating products...');
    const productsToCreate = productsData.map(product => ({
      name: product.name,
      image: product.image,
      usage: product.usage,
      company: createdCompanies[product.companyIndex]._id,
      usedFor: createdCrops[product.cropIndex]._id,
    }));
    const createdProducts = await Products.insertMany(productsToCreate);

    // Update companies with their products
    for (let i = 0; i < productsData.length; i++) {
      const companyIndex = productsData[i].companyIndex;
      await Company.findByIdAndUpdate(
        createdCompanies[companyIndex]._id,
        { $push: { products: createdProducts[i]._id } }
      );
    }
    console.log(`✅ Created ${createdProducts.length} products`);

    // 6. Create News (with random user as uploader)
    console.log('\n📰 Creating news...');
    const newsToCreate = newsData.map(news => ({
      ...news,
      uploadedBy: createdUsers[Math.floor(Math.random() * createdUsers.length)]._id,
    }));
    const createdNews = await News.insertMany(newsToCreate);
    console.log(`✅ Created ${createdNews.length} news articles`);

    // 7. Create Schemes
    console.log('\n📋 Creating government schemes...');
    const createdSchemes = await Scheme.insertMany(schemesData);
    console.log(`✅ Created ${createdSchemes.length} schemes`);

    // 8. Create Services
    console.log('\n🛠️  Creating services...');
    const createdServices = await Services.insertMany(servicesData);
    console.log(`✅ Created ${createdServices.length} services`);

    // 9. Create Regions
    console.log('\n🗺️  Creating regions...');
    // Update regions with crop references
    const regionsToCreate = regionsData.map(region => ({
      ...region,
      majorCrops: createdCrops.slice(0, 3).map(c => c._id),
      soilTypes: region.soilTypes.map(soil => ({
        ...soil,
        suitableCrops: createdCrops.slice(0, 2).map(c => c._id),
      })),
    }));
    const createdRegions = await Region.insertMany(regionsToCreate);
    console.log(`✅ Created ${createdRegions.length} regions`);

    // 10. Create Crop Calendars
    console.log('\n📅 Creating crop calendars...');
    const cropCalendarsToCreate = [];
    for (const crop of createdCrops.slice(0, 4)) {
      // Create calendar entries for 3 months
      for (let month = 10; month <= 12; month++) {
        cropCalendarsToCreate.push({
          cropId: crop._id,
          month: month,
          growthStage: month === 10 ? 'Sowing' : month === 11 ? 'Vegetative' : 'Tillering',
          activities: [
            {
              activityId: createdActivities[month - 10]._id,
              timing: { week: 1, recommendedTime: 'Morning' },
              instructions: 'Follow standard practices',
              importance: 'Critical',
            },
          ],
          weatherConsiderations: {
            idealTemperature: { min: 15, max: 25 },
            rainfall: 'Low to moderate',
            humidity: '60-70%',
          },
          tips: ['Monitor soil moisture regularly', 'Check for pest infestations'],
          status: 'active',
        });
      }
    }
    const createdCropCalendars = await CropCalendar.insertMany(cropCalendarsToCreate);
    console.log(`✅ Created ${createdCropCalendars.length} crop calendar entries`);

    // 11. Create Home Sliders
    console.log('\n🖼️  Creating home sliders...');
    const createdHomeSliders = await HomeSlider.insertMany(homeSlidersData);
    console.log(`✅ Created ${createdHomeSliders.length} home sliders`);

    // 12. Create Home Screen Ads
    console.log('\n📢 Creating home screen ads...');
    const createdHomeAds = await HomeScreenAds.insertMany(homeScreenAdsData);
    console.log(`✅ Created ${createdHomeAds.length} home screen ads`);

    // 13. Create Testimonials
    console.log('\n💬 Creating testimonials...');
    const testimonialsToCreate = testimonialsData.map((t, i) => ({
      ...t,
      userId: createdUsers[i % createdUsers.length]._id,
    }));
    const createdTestimonials = await Testimonial.insertMany(testimonialsToCreate);
    console.log(`✅ Created ${createdTestimonials.length} testimonials`);

    // 14. Create Marketplace Products
    console.log('\n🛒 Creating marketplace products...');
    const marketplaceToCreate = marketplaceProductsData.map((product, i) => ({
      ...product,
      sellerInfo: {
        userId: createdUsers[5]._id, // Use marketplace user
        userName: createdUsers[5].name,
        profilePhoto: createdUsers[5].image,
        contactNumber: createdUsers[5].phoneNo.toString(),
      },
    }));
    const createdMarketplace = await MarketplaceProduct.insertMany(marketplaceToCreate);
    console.log(`✅ Created ${createdMarketplace.length} marketplace products`);

    // 15. Create UI Display settings
    console.log('\n⚙️  Creating UI display settings...');
    await UIDisplay.create({
      Slider: true,
      SplashSreen: true,
      HomeScreenAdOne: true,
      HomeScreenAdTwo: true,
      HomeScreenAdThree: true,
      HomeScreenAdFour: true,
      FeedAds: true,
      ReelAds: true,
      NewsAds: true,
    });
    console.log('✅ Created UI display settings');

    // Summary
    console.log('\n' + '='.repeat(50));
    console.log('🎉 SEED DATA COMPLETE!');
    console.log('='.repeat(50));
    console.log(`
Summary:
- Users: ${createdUsers.length}
- Companies: ${createdCompanies.length}
- Products: ${createdProducts.length}
- Crops: ${createdCrops.length}
- Activities: ${createdActivities.length}
- Crop Calendars: ${createdCropCalendars.length}
- Regions: ${createdRegions.length}
- News Articles: ${createdNews.length}
- Government Schemes: ${createdSchemes.length}
- Services: ${createdServices.length}
- Home Sliders: ${createdHomeSliders.length}
- Home Ads: ${createdHomeAds.length}
- Testimonials: ${createdTestimonials.length}
- Marketplace Products: ${createdMarketplace.length}

Default password for all users: KrishiMantra@123
    `);

    await mongoose.connection.close();
    console.log('✅ Database connection closed');
    process.exit(0);

  } catch (error) {
    console.error('❌ Error seeding database:', error);
    process.exit(1);
  }
}

// Run the seed function
seedDatabase();
