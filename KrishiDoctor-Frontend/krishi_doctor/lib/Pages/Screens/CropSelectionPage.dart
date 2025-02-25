import 'package:flutter/material.dart';

class CropData {
  final String name;
  final String imageUrl;

  CropData({
    required this.name,
    required this.imageUrl,
  });
}

class CropSelectionScreen extends StatefulWidget {
  const CropSelectionScreen({super.key});

  @override
  State<CropSelectionScreen> createState() => _CropSelectionScreenState();
}

class _CropSelectionScreenState extends State<CropSelectionScreen> {
  final List<CropData> crops = [
    CropData(
      name: 'Wheat',
      imageUrl: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b',
    ),
    CropData(
      name: 'Rice',
      imageUrl: 'https://images.unsplash.com/photo-1536746803623-cef87080bfc8',
    ),
    CropData(
      name: 'Cotton',
      imageUrl: 'https://images.unsplash.com/photo-1594896351298-58dd1a9c35c9',
    ),
    CropData(
      name: 'Maize',
      imageUrl: 'https://images.unsplash.com/photo-1526150571904-1f05cab1b020',
    ),
    CropData(
      name: 'Sugarcane',
      imageUrl: 'https://images.unsplash.com/photo-1596673686104-8b1a2c29d8cf',
    ),
    CropData(
      name: 'Soybean',
      imageUrl: 'https://images.unsplash.com/photo-1599720843413-60211c3aa419',
    ),
    CropData(
      name: 'Tomato',
      imageUrl: 'https://images.unsplash.com/photo-1592841200221-a6898f307baa',
    ),
    CropData(
      name: 'Potato',
      imageUrl: 'https://images.unsplash.com/photo-1518977676601-b53f82aba655',
    ),
  ];

  Set<String> selectedCrops = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: _buildCropGrid(),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Your Crops',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose at least 2 crops',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${selectedCrops.length} Selected',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 16,
        alignment: WrapAlignment.start,
        children: crops.map((crop) => _buildCropCard(crop)).toList(),
      ),
    );
  }

  Widget _buildCropCard(CropData crop) {
    final isSelected = selectedCrops.contains(crop.name);
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32 - 36) / 4; // 32 for padding, 36 for spacing between items

    return GestureDetector(
      onTap: () => _toggleCropSelection(crop.name),
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: itemWidth - 10,
                  height: itemWidth - 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      crop.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              crop.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.green[700] : Colors.grey[800],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: ElevatedButton(
            onPressed: selectedCrops.length >= 2
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Selected crops: ${selectedCrops.join(", ")}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: selectedCrops.length >= 2 ? 4 : 0,
            ),
            child: Text(
              selectedCrops.length >= 2 ? 'Continue' : 'Select at least 2 crops',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleCropSelection(String cropName) {
    setState(() {
      if (selectedCrops.contains(cropName)) {
        selectedCrops.remove(cropName);
      } else {
        selectedCrops.add(cropName);
      }
    });
  }
}