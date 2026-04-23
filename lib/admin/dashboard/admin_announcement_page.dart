import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'admin_announcement_detail_page.dart';

class AdminAnnouncementPage extends StatefulWidget {
  const AdminAnnouncementPage({super.key});

  @override
  State<AdminAnnouncementPage> createState() => _AdminAnnouncementPageState();
}

class _AdminAnnouncementPageState extends State<AdminAnnouncementPage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker(); // 图片选择器实例

  List announcements = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAnnouncements();
  }

  Future<void> fetchAnnouncements() async {
    try {
      setState(() => isLoading = true);
      final data = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        announcements = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching announcements: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- 你提供的 Create Announcement BottomSheet (已适配棕色主题) ---
  void _showCreateAnnouncementSheet(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    DateTime? selectedDate;
    bool isUrgent = false;
    String selectedCategory = 'Notice';
    File? imageFile;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 25,
              left: 20,
              right: 20),
          decoration: const BoxDecoration(
              color: Colors.white, // 底色保持白色
              borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text("Create Announcement",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown.shade900)),
                ),
                const SizedBox(height: 20),

                // 图片选择区域
                GestureDetector(
                  onTap: () async {
                    final XFile? pickedFile = await _picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 70);
                    if (pickedFile != null) {
                      setModalState(() => imageFile = File(pickedFile.path));
                    }
                  },
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.brown.shade50, // 浅棕色背景
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.brown.shade200),
                    ),
                    child: imageFile == null
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: Colors.brown.shade300, size: 45),
                        const SizedBox(height: 8),
                        Text("Add Cover Photo", style: TextStyle(color: Colors.brown.shade400, fontSize: 13)),
                      ],
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(imageFile!, fit: BoxFit.cover, width: double.infinity),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 标题输入
                TextField(
                    controller: titleController,
                    cursorColor: Colors.brown.shade600,
                    decoration: InputDecoration(
                        labelText: "Title",
                        labelStyle: TextStyle(color: Colors.brown.shade400),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.brown.shade600)))),
                const SizedBox(height: 15),

                // 内容输入
                TextField(
                    controller: contentController,
                    maxLines: 4,
                    cursorColor: Colors.brown.shade600,
                    decoration: InputDecoration(
                        labelText: "Message",
                        alignLabelWithHint: true,
                        labelStyle: TextStyle(color: Colors.brown.shade400),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.brown.shade600)))),
                const SizedBox(height: 15),

                // 类别选择
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                      labelText: "Category",
                      labelStyle: TextStyle(color: Colors.brown.shade400),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.brown.shade600)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: ['Notice', 'Maintenance', 'Event', 'General']
                      .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (val) => setModalState(() => selectedCategory = val!),
                ),

                const SizedBox(height: 15),

                // 日期与紧急程度
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                          // 适配棕色主题的日历
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.brown.shade600, // header background color
                                  onPrimary: Colors.white, // header text color
                                  onSurface: Colors.brown.shade900, // body text color
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) setModalState(() => selectedDate = picked);
                      },
                      icon: Icon(Icons.calendar_month, color: Colors.brown.shade600),
                      label: Text(
                        selectedDate == null
                            ? "Set Event Date"
                            : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                        style: TextStyle(color: Colors.brown.shade600, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(children: [
                      const Text("Urgent", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      Switch(
                          value: isUrgent,
                          activeColor: Colors.red,
                          onChanged: (val) => setModalState(() => isUrgent = val)),
                    ]),
                  ],
                ),
                const SizedBox(height: 20),

                // 发布按钮
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade600, // 按钮主色
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: isUploading ? null : () async {
                      if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please fill in Title and Message")));
                        return;
                      }

                      setModalState(() => isUploading = true);
                      try {
                        String? imageUrl;
                        // 1. 如果有图片，先上传到存储桶
                        if (imageFile != null) {
                          final fileName = 'ann_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final path = 'public/$fileName'; // 确保存储桶里有 public 文件夹，或者直接传文件名
                          await supabase.storage.from('announcement_images').upload(path, imageFile!);
                          imageUrl = supabase.storage.from('announcement_images').getPublicUrl(path);
                        }

                        // 2. 写入数据库
                        await supabase.from('announcements').insert({
                          'title': titleController.text.trim(),
                          'content': contentController.text.trim(),
                          'category': selectedCategory,
                          'event_date': selectedDate?.toIso8601String(),
                          'is_urgent': isUrgent,
                          if (imageUrl != null) 'image_url': imageUrl,
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text("Announcement published!"), backgroundColor: Colors.brown.shade800));

                          // 🚨 刷新列表页的数据
                          fetchAnnouncements();
                        }
                      } catch (e) {
                        debugPrint("Upload Error: $e");
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text("Failed to publish. Check your connection."), backgroundColor: Colors.red));
                        }
                      } finally {
                        setModalState(() => isUploading = false);
                      }
                    },
                    child: isUploading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Publish Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 列表卡片 UI ---
  Widget _buildAnnouncementCard(Map data) {
    bool hasImage = data['image_url'] != null && data['image_url'].toString().isNotEmpty;
    bool isUrgent = data['is_urgent'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.brown.shade100, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminAnnouncementDetailPage(data: data)),
          ).then((_) => fetchAnnouncements());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      data['image_url'],
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.brown.shade100,
                        height: 160,
                        child: Center(child: Icon(Icons.broken_image, color: Colors.brown.shade300)),
                      ),
                    ),
                  ),
                  if (isUrgent)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("URGENT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),

            if (!hasImage && isUrgent)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(4)),
                    child: const Text("URGENT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
                top: (hasImage || isUrgent) ? 12 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? "No Title",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.brown.shade900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['content'] ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Colors.brown.shade800, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      appBar: AppBar(
        title: const Text("Manage Announcements", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.brown.shade600,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        // 🚨 这里改为调用你新加的 BottomSheet 方法
        onPressed: () => _showCreateAnnouncementSheet(context),
        backgroundColor: Colors.brown.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.brown.shade400))
          : announcements.isEmpty
          ? Center(child: Text("No announcements found.", style: TextStyle(color: Colors.brown.shade600)))
          : RefreshIndicator(
        color: Colors.brown.shade600,
        onRefresh: fetchAnnouncements,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: announcements.length,
          itemBuilder: (context, index) => _buildAnnouncementCard(announcements[index]),
        ),
      ),
    );
  }
}