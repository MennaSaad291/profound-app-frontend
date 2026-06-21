import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';

class ResearchOrganizerScreen extends StatefulWidget {
  const ResearchOrganizerScreen({super.key});
  @override
  State<ResearchOrganizerScreen> createState() =>
      _ResearchOrganizerScreenState();
}

class _ResearchOrganizerScreenState extends State<ResearchOrganizerScreen>
    with SingleTickerProviderStateMixin {
  static const _base = 'http://127.0.0.1:8000';
  bool _isLoading = true;
  int? _userId;
  List<Map<String, dynamic>> _pubs = [];
  List<Map<String, dynamic>> _projs = [];
  List<String> _interests = [];
  List<Map<String, dynamic>> _lit = [];
  List<Map<String, dynamic>> _deadlines = [];
  Map<String, dynamic> _stats = {};
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    // FIX: Look up 'userId' to perfectly align with what your sidebar MainLayout passes!
    final raw = args?['userId'] ?? args?['user_id'] ?? args?['id'];
    final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (id != null && _userId == null) {
      _userId = id;
      _load();
    }
  }

  Future<void> _load() async {
    if (_userId == null) return;
    setState(() => _isLoading = true);
    try {
      final r = await http.get(Uri.parse('$_base/research/$_userId'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200 && mounted) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() {
          _pubs      = List<Map<String, dynamic>>.from(d['publications'] ?? []);
          _projs     = List<Map<String, dynamic>>.from(d['projects'] ?? []);
          _interests = List<String>.from(d['interests'] ?? []);
          _lit       = List<Map<String, dynamic>>.from(d['literature'] ?? []);
          _deadlines = List<Map<String, dynamic>>.from(d['deadlines'] ?? []);
          _stats     = Map<String, dynamic>.from(d['stats'] ?? {});
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Color & UI helpers
  Color _sc(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'drafting': case 'ongoing': case 'in progress': return const Color(0xFF1D4ED8);
      case 'under-review': case 'under review': return const Color(0xFFB45309);
      case 'submitted': return const Color(0xFF7E22CE);
      case 'published': case 'completed': return const Color(0xFF15803D);
      default: return Colors.grey;
    }
  }

  Color _sb(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'drafting': case 'ongoing': case 'in progress': return const Color(0xFFEFF6FF);
      case 'under-review': case 'under review': return const Color(0xFFFFFBEB);
      case 'submitted': return const Color(0xFFFAF5FF);
      case 'published': case 'completed': return const Color(0xFFF0FDF4);
      default: return Colors.grey.shade100;
    }
  }

  Color _rc(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'reading': return const Color(0xFF1D4ED8);
      case 'read': return const Color(0xFF15803D);
      default: return Colors.grey.shade700;
    }
  }

  Color _rb(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'reading': return const Color(0xFFEFF6FF);
      case 'read': return const Color(0xFFF0FDF4);
      default: return Colors.grey.shade100;
    }
  }

  InputDecoration _dec(String l) => InputDecoration(
      labelText: l,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10));

  Widget _tf(TextEditingController c, String l, {TextInputType? kb, int ml = 1}) =>
      TextField(controller: c, keyboardType: kb, maxLines: ml, decoration: _dec(l));

  // ── Publication dialog ───────────────────────────────────────────────────────
  void _showPubDialog({Map<String, dynamic>? e}) {
    final tC = TextEditingController(text: e?['title'] ?? '');
    final jC = TextEditingController(text: e?['journal'] ?? '');
    final yC = TextEditingController(text: e?['year']?.toString() ?? '2026');
    final cC = TextEditingController(text: e?['citations']?.toString() ?? '0');
    final edit = e != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(edit ? 'Edit Publication' : 'Add Publication', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
            if (edit) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async {
              await http.delete(Uri.parse('$_base/publications/${e['id']}'));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]),
          const SizedBox(height: 12),
          _tf(tC, 'Title'), const SizedBox(height: 8),
          _tf(jC, 'Journal / Conference'), const SizedBox(height: 8),
          Row(children: [Expanded(child: _tf(yC, 'Year', kb: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _tf(cC, 'Citations', kb: TextInputType.number))]),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, minimumSize: const Size(double.infinity, 48)),
            onPressed: () async {
              final body = jsonEncode({'user_id': _userId, 'title': tC.text.trim(), 'journal': jC.text.trim(), 'year': int.tryParse(yC.text) ?? 2026, 'citations': int.tryParse(cC.text) ?? 0});
              if (edit) {
                await http.put(Uri.parse('$_base/publications/${e['id']}'), headers: {'Content-Type': 'application/json'}, body: body);
              } else {
                await http.post(Uri.parse('$_base/publications'), headers: {'Content-Type': 'application/json'}, body: body);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: Text(edit ? 'Save Changes' : 'Add Publication', style: const TextStyle(color: Colors.white)),
          ), const SizedBox(height: 12),
        ]),
      ),
    );
  }

  // ── Project dialog ───────────────────────────────────────────────────────────
  void _showProjDialog({Map<String, dynamic>? e}) {
    final tC = TextEditingController(text: e?['title'] ?? '');
    final tmC = TextEditingController(text: e?['team'] ?? '');
    final yC = TextEditingController(text: e?['year'] ?? '2025-2026');
    final dC = TextEditingController(text: e?['deadline'] ?? '');
    double prog = ((e?['progress'] ?? 0) as num).toDouble();
    String status = e?['status'] ?? 'ongoing';
    final edit = e != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(edit ? 'Edit Project' : 'Add Research Project', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
            if (edit) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async {
              await http.delete(Uri.parse('$_base/projects/${e['id']}'));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]),
          const SizedBox(height: 12),
          _tf(tC, 'Title'), const SizedBox(height: 8),
          _tf(tmC, 'Collaborators (comma separated)'), const SizedBox(height: 8),
          Row(children: [Expanded(child: _tf(yC, 'Year')), const SizedBox(width: 8), Expanded(child: _tf(dC, 'Deadline (YYYY-MM-DD)'))]),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: status, decoration: _dec('Status'),
              items: ['ongoing','drafting','submitted','under-review','published'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => ss(() => status = v ?? status)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Progress', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
            Text('${prog.toInt()}%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
          ]),
          Slider(value: prog, min: 0, max: 100, divisions: 20, activeColor: AppColors.primaryPurple, onChanged: (v) => ss(() => prog = v)),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, minimumSize: const Size(double.infinity, 48)),
            onPressed: () async {
              final body = jsonEncode({'user_id': _userId, 'title': tC.text.trim(), 'team': tmC.text.trim(), 'year': yC.text.trim(), 'status': status, 'deadline': dC.text.trim().isEmpty ? null : dC.text.trim(), 'progress': prog.toInt()});
              if (edit) {
                await http.put(Uri.parse('$_base/projects/${e['id']}'), headers: {'Content-Type': 'application/json'}, body: body);
              } else {
                await http.post(Uri.parse('$_base/projects'), headers: {'Content-Type': 'application/json'}, body: body);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: Text(edit ? 'Save Changes' : 'Add Project', style: const TextStyle(color: Colors.white)),
          ), const SizedBox(height: 12),
        ])),
      )),
    );
  }

  // ── Literature dialog ────────────────────────────────────────────────────────
  void _showLitDialog({Map<String, dynamic>? e}) {
    final tC = TextEditingController(text: e?['title'] ?? '');
    final fC = TextEditingController(text: e?['citation_format'] ?? 'APA');
    String rs = e?['read_status'] ?? 'to-read';
    final edit = e != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(edit ? 'Edit Paper' : 'Add Literature', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
            if (edit) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async {
              await http.delete(Uri.parse('$_base/literature-papers/${e['id']}'));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]),
          const SizedBox(height: 12),
          _tf(tC, 'Paper Title', ml: 2), const SizedBox(height: 8),
          _tf(fC, 'Citation Format (APA / IEEE / MLA)'), const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: rs, decoration: _dec('Read Status'),
              items: ['to-read','reading','read'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => ss(() => rs = v ?? rs)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, minimumSize: const Size(double.infinity, 48)),
            onPressed: () async {
              final body = jsonEncode({'user_id': _userId, 'title': tC.text.trim(), 'citation_format': fC.text.trim(), 'read_status': rs});
              if (edit) {
                await http.put(Uri.parse('$_base/literature-papers/${e['id']}'), headers: {'Content-Type': 'application/json'}, body: body);
              } else {
                await http.post(Uri.parse('$_base/literature-papers'), headers: {'Content-Type': 'application/json'}, body: body);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: Text(edit ? 'Save Changes' : 'Add Paper', style: const TextStyle(color: Colors.white)),
          ), const SizedBox(height: 12),
        ]),
      )),
    );
  }

  // ── Interest dialog ──────────────────────────────────────────────────────────
  void _showInterestDialog() {
    final c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Add Research Interest', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      content: TextField(controller: c, decoration: _dec('Interest')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
          onPressed: () async {
            if (c.text.trim().isEmpty) return;
            await http.post(Uri.parse('$_base/interests'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': _userId, 'name': c.text.trim()}));
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFF3E5F5), Colors.white, Color(0xFFFFF8E1)])),
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _dashboard(),
                    const SizedBox(height: 16),
                    if (_deadlines.isNotEmpty) ...[_upcomingDeadlines(), const SizedBox(height: 16)],
                    _tabSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────
  Widget _dashboard() {
    final pubs  = _stats['total_publications'] ?? 0;
    final cits  = _stats['total_citations'] ?? 0;
    final projs = _stats['active_projects'] ?? 0;
    final inp   = _stats['in_progress'] ?? 0;
    final rev   = _stats['under_review'] ?? 0;
    final pub   = _projs.where((p) => ['published','completed'].contains((p['status'] ?? '').toLowerCase())).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Research Dashboard', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('${_pubs.length + _projs.length} total', style: GoogleFonts.inter(color: Colors.white, fontSize: 11))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _stat(pubs.toString(), 'Publications', Icons.menu_book_rounded),
            _stat(cits.toString(), 'Citations', Icons.format_quote_rounded),
            _stat(projs.toString(), 'Projects', Icons.science_outlined),
            _stat(pub.toString(), 'Published', Icons.check_circle_outline),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Projects Pipeline', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 14),
          _bar('In Progress', inp, projs, const Color(0xFF1D4ED8)),
          const SizedBox(height: 8),
          _bar('Under Review', rev, projs, const Color(0xFFB45309)),
          const SizedBox(height: 8),
          _bar('Published', pub, projs, const Color(0xFF15803D)),
        ]),
      ),
      if (_pubs.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
          child: Row(children: [
            Container(width: 52, height: 52,
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.format_quote_rounded, color: Color(0xFF166534), size: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$cits Total Citations', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Across $pubs publication${pubs == 1 ? '' : 's'}', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Most cited', style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 10)),
              SizedBox(width: 100, child: Text(_mostCited(), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 2, textAlign: TextAlign.end)),
            ]),
          ]),
        ),
      ],
    ]);
  }

  String _mostCited() {
    if (_pubs.isEmpty) return '—';
    final s = List<Map<String, dynamic>>.from(_pubs)..sort((a, b) => ((b['citations'] ?? 0) as num).compareTo((a['citations'] ?? 0) as num));
    return s.first['title'] ?? '—';
  }

  Widget _stat(String v, String l, IconData icon) => Expanded(child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 3),
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.white70, size: 16), const SizedBox(height: 6),
      Text(v, style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(l, style: GoogleFonts.inter(color: Colors.white70, fontSize: 9)),
    ]),
  ));

  Widget _bar(String label, int count, int total, Color color) {
    final frac = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
        Text('$count / $total', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
          value: frac, minHeight: 7,
          backgroundColor: color.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation<Color>(color))),
    ]);
  }

  // ── Upcoming Deadlines ───────────────────────────────────────────────────────
  Widget _upcomingDeadlines() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
        const SizedBox(width: 8),
        Text('Upcoming Deadlines', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF991B1B))),
      ]),
      const SizedBox(height: 12),
      ..._deadlines.map((d) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(d['title'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF991B1B)))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(d['date'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C))),
            if (d['days_left'] != null) Text('${d['days_left']} days left', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFDC2626))),
          ]),
        ]),
      )),
    ]),
  );

  // ── Tab section ───────────────────────────────────────────────────────────
  Widget _tabSection() => Column(children: [
    Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: TabBar(
        controller: _tabs,
        labelColor: Colors.white, unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(color: AppColors.primaryPurple, borderRadius: BorderRadius.circular(10)),
        indicatorSize: TabBarIndicatorSize.tab,
        padding: const EdgeInsets.all(4),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        tabs: const [Tab(text: 'Publications'), Tab(text: 'Projects'), Tab(text: 'Literature'), Tab(text: 'Interests')],
      ),
    ),
    const SizedBox(height: 12),
    // FIX: Dynamic fallback limits prevent rendering errors if lists are fully empty
    SizedBox(
      height: [180.0 + _pubs.length * 135.0, 180.0 + _projs.length * 210.0, 180.0 + _lit.length * 110.0, 240.0]
          .reduce((a, b) => a > b ? a : b).clamp(280.0, 4500.0),
      child: TabBarView(controller: _tabs, children: [_pubsTab(), _projsTab(), _litTab(), _interestsTab()]),
    ),
  ]);

  // ── Publications tab ─────────────────────────────────────────────────────────
  Widget _pubsTab() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('${_pubs.length} paper${_pubs.length == 1 ? '' : 's'}', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
      ElevatedButton.icon(onPressed: () => _showPubDialog(),
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), elevation: 0)),
    ]),
    const SizedBox(height: 10),
    if (_pubs.isEmpty) _empty('No publications yet.\nTap Add to record your first paper.', Icons.menu_book_rounded)
    else ..._pubs.map((p) => _pubCard(p)),
  ]);

  Widget _pubCard(Map<String, dynamic> p) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(p['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, height: 1.4))),
        IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryPurple),
            onPressed: () => _showPubDialog(e: p), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
      const SizedBox(height: 4),
      Text('${p['journal'] ?? ''} • ${p['year'] ?? ''}', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
      const SizedBox(height: 10),
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.format_quote, size: 14, color: Color(0xFF166534)), const SizedBox(width: 4),
              Text('${p['citations'] ?? 0} citations', style: GoogleFonts.inter(color: const Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.bold)),
            ])),
        const Spacer(),
        GestureDetector(
          onTap: () => _editCitations(p),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.edit, size: 12, color: Color(0xFF1D4ED8)), const SizedBox(width: 4),
                Text('Edit Citations', style: GoogleFonts.inter(color: const Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.w600)),
              ])),
        ),
      ]),
    ]),
  );

  void _editCitations(Map<String, dynamic> pub) {
    final c = TextEditingController(text: pub['citations']?.toString() ?? '0');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Update Citations', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(pub['title'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 12),
        TextField(controller: c, keyboardType: TextInputType.number, decoration: _dec('Number of Citations')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
          onPressed: () async {
            await http.put(Uri.parse('$_base/publications/${pub['id']}'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({...pub, 'citations': int.tryParse(c.text) ?? 0}));
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          },
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  // ── Projects tab ──────────────────────────────────────────────────────────────
  Widget _projsTab() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('${_projs.length} project${_projs.length == 1 ? '' : 's'}', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
      ElevatedButton.icon(onPressed: () => _showProjDialog(),
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), elevation: 0)),
    ]),
    const SizedBox(height: 10),
    if (_projs.isEmpty) _empty('No research projects yet.\nTap Add to record a project.', Icons.science_outlined)
    else ..._projs.map((p) => _projCard(p)),
  ]);

  Widget _projCard(Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? '';
    final team = (p['team']?.toString() ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final prog = ((p['progress'] ?? 0) as num).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(p['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, height: 1.4))),
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _sb(status), borderRadius: BorderRadius.circular(20), border: Border.all(color: _sc(status).withOpacity(0.3))),
              child: Text(status.replaceAll('-', ' '), style: GoogleFonts.inter(color: _sc(status), fontSize: 10, fontWeight: FontWeight.w600))),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryPurple),
              onPressed: () => _showProjDialog(e: p), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
        const SizedBox(height: 6),
        Text(p['year']?.toString() ?? '', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11)),
        if (team.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: team.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(12)),
              child: Text(t, style: GoogleFonts.inter(fontSize: 10, color: AppColors.primaryPurple)))).toList()),
        ],
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Progress', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
          Text('${prog.toInt()}%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
            value: prog / 100, minHeight: 6,
            backgroundColor: AppColors.primaryPurple.withOpacity(0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple))),
        if ((p['deadline'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.schedule, size: 12, color: Color(0xFFDC2626)), const SizedBox(width: 4),
            Text('Deadline: ${p['deadline']}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFDC2626))),
          ]),
        ],
      ]),
    );
  }

  // ── Literature tab ────────────────────────────────────────────────────────────
  Widget _litTab() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('${_lit.length} paper${_lit.length == 1 ? '' : 's'}', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
      ElevatedButton.icon(onPressed: () => _showLitDialog(),
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), elevation: 0)),
    ]),
    const SizedBox(height: 10),
    if (_lit.isEmpty) _empty('No literature saved yet.\nTap Add to track papers you are reading.', Icons.library_books_outlined)
    else ..._lit.map((item) => _litCard(item)),
  ]);

  Widget _litCard(Map<String, dynamic> item) {
    final rs = item['read_status']?.toString() ?? 'to-read';
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, height: 1.4))),
          GestureDetector(onTap: () => _showLitDialog(e: item), child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primaryPurple)),
          const SizedBox(width: 8),
          GestureDetector(
              onTap: () async {
                await http.delete(Uri.parse('$_base/literature-papers/${item['id']}'));
                _load();
              },
              child: const Icon(Icons.delete_outline, size: 16, color: Colors.red)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _rb(rs), borderRadius: BorderRadius.circular(12)),
              child: Text(rs.replaceAll('-', ' '), style: GoogleFonts.inter(color: _rc(rs), fontSize: 10, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          if ((item['citation_format'] ?? '').toString().isNotEmpty)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(12)),
                child: Text(item['citation_format'] ?? '', style: GoogleFonts.inter(color: AppColors.primaryPurple, fontSize: 10, fontWeight: FontWeight.w600))),
        ]),
      ]),
    );
  }

  // ── Interests tab ─────────────────────────────────────────────────────────────
  Widget _interestsTab() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('${_interests.length} interest${_interests.length == 1 ? '' : 's'}', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
      ElevatedButton.icon(onPressed: _showInterestDialog,
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), elevation: 0)),
    ]),
    const SizedBox(height: 12),
    if (_interests.isEmpty) _empty('No interests added yet.\nTap Add to list your research areas.', Icons.interests_outlined)
    else Wrap(spacing: 8, runSpacing: 8, children: _interests.map((i) => Chip(
      label: Text(i, style: GoogleFonts.inter(color: AppColors.primaryPurple, fontSize: 12, fontWeight: FontWeight.w500)),
      backgroundColor: const Color(0xFFF5F3FF),
      side: const BorderSide(color: Color(0xFFD8B4FE)),
      deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primaryPurple),
      onDeleted: () async {
        await http.delete(Uri.parse('$_base/interests/$_userId/${Uri.encodeComponent(i)}'));
        _load();
      },
    )).toList()),
  ]);

  // ── Empty state ───────────────────────────────────────────────────────────────
  Widget _empty(String msg, IconData icon) => Center(
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13, height: 1.6)),
        ])),
  );
}