
import 'package:flutter/material.dart';

class SearchResultsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final bool isSearching;
  final Function(String) onAddChild;

  const SearchResultsWidget({
    Key? key,
    required this.results,
    required this.isSearching,
    required this.onAddChild,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (results.isEmpty) {
      return const Center(
        child: Text('No users found'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: results.length,
      itemBuilder: (context, index) {
        Map<String, dynamic> user = results[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(user['displayName'][0].toUpperCase()),
          ),
          title: Text(user['displayName']),
          subtitle: Text(user['email']),
          trailing: user['isAlreadyChild']
              ? const Chip(
            label: Text('Child'),
            backgroundColor: Colors.green,
          )
              : user['hasPendingRequest']
              ? const Chip(
            label: Text('Pending'),
            backgroundColor: Colors.orange,
          )
              : ElevatedButton(
            onPressed: () => onAddChild(user['uid']),
            child: const Text('Add as Child'),
          ),
        );
      },
    );
  }
}
