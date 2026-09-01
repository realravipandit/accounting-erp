// // import 'package:flutter/material.dart';
// // import 'package:sas_app/core/state/global.dart';
// // import 'package:sas_app/models/purchase/purchase.dart';
// // import 'package:sas_app/models/sales/sales.dart';

// // class SearchScreen extends StatefulWidget {
// //   const SearchScreen({super.key});

// //   @override
// //   SearchScreenState createState() => SearchScreenState();
// // }

// // class SearchScreenState extends State<SearchScreen> {
// //   final TextEditingController _searchController = TextEditingController();
// //   List<dynamic> _searchResults = [];

// //   @override
// //   void initState() {
// //     super.initState();
// //     _searchResults = [...Global.sales, ...Global.purchases];
// //   }

// //   void _performSearch(String query) {
// //     if (query.isEmpty) {
// //       setState(() => _searchResults = [...Global.sales, ...Global.purchases]);
// //       return;
// //     }

// //     final lowerQuery = query.toLowerCase();
// //     setState(() {
// //       _searchResults = [
// //         ...Global.sales.where((sale) =>
// //             sale.customerName?.toLowerCase().contains(lowerQuery) == true ||
// //             sale.invoiceNumber?.toLowerCase().contains(lowerQuery) == true),
// //         ...Global.purchases.where((purchase) =>
// //             purchase.supplierName?.toLowerCase().contains(lowerQuery) == true ||
// //             purchase.invoiceNumber?.toLowerCase().contains(lowerQuery) == true),
// //       ];
// //     });
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: TextField(
// //           controller: _searchController,
// //           autofocus: true,
// //           decoration: const InputDecoration(
// //             hintText: 'Search sales, purchases...',
// //             border: InputBorder.none,
// //           ),
// //           onChanged: _performSearch,
// //         ),
// //         actions: [
// //           IconButton(
// //             icon: const Icon(Icons.clear),
// //             onPressed: () {
// //               _searchController.clear();
// //               _performSearch('');
// //             },
// //           ),
// //         ],
// //       ),
// //       body: ListView.builder(
// //         itemCount: _searchResults.length,
// //         itemBuilder: (context, index) {
// //           final item = _searchResults[index];
// //           return ListTile(
// //             title: Text(item.customerName ?? item.supplierName ?? 'Unknown'),
// //             subtitle: Text(item.invoiceNumber ?? 'No Invoice'),
// //             trailing: Text('Rs. ${item.totalAmount?.toStringAsFixed(2)}'),
// //             onTap: () {
// //               // Implement navigation to details
// //             },
// //           );
// //         },
// //       ),
// //     );
// //   }
// // }

// import 'package:flutter/material.dart';
// import 'package:sas_app/core/state/global.dart';
// import 'package:sas_app/models/sales/sales.dart';

// class SearchScreen extends StatefulWidget {
//   const SearchScreen({super.key});

//   @override
//   SearchScreenState createState() => SearchScreenState();
// }

// class SearchScreenState extends State<SearchScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   List<dynamic> _searchResults = [];

//   @override
//   void initState() {
//     super.initState();
//     _searchResults = [...Global.sales, ...Global.purchases];
//   }

//   void _performSearch(String query) {
//     if (query.isEmpty) {
//       setState(() => _searchResults = [...Global.sales, ...Global.purchases]);
//       return;
//     }

//     final lowerQuery = query.toLowerCase();
//     setState(() {
//       _searchResults = [
//         ...Global.sales.where((sale) =>
//             (sale.customerName?.toLowerCase().contains(lowerQuery) ?? false) ||
//             (sale.invoiceNumber?.toLowerCase().contains(lowerQuery) ?? false)),
//         ...Global.purchases.where((purchase) =>
//             (purchase.supplierName?.toLowerCase().contains(lowerQuery) ??
//                 false) ||
//             (purchase.invoiceNumber?.toLowerCase().contains(lowerQuery) ??
//                 false)),
//       ];
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: TextField(
//           controller: _searchController,
//           autofocus: true,
//           decoration: const InputDecoration(
//             hintText: 'Search sales, purchases...',
//             border: InputBorder.none,
//           ),
//           onChanged: _performSearch,
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.clear),
//             onPressed: () {
//               _searchController.clear();
//               _performSearch('');
//             },
//           ),
//         ],
//       ),
//       body: ListView.builder(
//         itemCount: _searchResults.length,
//         itemBuilder: (context, index) {
//           final item = _searchResults[index];
//           return ListTile(
//             title: Text(item is Sales
//                 ? item.customerName ?? 'Unknown Customer'
//                 : item.supplierName ?? 'Unknown Supplier'),
//             subtitle: Text(item.invoiceNumber ?? 'No Invoice'),
//             trailing: Text('Rs. ${item.totalAmount?.toStringAsFixed(2)}'),
//             onTap: () {
//               // Implement navigation to details
//             },
//           );
//         },
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:sas_app/core/state/global.dart';
import 'package:sas_app/models/sales/sales.dart';
// import 'package:sas_app/models/purchase/purchase.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchResults = [...Global.sales, ...Global.purchases];
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = [...Global.sales, ...Global.purchases]);
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _searchResults = [
        ...Global.sales.where((sale) =>
            (sale.customerName?.toLowerCase().contains(lowerQuery) ?? false) ||
            (sale.invoiceNumber?.toLowerCase().contains(lowerQuery) ?? false)),
        ...Global.purchases.where((purchase) =>
            (purchase.supplierName?.toLowerCase().contains(lowerQuery) ??
                false) ||
            (purchase.invoiceNumber?.toLowerCase().contains(lowerQuery) ??
                false)),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search sales, purchases...',
            border: InputBorder.none,
          ),
          onChanged: _performSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _performSearch('');
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          return ListTile(
            title: Text(item is Sales
                ? item.customerName ?? 'Unknown Customer'
                : item.supplierName ?? 'Unknown Supplier'),
            subtitle: Text(item.invoiceNumber ?? 'No Invoice'),
            trailing: Text('Rs. ${item.totalAmount?.toStringAsFixed(2)}'),
            onTap: () {
              // Implement navigation to details
            },
          );
        },
      ),
    );
  }
}

