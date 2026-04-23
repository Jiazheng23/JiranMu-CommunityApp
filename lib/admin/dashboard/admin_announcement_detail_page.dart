import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AdminAnnouncementDetailPage extends StatefulWidget {
  final Map data;

  const AdminAnnouncementDetailPage({super.key, required this.data});

  @override
  State<AdminAnnouncementDetailPage> createState() => _AdminAnnouncementDetailPageState();
}

class _AdminAnnouncementDetailPageState extends State<AdminAnnouncementDetailPage> {
  final supabase = Supabase.instance.client;
  late Map currentData;
  bool isLoadingDetails = false;

  // 🚨 新增：记录是否发生过编辑，用于通知上一页刷新
  bool _wasEdited = false;

  @override
  void initState() {
    super.initState();
    currentData = widget.data;
  }

  Future<void> fetchLatestDetails() async {
    try {
      setState(() => isLoadingDetails = true);
      final response = await supabase
          .from('announcements')
          .select()
          .eq('id', currentData['id']) // 匹配 UUID
          .single();

      setState(() {
        currentData = response;
        isLoadingDetails = false;
      });
    } catch (e) {
      debugPrint("Error fetching details: $e");
      setState(() => isLoadingDetails = false);
    }
  }

  Future<void> deleteAnnouncement() async {
    try {
      await supabase.from('announcements').delete().eq('id', currentData['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Announcement deleted successfully"),
          backgroundColor: Colors.brown.shade800, // 棕色主题的 SnackBar
        ),
      );
      // 删除成功后，直接返回 true，告诉列表页“数据有变，需要刷新”
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error deleting: $e");
    }
  }

  void confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Delete", style: TextStyle(color: Colors.brown.shade900)),
        content: const Text("Are you sure you want to delete this announcement?"),
        backgroundColor: Colors.brown.shade50, // 弹窗背景稍微带点浅棕色
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.brown.shade600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteAnnouncement();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)), // 删除依然保持红色以示警告
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    // 1. 获取现有数据，填充到控制器中
    final titleController = TextEditingController(text: currentData['title'] ?? "");
    final contentController = TextEditingController(text: currentData['content'] ?? "");

    // 初始化现有分类，如果没有就默认 'General'
    String selectedCategory = currentData['category'] ?? 'General';
    if (!['Notice', 'Maintenance', 'Event', 'General'].contains(selectedCategory)) {
      selectedCategory = 'General';
    }

    // 初始化现有日期和状态
    DateTime? selectedDate = currentData['event_date'] != null
        ? DateTime.parse(currentData['event_date']).toLocal()
        : null;
    bool isUrgent = currentData['is_urgent'] ?? false;

    // 初始化图片状态
    String? existingImageUrl = currentData['image_url'];
    File? imageFile;
    bool isUploading = false;
    final ImagePicker picker = ImagePicker();

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
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text("Edit Announcement",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown.shade900)),
                ),
                const SizedBox(height: 20),

                // --- 图片显示与选择区域 ---
                GestureDetector(
                  onTap: () async {
                    final XFile? pickedFile = await picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 70);
                    if (pickedFile != null) {
                      setModalState(() => imageFile = File(pickedFile.path));
                    }
                  },
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.brown.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.brown.shade200),
                    ),
                    child: imageFile != null
                    // 场景 1: 选了新图片，显示新图片
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(imageFile!, fit: BoxFit.cover, width: double.infinity),
                    )
                        : (existingImageUrl != null && existingImageUrl!.isNotEmpty && existingImageUrl!.startsWith('http'))
                    // 场景 2: 没选新图但原来有图，显示原来的网图
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(existingImageUrl!, fit: BoxFit.cover, width: double.infinity),
                    )
                    // 场景 3: 啥图片都没有，显示添加按钮
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: Colors.brown.shade300, size: 45),
                        const SizedBox(height: 8),
                        Text("Update Cover Photo", style: TextStyle(color: Colors.brown.shade400, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // --- 标题 ---
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

                // --- 内容 ---
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

                // --- 分类 ---
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

                // --- 日期与紧急程度 ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2000), // 编辑时允许选择过去的日期
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.brown.shade600,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.brown.shade900,
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

                // --- 保存更新按钮 ---
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade600,
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
                        String? finalImageUrl = existingImageUrl;

                        // 如果编辑时选了新图片，就上传新图片并更新 URL
                        if (imageFile != null) {
                          final fileName = 'ann_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final path = 'public/$fileName';
                          await supabase.storage.from('announcement_images').upload(path, imageFile!);
                          finalImageUrl = supabase.storage.from('announcement_images').getPublicUrl(path);
                        }

                        // 准备要更新到数据库的 payload
                        final payload = {
                          'title': titleController.text.trim(),
                          'content': contentController.text.trim(),
                          'category': selectedCategory,
                          'event_date': selectedDate?.toIso8601String(),
                          'is_urgent': isUrgent,
                          'image_url': finalImageUrl,
                        };

                        await supabase.from('announcements').update(payload).eq('id', currentData['id']);

                        if (context.mounted) {
                          Navigator.pop(context); // 关闭底部弹窗
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text("Announcement updated!"), backgroundColor: Colors.brown.shade800));

                          // 🚨 标记发生了修改，并刷新当前页面最新详情
                          _wasEdited = true;
                          fetchLatestDetails();
                        }
                      } catch (e) {
                        debugPrint("Update Error: $e");
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text("Failed to update. Check your connection."), backgroundColor: Colors.red));
                        }
                      } finally {
                        setModalState(() => isUploading = false);
                      }
                    },
                    child: isUploading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  @override
  Widget build(BuildContext context) {
    // 格式化带时区的时间戳
    String dateStr = currentData['created_at'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(currentData['created_at']).toLocal())
        : "";

    // 🚨 严谨的图片校验逻辑：防黄屏报错
    final String imageUrl = currentData['image_url']?.toString() ?? '';
    final bool hasImage = imageUrl.isNotEmpty && imageUrl.startsWith('http');

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5), // 非常淡的米棕色作为底色
      appBar: AppBar(
        title: const Text("Announcement Detail", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown.shade600, // 顶部使用深棕色
        foregroundColor: Colors.white, // 文字为白色
        elevation: 0,
        // 🚨 覆盖默认返回按钮，返回时带上刷新信号 _wasEdited
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _wasEdited);
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _showEditDialog),
          // 删除按钮
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: confirmDelete),
        ],
      ),
      body: isLoadingDetails
          ? Center(child: CircularProgressIndicator(color: Colors.brown.shade400)) // 棕色加载条
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 渲染图片区域
          if (hasImage)
            Image.network(
              imageUrl, // 使用严格校验过的 imageUrl
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 220,
                color: Colors.brown.shade100, // 图片加载失败时显示浅棕色底
                child: Center(child: Icon(Icons.broken_image, color: Colors.brown.shade300, size: 40)),
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentData['is_urgent'] == true)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.red.shade700, // 紧急标志保持醒目
                          borderRadius: BorderRadius.circular(4)
                      ),
                      child: const Text("URGENT", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  Text(
                      currentData['title'] ?? "No Title",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                          color: Colors.brown.shade900 // 标题深棕色
                      )
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.brown.shade400),
                      const SizedBox(width: 6),
                      Text(dateStr, style: TextStyle(color: Colors.brown.shade600, fontSize: 14)),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.brown.shade100, // 标签浅棕底色
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: Text(
                            currentData['category'] ?? "General",
                            style: TextStyle(fontSize: 12, color: Colors.brown.shade800, fontWeight: FontWeight.w600)
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 正文区域
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.brown.shade100, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.brown.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                    ),
                    child: Text(
                      currentData['content'] ?? "",
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.brown.shade800, // 文本深棕色
                          height: 1.6
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}