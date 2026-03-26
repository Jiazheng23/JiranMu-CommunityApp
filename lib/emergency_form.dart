import 'package:flutter/material.dart';

class EmergencyForm extends StatefulWidget {
  const EmergencyForm({super.key});

  @override
  State<EmergencyForm> createState() => _EmergencyFormState();
}

class _EmergencyFormState extends State<EmergencyForm> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    super.dispose();
  }

  void submit() {
    String title = titleController.text.trim();
    String desc = descController.text.trim();

    print("Title: $title");
    print("Description: $desc");

    Navigator.pop(context); // 关闭弹窗
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 🔥 关键
        children: [
          Text(
            "Create Emergency",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 12),

          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: "Title",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 12),

          TextField(
            controller: descController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Description",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 16),

          ElevatedButton(
            onPressed: submit,
            child: Text("Submit"),
          ),
        ],
      ),
    );

  }

}
