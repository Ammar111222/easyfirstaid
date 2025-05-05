import 'package:easy_first_aid/Search/widgets/child_tracking_screen.dart';
import 'package:flutter/material.dart';

class ChildrenListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final Function(String) onDeleteChild;

  const ChildrenListWidget({
    Key? key,
    required this.children,
    required this.onDeleteChild,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Your Children',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> child = children[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChildTrackingScreen(
                        childId: child['uid'],
                        childName: child['displayName'],
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(child['displayName'][0].toUpperCase()),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child['displayName'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(child['email']),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Remove Child'),
                                content: Text('Are you sure you want to remove ${child['displayName']} from your children list?'),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancel'),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                  TextButton(
                                    child: const Text('Remove', style: TextStyle(color: Colors.red)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      onDeleteChild(child['uid']);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}