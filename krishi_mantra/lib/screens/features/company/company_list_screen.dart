// screens/company_list_screen.dart
import 'package:flutter/material.dart';
import 'package:krishi_mantra/API/CompanyScreenAPI.dart';
import 'package:krishi_mantra/screens/features/company/company_details_screen.dart';
import 'package:krishi_mantra/screens/features/company/models/api_response.dart';
import 'dart:convert';

import 'package:krishi_mantra/screens/features/company/models/modal.dart';
import 'package:krishi_mantra/screens/features/company/widgets/company_card.dart';

class CompanyListScreen extends StatefulWidget {
  @override
  _CompanyListScreenState createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final ApiService _apiService = ApiService();
  List<Company> companies = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    try {
      final response = await _apiService.getAllCompany();

      if (response.statusCode == 200) {
        final ApiResponse apiResponse = ApiResponse.fromJson(
          json.decode(response.body),
        );

        setState(() {
          companies = apiResponse.data;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load companies';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fertilizer Companies',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _fetchCompanies();
            },
          ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // TODO: Implement search functionality
            },
          )
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(error!),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                            error = null;
                          });
                          _fetchCompanies();
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchCompanies,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: companies.length,
                      itemBuilder: (context, index) {
                        final company = companies[index];
                        return CompanyCard(
                          company: company,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CompanyDetailScreen(
                                  companyId: company.id,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
