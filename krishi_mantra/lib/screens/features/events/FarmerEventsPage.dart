import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Event Model
class FarmEvent {
  final String id;
  final String title;
  final String organizer;
  final DateTime date;
  final String location;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;

  FarmEvent({
    required this.id,
    required this.title,
    required this.organizer,
    required this.date,
    required this.location,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
  });
}

class EventDetailPage extends StatelessWidget {
  final FarmEvent event;

  const EventDetailPage({Key? key, required this.event}) : super(key: key);

  void _openMapLocation() async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${event.latitude},${event.longitude}';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                event.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black45,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Hero(
                tag: 'event_image_${event.id}',
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.green[100],
                    child: Icon(Icons.agriculture, size: 100, color: Colors.green),
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Details Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date and Time
                            _buildDetailRow(
                              icon: Icons.calendar_today,
                              title: 'Date & Time',
                              subtitle: DateFormat('dd MMM yyyy, hh:mm a').format(event.date),
                            ),
                            SizedBox(height: 12),

                            // Organizer
                            _buildDetailRow(
                              icon: Icons.business,
                              title: 'Organizer',
                              subtitle: event.organizer,
                            ),
                            SizedBox(height: 12),

                            // Location
                            _buildDetailRow(
                              icon: Icons.location_on,
                              title: 'Location',
                              subtitle: event.location,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Description
                    Text(
                      'About the Event',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),

                    SizedBox(height: 20),

                    // Open in Maps Button
                    Center(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.map_outlined),
                        label: Text('Open in Google Maps'),
                        onPressed: _openMapLocation,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white, backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green[600], size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FarmerEventsPage extends StatefulWidget {
  const FarmerEventsPage({Key? key}) : super(key: key);

  @override
  _FarmerEventsPageState createState() => _FarmerEventsPageState();
}

class _FarmerEventsPageState extends State<FarmerEventsPage> {
  final List<FarmEvent> _events = [
    FarmEvent(
      id: '1',
      title: "Agriculture Innovation Seminar",
      organizer: "KVK Pune",
      date: DateTime(2024, 2, 15, 10, 0),
      location: "KVK Pune Campus, Maharashtra",
      description: "Join us for a comprehensive seminar on the latest sustainable farming techniques, crop management strategies, and innovative agricultural technologies. Learn from experts and network with fellow farmers.",
      imageUrl: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTcPAn1lSW5oJIjSZLG9vIxFhZ-pHU2NV7bzw&s", // Replace with actual image URL
      latitude: 18.5204,
      longitude: 73.8567,
    ),
    FarmEvent(
      id: '2',
      title: "Soil Health Workshop",
      organizer: "KVK Baramati",
      date: DateTime(2024, 3, 20, 9, 30),
      location: "Agricultural Research Center, Baramati",
      description: "A hands-on workshop focusing on soil testing methods, nutrient management, and strategies to improve soil fertility. Discover advanced techniques to enhance crop yield and soil health.",
      imageUrl: "https://www.kvkbaramati.com/images/m1.jpg", // Replace with actual image URL
      latitude: 18.1557,
      longitude: 75.7092,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Farmer Events',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color.fromARGB(255, 255, 255, 255)!, const Color.fromARGB(255, 232, 232, 232)!],
          ),
        ),
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _events.length,
          itemBuilder: (context, index) {
            return _buildEventCard(_events[index]);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Add Event Feature Coming Soon!')),
          );
        },
        backgroundColor: Colors.green[700],
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEventCard(FarmEvent event) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailPage(event: event),
          ),
        );
      },
      child: Card(
        elevation: 6,
        shadowColor: Colors.green.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            Hero(
              tag: 'event_image_${event.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: Colors.green[100],
                    child: Icon(Icons.agriculture, size: 100, color: Colors.green),
                  ),
                ),
              ),
            ),

            // Event Details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.green[600], size: 18),
                      SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(event.date),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green[600], size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

