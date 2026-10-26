import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/app_drawer.dart';
import '../data/uploader_repository.dart';
import '../domain/uploader_models.dart';

class UploaderScreen extends StatefulWidget {
  const UploaderScreen({super.key});

  @override
  State<UploaderScreen> createState() => _UploaderScreenState();
}

class _UploaderScreenState extends State<UploaderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late UploaderRepository _repository;

  // Types
  List<UploadTypeModel> _types = [];
  UploadTypeModel? _selectedType;
  bool _isLoadingTypes = false;

  // File selection
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String _uploadProgressText = '';

  // Active Batch & Polling
  UploadBatchStatus? _currentBatch;
  Timer? _pollingTimer;
  bool _isProcessing = false;

  // Row Results
  List<BatchRowResult> _batchRows = [];
  String _rowFilter = ''; // '', 'Valid', 'Synced', 'Error'
  int _rowsPage = 1;
  final int _rowsPageSize = 50;
  bool _isLoadingRows = false;
  bool _hasMoreRows = true;
  final ScrollController _rowsScrollController = ScrollController();

  // History Tab
  List<UploadBatchStatus> _historyBatches = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _rowsScrollController.addListener(_onRowsScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _repository = UploaderRepository(
        token: auth.accessToken,
        tenantId: auth.tenantId,
      );
      _loadTypes();
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _rowsScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onRowsScroll() {
    if (_rowsScrollController.position.pixels >= _rowsScrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingRows && _hasMoreRows && _currentBatch != null) {
        _loadRows(append: true);
      }
    }
  }

  Future<void> _loadTypes() async {
    setState(() => _isLoadingTypes = true);
    try {
      final types = await _repository.fetchTypes();
      setState(() {
        _types = types;
        if (types.isNotEmpty) {
          _selectedType = types.first;
        }
      });
    } catch (e) {
      _showSnackBar('Error loading upload types: $e', isError: true);
    } finally {
      setState(() => _isLoadingTypes = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (!file.name.toLowerCase().endsWith('.xlsx')) {
          _showSnackBar('Only modern .xlsx files are supported.', isError: true);
          return;
        }
        if (file.size > 50 * 1024 * 1024) {
          _showSnackBar('File size exceeds the 50 MB limit.', isError: true);
          return;
        }
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', isError: true);
    }
  }

  Future<void> _downloadTemplate() async {
    if (_selectedType == null) return;
    try {
      final url = _repository.getTemplateUrl(_selectedType!.code);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not launch template URL', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error downloading template: $e', isError: true);
    }
  }

  Future<void> _uploadAndProcess() async {
    if (_selectedType == null || _selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgressText = 'Staging file into database...';
      _batchRows = [];
    });

    try {
      final batchId = await _repository.uploadExcel(_selectedType!.code, _selectedFile!);
      setState(() {
        _isUploading = false;
        _uploadProgressText = 'Queuing batch validation...';
      });

      await _repository.startProcessing(batchId);
      _startPolling(batchId);
      _loadHistory();
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgressText = '';
      });
      _showSnackBar('Upload failed: $e', isError: true);
    }
  }

  void _startPolling(String batchId) {
    _pollingTimer?.cancel();
    setState(() => _isProcessing = true);

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      try {
        final status = await _repository.getBatchStatus(batchId);
        if (!mounted) return;

        setState(() {
          _currentBatch = status;
        });

        if (status.status == 'Completed' || status.status == 'Failed') {
          timer.cancel();
          setState(() => _isProcessing = false);
          _loadRows(reset: true);
          _loadHistory();
          _showSnackBar(
            status.status == 'Completed'
                ? 'Batch processed: ${status.successRows} synced, ${status.errorRows} errors.'
                : 'Batch processing failed: ${status.errorMessage ?? ""}',
            isError: status.status == 'Failed',
          );
        }
      } catch (_) {
        // continue polling on transient network hitch
      }
    });
  }

  Future<void> _loadRows({bool reset = false, bool append = false}) async {
    if (_currentBatch == null) return;

    if (reset) {
      _rowsPage = 1;
      _hasMoreRows = true;
      setState(() => _batchRows = []);
    } else if (append) {
      _rowsPage++;
    }

    setState(() => _isLoadingRows = true);
    try {
      final rows = await _repository.getBatchRows(
        _currentBatch!.batchId,
        status: _rowFilter.isEmpty ? null : _rowFilter,
        page: _rowsPage,
        pageSize: _rowsPageSize,
      );

      setState(() {
        if (reset) {
          _batchRows = rows;
        } else {
          _batchRows.addAll(rows);
        }
        if (rows.length < _rowsPageSize) {
          _hasMoreRows = false;
        }
      });
    } catch (e) {
      _showSnackBar('Error loading rows: $e', isError: true);
    } finally {
      setState(() => _isLoadingRows = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final list = await _repository.getBatches(page: 1, pageSize: 25);
      setState(() => _historyBatches = list);
    } catch (_) {
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _downloadReport() async {
    if (_currentBatch == null) return;
    try {
      final url = _repository.getReportUrl(_currentBatch!.batchId);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not launch report download', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error downloading report: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<TenantThemeProvider>(context);
    final locale = Provider.of<LocaleProvider>(context);
    final isHindi = locale.isHindi;

    return Scaffold(
      appBar: AppBar(
        title: Text(isHindi ? 'एक्सेल डेटा अपलोडर' : 'Excel Data Uploader'),
        backgroundColor: theme.primaryColor == Colors.white ? const Color(0xFF0F172A) : theme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.secondaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.cloud_upload_rounded),
              text: isHindi ? 'अपलोड और परिणाम' : 'Upload & Results',
            ),
            Tab(
              icon: const Icon(Icons.history_rounded),
              text: isHindi ? 'इतिहास' : 'Batch History',
            ),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUploaderTab(context, theme, isHindi),
          _buildHistoryTab(context, theme, isHindi),
        ],
      ),
    );
  }

  Widget _buildUploaderTab(BuildContext context, TenantThemeProvider theme, bool isHindi) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step 1: Type Selection Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.primaryColor,
                        child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isHindi ? 'अपलोड प्रकार चुनें और टेम्पलेट डाउनलोड करें' : 'Select Upload Type & Template',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingTypes)
                    const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                  else
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<UploadTypeModel>(
                            value: _selectedType,
                            decoration: InputDecoration(
                              labelText: isHindi ? 'प्रकार (Upload Type)' : 'Upload Type',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _types.map((t) {
                              return DropdownMenuItem<UploadTypeModel>(
                                value: t,
                                child: Text('${t.name} (${t.code})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedType = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _selectedType != null ? _downloadTemplate : null,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text(isHindi ? 'टेम्पलेट' : 'Template'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Step 2: File Picker Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.primaryColor,
                        child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isHindi ? 'एक्सेल फाइल चुनें (.xlsx)' : 'Choose Excel File (.xlsx)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _isUploading || _isProcessing ? null : _pickFile,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedFile != null ? Icons.description_rounded : Icons.file_upload_outlined,
                            size: 40,
                            color: _selectedFile != null ? Colors.teal : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFile != null ? _selectedFile!.name : (isHindi ? 'फाइल चुनने के लिए क्लिक करें' : 'Click to select .xlsx file (Max 50MB)'),
                            style: TextStyle(
                              fontWeight: _selectedFile != null ? FontWeight.bold : FontWeight.normal,
                              color: _selectedFile != null ? Colors.black87 : Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_selectedFile != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: (_selectedFile != null && !_isUploading && !_isProcessing) ? _uploadAndProcess : null,
                      icon: _isUploading || _isProcessing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(
                        _isUploading
                            ? _uploadProgressText
                            : (_isProcessing ? (isHindi ? 'प्रोसेसिंग जारी है...' : 'Processing in background...') : (isHindi ? 'अपलोड और सिंक करें' : 'Upload & Sync Data')),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor == Colors.white ? const Color(0xFF0F172A) : theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isUploading || _isProcessing || _currentBatch != null) ...[
            const SizedBox(height: 16),
            _buildBatchProgressCard(context, theme, isHindi),
          ],

          if (_currentBatch != null && (_currentBatch!.status == 'Completed' || _currentBatch!.status == 'Failed')) ...[
            const SizedBox(height: 16),
            _buildResultsSection(context, theme, isHindi),
          ],
        ],
      ),
    );
  }

  Widget _buildBatchProgressCard(BuildContext context, TenantThemeProvider theme, bool isHindi) {
    final batch = _currentBatch;
    final status = batch?.status ?? (_isUploading ? 'Uploading' : 'Queued');

    Color statusColor = Colors.orange;
    if (status == 'Completed') statusColor = Colors.green;
    if (status == 'Failed') statusColor = Colors.red;
    if (status == 'Syncing') statusColor = Colors.blue;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isHindi ? 'बैच स्थिति' : 'Batch Status',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1.2),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isProcessing || _isUploading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            // 3 Summary Cards
            Row(
              children: [
                _buildMetricCard(
                  label: isHindi ? 'कुल पंक्तियाँ' : 'Total Rows',
                  value: '${batch?.totalRows ?? 0}',
                  color: Colors.purple.shade700,
                  icon: Icons.format_list_numbered_rounded,
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  label: isHindi ? 'सफल' : 'Success',
                  value: '${batch?.successRows ?? 0}',
                  color: Colors.green.shade700,
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  label: isHindi ? 'त्रुटि' : 'Error',
                  value: '${batch?.errorRows ?? 0}',
                  color: Colors.red.shade700,
                  icon: Icons.error_outline_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String label, required String value, required Color color, required IconData icon}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection(BuildContext context, TenantThemeProvider theme, bool isHindi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isHindi ? 'पंक्ति परिणाम' : 'Row-wise Results',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _downloadReport,
              icon: const Icon(Icons.table_view_rounded, size: 16),
              label: Text(isHindi ? 'एक्सेल रिपोर्ट' : 'Download Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(isHindi ? 'सभी' : 'All'),
                selected: _rowFilter.isEmpty,
                onSelected: (_) {
                  setState(() => _rowFilter = '');
                  _loadRows(reset: true);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(isHindi ? 'सफल (Valid/Synced)' : 'Valid / Synced'),
                selected: _rowFilter == 'Valid' || _rowFilter == 'Synced',
                onSelected: (_) {
                  setState(() => _rowFilter = 'Synced');
                  _loadRows(reset: true);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(isHindi ? 'त्रुटियाँ (Error)' : 'Error Rows'),
                selected: _rowFilter == 'Error',
                onSelected: (_) {
                  setState(() => _rowFilter = 'Error');
                  _loadRows(reset: true);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Virtualized rows list
        _batchRows.isEmpty
            ? Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: _isLoadingRows
                    ? const CircularProgressIndicator()
                    : Text(isHindi ? 'कोई डेटा नहीं मिला' : 'No rows match filter criteria'),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _batchRows.length + (_hasMoreRows ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _batchRows.length) {
                    return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                  }
                  final row = _batchRows[index];
                  final isErr = row.status == 'Error';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isErr ? Colors.red.shade100 : Colors.green.shade100,
                        child: Icon(
                          isErr ? Icons.close_rounded : Icons.check_rounded,
                          color: isErr ? Colors.red.shade700 : Colors.green.shade700,
                          size: 18,
                        ),
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Row #${row.rowNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              row.keyValue.isNotEmpty ? row.keyValue : '-',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            row.status,
                            style: TextStyle(
                              color: isErr ? Colors.red.shade700 : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      subtitle: (row.message != null && row.message!.isNotEmpty)
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                row.message!,
                                style: TextStyle(color: isErr ? Colors.red.shade800 : Colors.grey.shade700, fontSize: 11.5),
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildHistoryTab(BuildContext context, TenantThemeProvider theme, bool isHindi) {
    if (_isLoadingHistory && _historyBatches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyBatches.isEmpty) {
      return Center(
        child: Text(isHindi ? 'कोई पुराना अपलोड इतिहास नहीं मिला' : 'No previous upload batches found'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _historyBatches.length,
        itemBuilder: (context, index) {
          final b = _historyBatches[index];
          final isSuccess = b.status == 'Completed';
          final isFailed = b.status == 'Failed';

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 1.5,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isSuccess
                    ? Colors.green.shade100
                    : (isFailed ? Colors.red.shade100 : Colors.amber.shade100),
                child: Icon(
                  isSuccess
                      ? Icons.check_circle_outline_rounded
                      : (isFailed ? Icons.error_outline_rounded : Icons.hourglass_top_rounded),
                  color: isSuccess
                      ? Colors.green.shade700
                      : (isFailed ? Colors.red.shade700 : Colors.amber.shade800),
                ),
              ),
              title: Text(
                b.fileName.isNotEmpty ? b.fileName : b.typeCode,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'Type: ${b.typeCode}  |  Total: ${b.totalRows}  (✓ ${b.successRows}  ✗ ${b.errorRows})',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange)).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      b.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSuccess ? Colors.green.shade800 : (isFailed ? Colors.red.shade800 : Colors.orange.shade800),
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  _currentBatch = b;
                  _tabController.animateTo(0);
                });
                _loadRows(reset: true);
              },
            ),
          );
        },
      ),
    );
  }
}
