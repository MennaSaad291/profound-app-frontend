import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'services/analytics_service.dart';
import 'package:dio/dio.dart';

class FullAnalyticsReportsModule extends StatefulWidget {
  final VoidCallback onBack;
  final String? preSelectedCourse;
  const FullAnalyticsReportsModule({
    super.key,
    required this.onBack,
    this.preSelectedCourse,
  });
  @override
  State<FullAnalyticsReportsModule> createState() =>
      _FullAnalyticsReportsModuleState();
}

class _FullAnalyticsReportsModuleState
    extends State<FullAnalyticsReportsModule> {
  String selectedCourse = 'All Courses';
  String selectedSemester = 'All Semesters';
  String dateRange = 'Current Semester';
  DateTime? fromDate;
  DateTime? toDate;
  bool showFilters = false;
  bool isUploading = false;
  bool showReportConfig = false;
  Map<String, dynamic> performanceDistribution = {};
  Map<String, dynamic> predictionData = {};
  List<Map<String, dynamic>> errorAnalysisData = [];
  List courses = [];
  bool isCoursesLoading = false;
  List<Map<String, dynamic>> departmentBenchmarks = [];
  Map<String, dynamic> correlationData = {};
  bool isLoading = false;
  String selectedFormat = "pdf"; // default
  Map<String, bool> reportConfig = {
    'includeStudentPII': false,
    'includeDepartmentBenchmarks': true,
    'includeErrorAnalysis': true,
    'includePredictiveMetrics': true,
    'includeAttendanceData': true,
    'includeGradeDistribution': true,
  };
  final List<Map<String, String>> reportOptions = [
    {
      'key': 'includeStudentPII',
      'title': 'Include Student PII',
      'subtitle': 'Names, IDs, and Departments',
    },
    {
      'key': 'includeDepartmentBenchmarks',
      'title': 'Department Benchmarks',
      'subtitle': 'Comparative analytics',
    },
    {
      'key': 'includeErrorAnalysis',
      'title': 'Error Analysis Detail',
      'subtitle': 'Common mistakes and patterns',
    },
    {
      'key': 'includePredictiveMetrics',
      'title': 'Predictive Analytics',
      'subtitle': 'AI-powered performance forecasts',
    },
    {
      'key': 'includeAttendanceData',
      'title': 'Attendance Data',
      'subtitle': 'Detailed attendance records',
    },
    {
      'key': 'includeGradeDistribution',
      'title': 'Grade Distribution Charts',
      'subtitle': 'Visual performance breakdowns',
    },
  ];
  int? selectedCourseId;
  @override
  void initState() {
    super.initState();
    fetchCourses();
    fetchInitialAnalytics();
  }

  int? getDays(String range) {
    switch (range) {
      case 'Last 30 Days':
        return 30;
      case 'Last Quarter':
        return 90;
      case 'Academic Year':
        return 365;
      default:
        return null;
    }
  }

  Future<void> fetchInitialAnalytics() async {
    setState(() => isLoading = true);

    final data = await AnalyticsService.getAnalytics(
      courseId: null, // ALL courses
      semester: selectedSemester,
      days: getDays(dateRange),
    );

    setState(() {
      predictionData = Map<String, dynamic>.from(data['prediction'] ?? {});
      performanceDistribution = Map<String, dynamic>.from(
        data['performanceDistribution'] ?? {},
      );
      correlationData = Map<String, dynamic>.from(data['correlation'] ?? {});
      errorAnalysisData = List<Map<String, dynamic>>.from(
        data['errorAnalysis'] ?? [],
      );

      isLoading = false;
    });
  }

  Future<void> fetchCourses() async {
    setState(() => isCoursesLoading = true);

    try {
      final data = await AnalyticsService.getCourses();

      setState(() {
        courses = data;
        isCoursesLoading = false;
      });
    } catch (e) {
      setState(() => isCoursesLoading = false);
      print("Error loading courses: $e");
    }
  }

  Widget _buildUploadSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9333EA), Color(0xFF7E22CE)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.upload, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                "Intelligent Data Upload",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            "Upload grade sheets or attendance files for analytics processing",
            style: TextStyle(
              color: Color.fromARGB(255, 230, 220, 240),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF7E22CE),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            onPressed: isUploading
                ? null
                : () async {
                    setState(() => isUploading = true);

                    try {
                      final result = await AnalyticsService.uploadFile();

                      if (!mounted) return;

                      // user cancelled picker
                      if (result == "cancelled") {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Upload cancelled"),
                            backgroundColor: Colors.orange,
                          ),
                        );

                        return;
                      }

                      // backend returned error
                      if (result.startsWith("error:")) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.replaceFirst("error:", "").trim(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );

                        return;
                      }

                      // refresh analytics after successful upload
                      final analyticsData = await AnalyticsService.getAnalytics(
                        courseId: selectedCourseId,
                        semester: selectedSemester,
                        days: getDays(dateRange),
                      );

                      List<dynamic> benchmarksRaw = [];

                      if (selectedCourseId != null) {
                        benchmarksRaw = await AnalyticsService.getBenchmarks(
                          selectedCourseId!,
                        );
                      }

                      if (!mounted) return;

                      setState(() {
                        predictionData = Map<String, dynamic>.from(
                          analyticsData['prediction'] ?? {},
                        );

                        performanceDistribution = Map<String, dynamic>.from(
                          analyticsData['performanceDistribution'] ?? {},
                        );

                        correlationData = Map<String, dynamic>.from(
                          analyticsData['correlation'] ?? {},
                        );

                        errorAnalysisData = List<Map<String, dynamic>>.from(
                          analyticsData['errorAnalysis'] ?? [],
                        );

                        departmentBenchmarks = List<Map<String, dynamic>>.from(
                          benchmarksRaw,
                        );
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "File uploaded and analytics updated successfully",
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } on FormatException {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Invalid file format. Please upload CSV or Excel file.",
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      String errorMessage = "Upload failed. Please try again.";

                      if (e is DioException) {
                        final statusCode = e.response?.statusCode;
                        final data = e.response?.data;

                        if (data is Map && data['message'] != null) {
                          errorMessage = data['message'];
                        } else if (statusCode == 400) {
                          errorMessage =
                              "Invalid file structure or missing columns.";
                        } else if (statusCode == 401) {
                          errorMessage = "Session expired. Please login again.";
                        } else if (statusCode == 413) {
                          errorMessage = "File size too large.";
                        } else if (statusCode == 415) {
                          errorMessage = "Unsupported file type.";
                        } else if (statusCode == 500) {
                          errorMessage = "Server error while processing file.";
                        }
                      } else {
                        final error = e.toString().toLowerCase();

                        if (error.contains("socket")) {
                          errorMessage = "No internet connection.";
                        } else if (error.contains("timeout")) {
                          errorMessage = "Upload timed out.";
                        }
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => isUploading = false);
                      }
                    }
                  },

            icon: isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.fileSpreadsheet, size: 18),

            label: Text(isUploading ? "Uploading..." : "Upload Excel/CSV File"),
          ),
        ],
      ),
    );
  }
  // Widget _buildUploadSection() {
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 16),
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       gradient: const LinearGradient(
  //         colors: [Color(0xFF9333EA), Color(0xFF7E22CE)],
  //       ),
  //       borderRadius: BorderRadius.circular(16),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: const [
  //             Icon(LucideIcons.upload, color: Colors.white, size: 20),
  //             SizedBox(width: 8),
  //             Text(
  //               "Intelligent Data Upload",
  //               style: TextStyle(fontSize: 16, color: Colors.white),
  //             ),
  //           ],
  //         ),

  //         const SizedBox(height: 8),

  //         const Text(
  //           "Upload existing grade sheets or attendance records for advanced analysis",
  //           style: TextStyle(
  //             color: Color.fromARGB(255, 79, 56, 103),
  //             fontSize: 13,
  //           ),
  //         ),

  //         const SizedBox(height: 12),

  //         ElevatedButton.icon(
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.white,
  //             foregroundColor: const Color(0xFF7E22CE),
  //             minimumSize: const Size(double.infinity, 50),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //           ),

  //           onPressed: isUploading
  //               ? null
  //               : () async {
  //                   setState(() => isUploading = true);

  //                   try {
  //                     final result = await AnalyticsService.uploadFile();

  //                     if (result == "cancelled") {
  //                       if (!mounted) return;

  //                       ScaffoldMessenger.of(context).showSnackBar(
  //                         const SnackBar(
  //                           content: Text("Upload cancelled"),
  //                           backgroundColor: Colors.orange,
  //                         ),
  //                       );

  //                       return;
  //                     }

  //                     // backend returned error
  //                     if (result.startsWith("error")) {
  //                       if (!mounted) return;

  //                       ScaffoldMessenger.of(context).showSnackBar(
  //                         SnackBar(
  //                           content: Text(result.replaceFirst("error:", "")),
  //                           backgroundColor: Colors.red,
  //                         ),
  //                       );

  //                       return;
  //                     }

  //                     // fetch analytics after successful upload
  //                     final data = await AnalyticsService.getAnalytics(
  //                       courseId: selectedCourseId,
  //                       semester: selectedSemester,
  //                       days: getDays(dateRange),
  //                     );

  //                     // validate sections
  //                     final newPrediction = Map<String, dynamic>.from(
  //                       data['prediction'] ?? {},
  //                     );

  //                     final newPerformance = Map<String, dynamic>.from(
  //                       data['performanceDistribution'] ?? {},
  //                     );

  //                     final newCorrelation = Map<String, dynamic>.from(
  //                       data['correlation'] ?? {},
  //                     );

  //                     final newErrors = List<Map<String, dynamic>>.from(
  //                       data['errorAnalysis'] ?? [],
  //                     );
  //                     List<Map<String, dynamic>> newBenchmarks = [];

  //                     if (selectedCourseId != null) {
  //                       final benchmarkResponse =
  //                           await AnalyticsService.getBenchmarks(
  //                             selectedCourseId!,
  //                           );

  //                       newBenchmarks = List<Map<String, dynamic>>.from(
  //                         benchmarkResponse,
  //                       );
  //                     }
  //                     List<String> missingSections = [];

  //                     if (newPrediction.isEmpty) {
  //                       missingSections.add("Prediction");
  //                     }

  //                     if (newPerformance.isEmpty) {
  //                       missingSections.add("Performance Distribution");
  //                     }

  //                     if (newCorrelation.isEmpty) {
  //                       missingSections.add("Correlation Analysis");
  //                     }

  //                     if (newErrors.isEmpty) {
  //                       missingSections.add("Error Analysis");
  //                     }

  //                     if (!mounted) return;

  //                     setState(() {
  //                       predictionData = newPrediction;

  //                       performanceDistribution = newPerformance;

  //                       correlationData = newCorrelation;

  //                       errorAnalysisData = newErrors;
  //                       departmentBenchmarks = newBenchmarks;
  //                     });

  //                     if (missingSections.isEmpty) {
  //                       ScaffoldMessenger.of(context).showSnackBar(
  //                         const SnackBar(
  //                           content: Text(
  //                             "Upload successful and all analytics updated ",
  //                           ),
  //                           backgroundColor: Colors.green,
  //                         ),
  //                       );
  //                     } else {
  //                       ScaffoldMessenger.of(context).showSnackBar(
  //                         SnackBar(
  //                           content: Text(
  //                             "Upload completed but some sections missing: ${missingSections.join(", ")}",
  //                           ),
  //                           backgroundColor: Colors.orange,
  //                         ),
  //                       );
  //                     }
  //                   } on FormatException {
  //                     ScaffoldMessenger.of(context).showSnackBar(
  //                       const SnackBar(
  //                         content: Text(
  //                           "Invalid file format. Please upload CSV or Excel file.",
  //                         ),
  //                         backgroundColor: Colors.red,
  //                       ),
  //                     );
  //                   } catch (e) {
  //                     String errorMessage =
  //                         "Upload failed. Please try again with a valid Excel or CSV file.";

  //                     String extractMessage(dynamic data) {
  //                       if (data == null) return "";

  //                       if (data is String) return data;

  //                       if (data is Map) {
  //                         final detail = data['detail'];

  //                         if (detail is Map) {
  //                           return detail['message'] ??
  //                               detail['error'] ??
  //                               detail.toString();
  //                         }

  //                         return data['message'] ??
  //                             data['error'] ??
  //                             data['detail'] ??
  //                             data.toString();
  //                       }

  //                       return data.toString();
  //                     }

  //                     if (e is DioException) {
  //                       final statusCode = e.response?.statusCode;
  //                       final data = e.response?.data;

  //                       String serverMessage = "";

  //                       if (data is Map) {
  //                         serverMessage =
  //                             data['message'] ?? data['detail'] ?? "";
  //                       } else {
  //                         serverMessage = data.toString();
  //                       }
  //                       if (statusCode == 400) {
  //                         errorMessage = serverMessage.isNotEmpty
  //                             ? serverMessage
  //                             : "Invalid file data. Please check the file content and try again.";
  //                       } else if (statusCode == 401) {
  //                         errorMessage = "Session expired. Please login again.";
  //                       } else if (statusCode == 403) {
  //                         errorMessage =
  //                             "You do not have permission to upload this file.";
  //                       } else if (statusCode == 404) {
  //                         errorMessage =
  //                             "Upload service not found. Please contact support.";
  //                       } else if (statusCode == 413) {
  //                         errorMessage =
  //                             "File size is too large. Please upload a smaller file.";
  //                       } else if (statusCode == 415) {
  //                         errorMessage =
  //                             "Unsupported file type. Please upload Excel or CSV files only.";
  //                       } else if (statusCode == 500) {
  //                         errorMessage =
  //                             "Server error occurred while processing the file.";
  //                       } else {
  //                         errorMessage = serverMessage.isNotEmpty
  //                             ? serverMessage
  //                             : "Unexpected server error occurred.";
  //                       }
  //                     } else {
  //                       final error = e.toString().toLowerCase();

  //                       if (error.contains("socket")) {
  //                         errorMessage =
  //                             "No internet connection. Please check your network.";
  //                       } else if (error.contains("timeout")) {
  //                         errorMessage = "Upload timed out. Please try again.";
  //                       } else if (error.contains("format")) {
  //                         errorMessage =
  //                             "Invalid file format. Please upload CSV or Excel file.";
  //                       }
  //                     }

  //                     if (!mounted) return;

  //                     ScaffoldMessenger.of(context).showSnackBar(
  //                       SnackBar(
  //                         content: Text(errorMessage),
  //                         backgroundColor: Colors.red,
  //                         behavior: SnackBarBehavior.floating,
  //                       ),
  //                     );
  //                   } finally {
  //                     if (mounted) {
  //                       setState(() => isUploading = false);
  //                     }
  //                   }
  //                 },

  //           icon: isUploading
  //               ? const SizedBox(
  //                   width: 18,
  //                   height: 18,
  //                   child: CircularProgressIndicator(strokeWidth: 2),
  //                 )
  //               : const Icon(LucideIcons.fileSpreadsheet, size: 18),

  //           label: Text(isUploading ? "Uploading..." : "Upload Excel/CSV File"),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => showFilters = !showFilters),
            leading: const Icon(LucideIcons.filter, color: Color(0xFF9333EA)),
            title: const Text("Data Filters & Scope"),
            trailing: Icon(
              showFilters ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            ),
          ),
          if (showFilters)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDropdown(
                    "Course",
                    selectedCourse,
                    [
                      'All Courses',
                      ...courses.map((c) => c['display'].toString()),
                    ],
                    (val) {
                      setState(() {
                        selectedCourse = val!;

                        if (val == "All Courses") {
                          selectedCourseId = null;
                        } else {
                          final selected = courses.firstWhere(
                            (c) => c['display'] == val,
                          );
                          selectedCourseId = selected['id'];
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildDropdown(
                    "Semester",
                    selectedSemester,
                    [
                      'All Semesters',
                      'Fall 2025',
                      'Spring 2026',
                      'Summer 2026',
                    ],
                    (val) {
                      setState(() {
                        selectedSemester = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    "Date Range",
                    dateRange,
                    [
                      'Current Semester',
                      'Last 30 Days',
                      'Last Quarter',
                      'Academic Year',
                      'Custom Range',
                    ],
                    (val) {
                      setState(() {
                        dateRange = val!;

                        if (val != 'Custom Range') {
                          fromDate = null;
                          toDate = null;
                        }
                      });
                    },
                  ),

                  if (dateRange == 'Custom Range') ...[
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );

                              if (picked != null) {
                                setState(() {
                                  fromDate = picked;
                                });
                              }
                            },

                            child: Text(
                              fromDate == null
                                  ? "Select Start Date"
                                  : "${fromDate!.year}-${fromDate!.month}-${fromDate!.day}",
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );

                              if (picked != null) {
                                setState(() {
                                  toDate = picked;
                                });
                              }
                            },

                            child: Text(
                              toDate == null
                                  ? "Select End Date"
                                  : "${toDate!.year}-${toDate!.month}-${toDate!.day}",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            setState(() => isLoading = true);

                            try {
                              final analyticsData =
                                  await AnalyticsService.getAnalytics(
                                    courseId: selectedCourseId,
                                    semester: selectedSemester,
                                    days: getDays(dateRange),
                                    fromDate: fromDate?.toIso8601String(),
                                    toDate: toDate?.toIso8601String(),
                                  );

                              List<dynamic> benchmarksRaw = [];

                              if (selectedCourseId != null) {
                                benchmarksRaw =
                                    await AnalyticsService.getBenchmarks(
                                      selectedCourseId!,
                                    );
                              }

                              if (!mounted) return;

                              setState(() {
                                errorAnalysisData =
                                    List<Map<String, dynamic>>.from(
                                      analyticsData['errorAnalysis'] ?? [],
                                    );

                                performanceDistribution =
                                    Map<String, dynamic>.from(
                                      analyticsData['performanceDistribution'] ??
                                          {},
                                    );

                                correlationData = Map<String, dynamic>.from(
                                  analyticsData['correlation'] ?? {},
                                );

                                predictionData = Map<String, dynamic>.from(
                                  analyticsData['prediction'] ?? {},
                                );

                                departmentBenchmarks =
                                    List<Map<String, dynamic>>.from(
                                      benchmarksRaw,
                                    );

                                showFilters = false;
                              });
                            } catch (e) {
                              print(e);
                            }

                            setState(() => isLoading = false);
                          },

                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.filter, size: 18),

                    label: Text(isLoading ? "Applying..." : "Apply Filters"),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9333EA),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E8FF), Colors.white, Color(0xFFFFFBEB)],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUploadSection(),
                    _buildFilterSection(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        "Advanced Analytics & Insights",
                        style: TextStyle(fontSize: 18, color: Colors.black87),
                      ),
                    ),
                    _buildPredictiveChart(),
                    _buildCorrelationChart(),
                    _buildPieChartSection(),
                    _buildErrorAnalysisSection(),
                    _buildBenchmarksSection(),
                    _buildReportConfigSection(),
                    _buildExportButton(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorAnalysisSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFEF2F2), Color(0xFFFFFBEB)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      LucideIcons.alertCircle,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Common Error Analysis",
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "Granular error patterns across all assignments",
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),

          // BODY
          Padding(
            padding: const EdgeInsets.all(16),
            child: errorAnalysisData.isEmpty
                ? const Center(child: Text("No error data available"))
                : Column(
                    children: [
                      ...errorAnalysisData.map(
                        (category) => _buildErrorCategoryCard(category),
                      ),

                      const SizedBox(height: 12),

                      // SizedBox(
                      //   width: double.infinity,
                      //   child: ElevatedButton(
                      //     onPressed: () {},
                      //     style: ElevatedButton.styleFrom(
                      //       backgroundColor: const Color(0xFFFEF2F2),
                      //       foregroundColor: const Color(0xFFB91C1C),
                      //       elevation: 0,
                      //       padding: const EdgeInsets.symmetric(vertical: 14),
                      //     ),
                      //     child: const Text("View Detailed Error Report →"),
                      //   ),
                      // ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCategoryCard(Map<String, dynamic> data) {
    final patterns = List<Map<String, dynamic>>.from(data['patterns'] ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['category'],
                style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
              ),
              Row(
                children: [
                  Text(
                    "${data['total_errors']} errors",
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${data['percentage']}%",
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          ...patterns.map((pattern) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pattern['error_type'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Affected: ${pattern['affected_students']} students",
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${pattern['occurrences']}x",
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBenchmarksSection() {
    final List<Map<String, dynamic>> benchmarks = departmentBenchmarks.isEmpty
        ? []
        : List<Map<String, dynamic>>.from(departmentBenchmarks);

    return _buildCard(
      title: "Department Benchmarks",
      subtitle: "Compare your course performance against department averages",
      icon: LucideIcons.barChart3,
      child: benchmarks.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "No benchmark data available",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: benchmarks.map((benchmark) {
                final String metric = benchmark['metric']?.toString() ?? '';

                final double yourCourse =
                    (benchmark['yourCourse'] as num?)?.toDouble() ?? 0;

                final double department =
                    (benchmark['department'] as num?)?.toDouble() ?? 0;

                final String diff = benchmark['difference']?.toString() ?? '0';

                final bool isPositive = diff.startsWith('+');

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metric, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          _buildBenchmarkBox(
                            "${yourCourse.toStringAsFixed(1)}%",
                            "Your Course",
                            const Color(0xFFF5F3FF),
                            const Color(0xFF7E22CE),
                          ),
                          const SizedBox(width: 6),

                          _buildBenchmarkBox(
                            "${department.toStringAsFixed(1)}%",
                            "Department",
                            const Color(0xFFF9FAFB),
                            const Color(0xFF374151),
                          ),
                          const SizedBox(width: 6),

                          _buildBenchmarkBox(
                            diff.contains('%') ? diff : "$diff%",
                            "Difference",
                            isPositive
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFFEF2F2),
                            isPositive
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB91C1C),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildBenchmarkBox(
    String value,
    String label,
    Color bg,
    Color textColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: textColor, fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 4,
      automaticallyImplyLeading: true,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7E22CE), Color(0xFFD97706)],
          ),
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Profound Data & Reporting",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            "UCD-7 • US-8",
            style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 11),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: widget.onBack,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.jpeg',
                  fit: BoxFit.cover,
                  width: 36,
                  height: 36,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictiveChart() {
    final chart = List<Map<String, dynamic>>.from(
      predictionData['chart'] ?? [],
    );
    final meta = predictionData['meta'] ?? {};

    final double finalPrediction = (meta['final_prediction'] ?? 0).toDouble();

    final int weeks = meta['weeks'] ?? 0;
    final int atRisk = meta['at_risk_students'] ?? 0;

    final String insight =
        "Based on current trends, class average expected to reach "
        "${finalPrediction.toStringAsFixed(0)}% by week $weeks. "
        "Recommend intervention for $atRisk at-risk students to improve trajectory.";

    List<FlSpot> actualSpots = [];
    List<FlSpot> predictedSpots = [];

    for (int i = 0; i < chart.length; i++) {
      final item = chart[i];

      final actual = item['actual'] as num?;
      final predicted = item['predicted'] as num?;

      if (actual != null) {
        actualSpots.add(FlSpot(i.toDouble(), (actual as num).toDouble()));
      }

      if (predicted != null) {
        predictedSpots.add(FlSpot(i.toDouble(), (predicted as num).toDouble()));
      }
    }

    final labels = chart.map((e) => e['label']?.toString() ?? '').toList();
    return _buildCard(
      title: "Predictive Performance Model",
      subtitle:
          "Machine learning predictions based on current performance trends",
      icon: LucideIcons.activity,
      badge: "AI-Powered",
      child: chart.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  "No prediction data available",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      clipData: FlClipData.all(),
                      minY: 0,
                      maxY: 100,

                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (spot) => Colors.white,
                          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              final isActual = barSpot.barIndex == 0;

                              return LineTooltipItem(
                                '${isActual ? "Actual" : "Predicted"}: ${barSpot.y.toInt()}',
                                TextStyle(
                                  color: isActual
                                      ? const Color(0xFF9333EA)
                                      : const Color(0xFFF59E0B),
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),

                      gridData: FlGridData(
                        show: true,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: Color(0xFFF0F0F0),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (value) => const FlLine(
                          color: Color(0xFFF0F0F0),
                          strokeWidth: 1,
                        ),
                      ),

                      titlesData: FlTitlesData(
                        show: true,

                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),

                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),

                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 10,
                            getTitlesWidget: (val, _) => Text(
                              val.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),

                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (val, meta) {
                              final index = val.toInt();

                              if (index < 0 || index >= labels.length) {
                                return const SizedBox.shrink();
                              }

                              final label = labels[index];

                              if (label.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      lineBarsData: [
                        LineChartBarData(
                          spots: actualSpots,
                          isCurved: true,
                          color: const Color(0xFF9333EA),
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF9333EA).withOpacity(0.1),
                          ),
                        ),
                        LineChartBarData(
                          spots: predictedSpots,
                          isCurved: true,
                          color: const Color(0xFFF59E0B),
                          barWidth: 2,
                          dashArray: [5, 5],
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFFF59E0B).withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(
                      "Actual Performance",
                      const Color(0xFF9333EA),
                    ),
                    const SizedBox(width: 20),
                    _buildLegendItem(
                      "Predicted Performance",
                      const Color(0xFFF59E0B),
                      isDashed: true,
                    ),
                  ],
                ),
              ],
            ),

      footer: _buildInsightBox("Prediction Insight", insight),
    );
  }

  Widget _buildCorrelationChart() {
    final List points = correlationData.isEmpty
        ? []
        : correlationData['points'] ?? [];
    final stats = correlationData['stats'] ?? {};
    final double r2 = (stats['r_squared'] ?? 0).toDouble();

    String getStrength(double r2) {
      if (r2 >= 0.7) return "Strong";
      if (r2 >= 0.4) return "Moderate";
      return "Weak";
    }

    final String correlationText =
        "${getStrength(r2)} correlation (R² = ${r2.toStringAsFixed(2)}) "
        "between attendance and final performance";
    return _buildCard(
      title: "Attendance-Grade Correlation",
      subtitle: correlationData.isEmpty ? "Loading..." : correlationText,
      icon: LucideIcons.target,
      child: Column(
        children: [
          SizedBox(
            height: 250,
            child: ScatterChart(
              ScatterChartData(
                minX: 0,
                maxX: 100,
                minY: 0,
                maxY: 100,

                scatterTouchData: ScatterTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipColor: (touchedSpot) => const Color(0xFF111827),
                    getTooltipItems: (ScatterSpot touchedSpot) {
                      return ScatterTooltipItem(
                        "Attendance: ${touchedSpot.x.toInt()}%\n"
                        "Grade: ${touchedSpot.y.toInt()}%",
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Color(0xFFF0F0F0), strokeWidth: 1),
                  getDrawingVerticalLine: (value) =>
                      const FlLine(color: Color(0xFFF0F0F0), strokeWidth: 1),
                ),

                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFD1D5DB)),
                    left: BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                ),

                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),

                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      "Attendance %",
                      style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      getTitlesWidget: (val, _) => Text("${val.toInt()}"),
                    ),
                  ),

                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      "Grade %",
                      style: TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      getTitlesWidget: (val, _) => Text("${val.toInt()}"),
                    ),
                  ),
                ),

                scatterSpots: points.isEmpty
                    ? []
                    : points.map<ScatterSpot>((p) {
                        return ScatterSpot(
                          (p['attendance'] as num).toDouble(),
                          (p['grade'] as num).toDouble(),
                          dotPainter: FlDotCirclePainter(
                            color: const Color(0xFF9333EA).withOpacity(0.7),
                            radius: 5,
                          ),
                        );
                      }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildCorrelationInsight(
                  "Correlation",
                  correlationData.isEmpty
                      ? "Loading..."
                      : correlationData['stats']['label'],
                  const Color(0xFFF5F3FF),
                  const Color(0xFF7E22CE),
                  const Color(0xFFDDD6FE),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCorrelationInsight(
                  "Insight",
                  correlationData.isEmpty ? "" : correlationData['insight'],
                  const Color(0xFFFFFBEB),
                  const Color(0xFFB45309),
                  const Color(0xFFFEF3C7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection() {
    List pieData = [];

    if (performanceDistribution.isNotEmpty) {
      final raw = performanceDistribution as Map<String, dynamic>;

      final colors = [
        const Color(0xFF22C55E), // Excellent
        const Color(0xFF3B82F6), // Good
        const Color(0xFFF59E0B), // Average
        const Color(0xFFEF4444), // At Risk
      ];

      double total = 0;
      raw.forEach((key, value) {
        total += (value as num).toDouble();
      });

      int i = 0;
      raw.forEach((key, value) {
        final count = (value as num).toDouble();

        final percentage = total == 0 ? 0 : (count / total) * 100;

        pieData.add({
          "name": key,
          "value": percentage,
          "count": count,
          "color": colors[i % colors.length],
        });

        i++;
      });
    }

    return _buildCard(
      title: "Performance Distribution",
      icon: LucideIcons.pieChart,
      child: Column(
        children: [
          SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(enabled: false),
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: pieData.isEmpty
                    ? []
                    : pieData.map((data) {
                        return PieChartSectionData(
                          color: data['color'],
                          value: data['value'],
                          title: "${data['value'].toStringAsFixed(1)}%",
                          radius: 90,
                        );
                      }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: pieData.map((item) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item['color'],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${item['name']} (${item['count'].toInt()} students)",
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportConfigSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => showReportConfig = !showReportConfig),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFBEB), Color(0xFFFAF5FF)],
                ),
                borderRadius: showReportConfig
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(
                        LucideIcons.fileText,
                        color: Color(0xFFD97706),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Report Configuration",
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: showReportConfig ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(LucideIcons.chevronDown),
                  ),
                ],
              ),
            ),
          ),

          if (showReportConfig)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Customize what to include in your exported report",
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                  ),

                  const SizedBox(height: 12),

                  ...reportOptions.map((option) {
                    final String key = option['key']!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InkWell(
                        onTap: () => setState(
                          () => reportConfig[key] = !reportConfig[key]!,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: reportConfig[key],
                                activeColor: const Color(0xFF9333EA),
                                onChanged: (val) =>
                                    setState(() => reportConfig[key] = val!),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(option['title']!),
                                    Text(
                                      option['subtitle']!,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: selectedFormat,
                    items: const [
                      DropdownMenuItem(value: "pdf", child: Text("PDF")),
                      DropdownMenuItem(value: "excel", child: Text("Excel")),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedFormat = val!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Export Format",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool isExporting = false;
  Widget _buildExportButton() {
    return ElevatedButton.icon(
      onPressed: isExporting
          ? null
          : () async {
              setState(() => isExporting = true);

              try {
                await AnalyticsService.exportReport(
                  config: reportConfig,
                  format: selectedFormat,
                  courseId: selectedCourseId,
                  semester: selectedSemester,
                  days: getDays(dateRange),
                  fromDate: fromDate?.toIso8601String(),
                  toDate: toDate?.toIso8601String(),
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Downloading ${selectedFormat.toUpperCase()}...",
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }

              setState(() => isExporting = false);
            },
      icon: isExporting
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.download),
      label: Text(
        isExporting
            ? "Generating..."
            : "Generate & Export Format ${selectedFormat.toUpperCase()} Report",
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool isDashed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: isDashed ? 2 : 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    String? subtitle,
    required IconData icon,
    String? badge,
    required Widget child,
    Widget? footer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF9333EA), size: 20),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 15)),
                ],
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFF9333EA),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          child,
          if (footer != null) ...[const SizedBox(height: 12), footer],
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildInsightBox(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.zap, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$title: $body",
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationInsight(
    String title,
    String desc,
    Color bg,
    Color textColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(color: textColor, fontSize: 10)),
        ],
      ),
    );
  }
}
