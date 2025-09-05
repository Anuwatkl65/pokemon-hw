import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class TeamListPage extends StatefulWidget {
  const TeamListPage({super.key});
  @override
  State<TeamListPage> createState() => _TeamListPageState();
}

class _TeamListPageState extends State<TeamListPage> {
  final storage = GetStorage();
  List<Map<String, dynamic>> teams = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final t = storage.read<List>('teams') ?? [];
    teams = t.map((e) => Map<String, dynamic>.from(e)).toList().reversed.toList();
    setState(() {});
  }

  void _deleteAt(int index) {
    final all = storage.read<List>('teams') ?? [];
    // index ใน UI เป็น reverse
    final realIndex = all.length - 1 - index;
    all.removeAt(realIndex);
    storage.write('teams', all);
    _load();
    Get.snackbar('ลบทีมแล้ว', '',
        snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ทีมของฉัน'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            tooltip: 'เลือกทีมใหม่',
            onPressed: () => Get.offNamed('/select'),
            icon: const Icon(Icons.add),
          )
        ],
      ),
      body: teams.isEmpty
          ? const Center(child: Text('ยังไม่มีทีมที่บันทึกไว้'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: teams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final team = teams[i];
                final name = team['name'] as String;
                final members =
                    (team['members'] as List).map((e) => Map<String, dynamic>.from(e)).toList();

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // avatars
                        SizedBox(
                          height: 48,
                          width: 120,
                          child: Stack(
                            children: List.generate(members.length, (k) {
                              final m = members[k];
                              return Positioned(
                                left: k * 28.0,
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: ClipOval(
                                    child: Image.network(m['img'], width: 42, height: 42),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'รายละเอียด',
                          onPressed: () {
                            Get.dialog(AlertDialog(
                              title: Text(name),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: members.map((m) {
                                  return ListTile(
                                    leading:
                                        Image.network(m['img'], width: 36, height: 36),
                                    title: Text((m['name'] as String).toUpperCase()),
                                  );
                                }).toList(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(),
                                  child: const Text('ปิด'),
                                )
                              ],
                            ));
                          },
                          icon: const Icon(Icons.info_outline),
                        ),
                        IconButton(
                          tooltip: 'ลบทีมนี้',
                          onPressed: () => _deleteAt(i),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
