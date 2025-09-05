import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

/// ---------- Model ----------
class Pokemon {
  final int id;
  final String name;
  final String imageUrl;
  const Pokemon({required this.id, required this.name, required this.imageUrl});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'img': imageUrl};
  factory Pokemon.fromJson(Map<String, dynamic> j) =>
      Pokemon(id: j['id'], name: j['name'], imageUrl: j['img']);

  // สำคัญ! เพื่อแก้ปัญหา "ยกเลิกเลือกแล้วค้าง"
  @override
  bool operator ==(Object other) => other is Pokemon && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// ---------- Controller ----------
class SelectPlayerController extends GetxController {
  final storage = GetStorage();

  // data
  final pokemons = <Pokemon>[].obs;
  final selected = <Pokemon>[].obs;

  // paging
  final nextUrl = 'https://pokeapi.co/api/v2/pokemon?limit=100'.obs;
  final isLoading = false.obs;
  final hasMore = true.obs;

  // inputs
  final teamNameCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  final query = ''.obs;

  bool get isFull => selected.length >= 3;
  bool get canConfirm => selected.length == 3;

  @override
  void onInit() {
    super.onInit();
    _loadDraftFromStorage();
    fetchNextPage();

    teamNameCtrl.addListener(() {
      storage.write('draft_team_name', teamNameCtrl.text.trim());
    });
    searchCtrl.addListener(() {
      query.value = searchCtrl.text.trim().toLowerCase();
    });
  }

  // ---------- Paging fetch ----------
  Future<void> fetchNextPage() async {
    if (!hasMore.value || isLoading.value) return;
    isLoading.value = true;
    final resp = await http.get(Uri.parse(nextUrl.value));
    isLoading.value = false;

    if (resp.statusCode != 200) return;
    final data = jsonDecode(resp.body);
    final results = (data['results'] as List).cast<Map<String, dynamic>>();

    final chunk = <Pokemon>[];
    for (final item in results) {
      final url = item['url'] as String; // .../pokemon/25/
      final id = int.parse(url.split('/').where((s) => s.isNotEmpty).last);
      final name = item['name'] as String;
      final img =
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
      chunk.add(Pokemon(id: id, name: name, imageUrl: img));
    }
    pokemons.addAll(chunk);

    final next = data['next'];
    if (next == null) {
      hasMore.value = false;
    } else {
      nextUrl.value = next as String;
    }
  }

  // ---------- Selection ----------
  void toggle(Pokemon p) {
    final already = selected.contains(p);
    if (already) {
      selected.removeWhere((e) => e.id == p.id);
    } else {
      if (isFull) {
        Get.snackbar('จำกัด 3 ตัว', 'คุณเลือกครบ 3 ตัวแล้ว',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12));
        return;
      }
      selected.add(p);
    }
    _saveDraftToStorage();
  }

  void resetTeam() {
    selected.clear();
    _saveDraftToStorage();
  }

  // ---------- Persistence (draft) ----------
  void _saveDraftToStorage() {
    storage.write('draft_team_members',
        selected.map((e) => e.toJson()).toList());
  }

  void _loadDraftFromStorage() {
    teamNameCtrl.text = storage.read<String>('draft_team_name') ?? '';
    final raw = storage.read<List>('draft_team_members') ?? [];
    final list =
        raw.map((e) => Pokemon.fromJson(Map<String, dynamic>.from(e))).toList();
    selected.assignAll(list);
  }

  // ---------- Save as a team and go to team list ----------
  void confirmTeam() {
    if (!canConfirm) return;

    // สร้างชื่ออัตโนมัติถ้าเว้นว่าง
    final name = (teamNameCtrl.text.trim().isEmpty)
        ? 'Team ${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'
        : teamNameCtrl.text.trim();

    final teams = storage.read<List>('teams') ?? [];
    teams.add({
      'name': name,
      'members': selected.map((e) => e.toJson()).toList(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    storage.write('teams', teams);

    // เคลียร์ draft
    storage.remove('draft_team_name');
    storage.remove('draft_team_members');

    // แจ้งเตือนสั้น ๆ แล้วพาไปหน้ารายการทีม
    Get.snackbar('บันทึกทีมแล้ว', name,
        snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
    Get.offNamed('/teams');
  }

  // ---------- Filter ----------
  List<Pokemon> get filteredList {
    final q = query.value;
    if (q.isEmpty) return pokemons;
    return pokemons.where((p) => p.name.contains(q)).toList();
  }
}

/// ---------- Page ----------
class SelectPlayerPage extends StatelessWidget {
  const SelectPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SelectPlayerController());

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text('เลือกทีม (${c.selected.length}/3)')),
        actions: [
          IconButton(
            tooltip: 'ไปยังทีมของฉัน',
            onPressed: () => Get.toNamed('/teams'),
            icon: const Icon(Icons.groups),
          ),
          IconButton(
            tooltip: 'Reset Team',
            onPressed: c.resetTeam,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: Column(
        children: [
          // Team name + Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: c.teamNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Team name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: c.searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search Pokémon',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selected strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Obx(() {
              final picks = [...c.selected];
              while (picks.length < 3) {
                picks.add(const Pokemon(id: -1, name: '', imageUrl: ''));
              }
              return Row(
                children: List.generate(3, (i) {
                  final p = picks[i];
                  final empty = p.id == -1;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(10),
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: empty ? Colors.grey.shade300 : Colors.indigo,
                          width: 1.4,
                        ),
                        color:
                            empty ? Colors.grey.shade100 : Colors.indigo.shade50,
                      ),
                      child: Center(
                        child: empty
                            ? const Text('ว่าง',
                                style: TextStyle(color: Colors.grey))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(p.imageUrl, width: 40, height: 40),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      p.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blueGrey.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // List + Infinite scroll
          Expanded(
            child: Obx(() {
              final list = c.filteredList;
              return NotificationListener<ScrollNotification>(
                onNotification: (sn) {
                  if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 200) {
                    c.fetchNextPage();
                  }
                  return false;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length + 1, // +1 สำหรับท้ายลิสต์ (loader/end)
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (i == list.length) {
                      return Center(
                        child: Obx(() => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              child: c.hasMore.value
                                  ? (c.isLoading.value
                                      ? const CircularProgressIndicator()
                                      : const SizedBox.shrink())
                                  : const Text('— End —'),
                            )),
                      );
                    }
                    final p = list[i];
                    final isSelected = c.selected.contains(p);
                    final isDisabled = !isSelected && c.isFull;

                    return InkWell(
                      onTap: () => c.toggle(p),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Colors.indigo
                                : (isDisabled
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade400),
                            width: 1.2,
                          ),
                          color: isSelected
                              ? Colors.indigo.withOpacity(0.08)
                              : (isDisabled
                                  ? Colors.grey.shade100
                                  : Colors.white),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                              color: Colors.black.withOpacity(0.06),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Image.network(p.imageUrl, width: 40, height: 40),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.name.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDisabled ? Colors.grey : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected
                                  ? Colors.indigo
                                  : (isDisabled
                                      ? Colors.grey
                                      : Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),

          // Confirm (เอาชื่อโปเกมอนออก)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Obx(() => FilledButton.icon(
                    onPressed: c.canConfirm ? c.confirmTeam : null,
                    icon: const Icon(Icons.check),
                    label: const Text('ยืนยันทีม'),
                  )),
            ),
          ),
        ],
      ),
    );
  }
}
