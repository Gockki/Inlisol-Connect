import 'package:flutter/material.dart';

class ResidentsPage extends StatelessWidget {
  const ResidentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Residents")),
      body: ListView.builder(
        itemCount: 5, // Replace with API data
        itemBuilder: (context, index) {
          return ListTile(
            title: Text("Resident ${index + 1}"),
            subtitle: const Text("Status: Active"),
            trailing: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // Navigate to Resident Details
              },
            ),
          );
        },
      ),
    );
  }
}
