// data/demo_data.dart
import '../models/company.dart';
import '../models/product.dart';
import '../models/address.dart';
import '../models/crop.dart';

// Create demo crop data
final List<Crop> demoCrops = [
  Crop(id: '1', name: 'Wheat'),
  Crop(id: '2', name: 'Rice'),
  Crop(id: '3', name: 'Corn'),
  Crop(id: '4', name: 'Cotton'),
];

// Create demo products
final List<Product> demoProducts = [
  Product(
    id: '1',
    name: 'Nitrogen Boost Fertilizer',
    image: 'https://example.com/nitrogen_fertilizer.jpg',
    usage: 'Excellent for promoting leaf and stem growth. Apply before planting or during early growth stages.',
    usedFor: [demoCrops[0], demoCrops[2]], // Wheat and Corn
  ),
  // Continuing demo products
Product(
    id: '2',
    name: 'Phosphorus Power Fertilizer',
    image: 'https://example.com/phosphorus_fertilizer.jpg',
    usage: 'Enhances root development and flower production. Best applied during seed planting and early growth.',
    usedFor: [demoCrops[1], demoCrops[3]], // Rice and Cotton
  ),
  Product(
    id: '3',
    name: 'Potassium Pro Fertilizer',
    image: 'https://example.com/potassium_fertilizer.jpg',
    usage: 'Improves overall plant health and disease resistance. Ideal for mature crops during crucial growth stages.',
    usedFor: demoCrops, // All crops
  ),
];

// Create demo company data
final List<Company> demoCompanies = [
  Company(
    id: '1',
    name: 'GreenGrow Fertilizers',
    email: 'info@greengrow.com',
    address: Address(
      street: '123 Agricultural Lane',
      city: 'Farmville',
      state: 'Agricultural State',
      zip: '12345'
    ),
    phone: '+1 (555) 123-4567',
    website: 'https://www.greengrow.com',
    description: 'Leading agricultural solutions provider with innovative fertilizer technologies.',
    logo: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT7EHRhusyS2HnmwfYbhJcApIeXGPPYZev25g&s',
    rating: 4.5,
    products: [demoProducts[0], demoProducts[1]]
  ),
  Company(
    id: '2',
    name: 'NutriCrop Solutions',
    email: 'support@nutricrop.com',
    address: Address(
      street: '456 Harvest Road',
      city: 'Cropland',
      state: 'Farming State',
      zip: '67890'
    ),
    phone: '+1 (555) 987-6543',
    website: 'https://www.nutricrop.com',
    description: 'Committed to sustainable agricultural practices and high-quality fertilizer solutions.',
    logo: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSK-Y5Le7CV7hBCRvaHapg3_fRi4I9o3onV5O84U5nimC-xbcRMfAvnK3F1GyBuD2dkqxU&usqp=CAU',
    rating: 4.2,
    products: [demoProducts[2]]
  ),
  Company(
    id: '3',
    name: 'NutriCrop Solutions',
    email: 'support@nutricrop.com',
    address: Address(
      street: '456 Harvest Road',
      city: 'Cropland',
      state: 'Farming State',
      zip: '67890'
    ),
    phone: '+1 (555) 987-6543',
    website: 'https://www.nutricrop.com',
    description: 'Committed to sustainable agricultural practices and high-quality fertilizer solutions.',
    logo: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSK-Y5Le7CV7hBCRvaHapg3_fRi4I9o3onV5O84U5nimC-xbcRMfAvnK3F1GyBuD2dkqxU&usqp=CAU',
    rating: 4.2,
    products: [demoProducts[2]]
  ),
  Company(
    id: '4',
    name: 'NutriCrop Solutions',
    email: 'support@nutricrop.com',
    address: Address(
      street: '456 Harvest Road',
      city: 'Cropland',
      state: 'Farming State',
      zip: '67890'
    ),
    phone: '+1 (555) 987-6543',
    website: 'https://www.nutricrop.com',
    description: 'Committed to sustainable agricultural practices and high-quality fertilizer solutions.',
    logo: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSK-Y5Le7CV7hBCRvaHapg3_fRi4I9o3onV5O84U5nimC-xbcRMfAvnK3F1GyBuD2dkqxU&usqp=CAU',
    rating: 4.2,
    products: [demoProducts[2]]
  ),
];