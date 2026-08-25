import 'package:flutter/material.dart';
import 'package:sas_akount_login/screens/cash_bank_entry_screen.dart';

import 'package:sas_akount_login/screens/sale_screen.dart';
import 'package:sas_akount_login/screens/purchase/purchase_screen.dart';
import 'package:sas_akount_login/screens/receivable_screen.dart';
import 'package:sas_akount_login/screens/payable_screen.dart';
import 'package:sas_akount_login/screens/inventory_screen.dart';
import 'package:sas_akount_login/screens/outstanding_screen.dart';
import 'package:sas_akount_login/screens/ageing_screen.dart';
import 'package:sas_akount_login/screens/company_selection_screen.dart';
import 'package:sas_akount_login/screens/ledger_master_screen.dart';
import 'package:sas_akount_login/screens/item_master_screen.dart';
import 'package:sas_akount_login/screens/sales_entry_screen.dart'; // Adjust the path to wherever you saved it!
import 'package:sas_akount_login/screens/purchase_entry_screen.dart';
// (Or import 'package:your_app_name/screens/purchase_entry_screen.dart'; depending on your setup)

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.88,
      backgroundColor: const Color(0xFFF8FAFC),
      child: RepaintBoundary(
        child: Column(
          children: [
            // --- HEADER WITH LOGO ---
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const Text(
                    "v3.1.2",
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                  )
                ],
              ),
            ),
            
            // --- SCROLLABLE CONTENT ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                physics: const BouncingScrollPhysics(), 
                children: <Widget>[
                  
                  // --- SWITCH COMPANY CARD ---
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.swap_horiz, color: Color(0xFF1E3A8A)),
                        ),
                        title: const Text(
                          'Switch Company', 
                          style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: const Text('Tap to change active workspace', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF1E3A8A)),
                        onTap: () {
                          Navigator.pop(context); 
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CompanySelectionScreen()),
                          );
                        },
                      ),
                    ),
                  ),

                  // --- SECTION 1: CORE MODULES ---
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      "BUSINESS MODULES",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
                    ),
                  ),
                  
                  // Chart of Account (Ledger Master & Item Master)
                  buildStyledExpansionTile(
                    context,
                    title: 'Chart of Account',
                    icon: Icons.account_tree_outlined,
                    iconBgColor: Colors.purple.shade50,
                    iconColor: Colors.purple.shade700,
                    items: [
                      {'title': 'Ledger Master', 'page': const LedgerMasterScreen()},
                      {'title': 'Item Master', 'page': const ItemMasterScreen(), 'badge': ''},
                    ],
                  ),
                  const SizedBox(height: 8),

                  buildStyledExpansionTile(
                    context,
                    title: 'Sale Module',
                    icon: Icons.point_of_sale,
                    iconBgColor: Colors.green.shade50,
                    iconColor: Colors.green.shade700,
                    items: [
                      {'title': 'Sales Invoice', 'page': const SaleScreen()},
                      {'title': 'Sales Entry', 'page': const SalesEntryScreen()},
                      {'title': 'Customer List', 'page': const ReceivableScreen()},
                    ],
                  ),
                  const SizedBox(height: 8),

                  buildStyledExpansionTile(
                    context,
                    title: 'Purchase Module',
                    icon: Icons.shopping_bag_outlined,
                    iconBgColor: Colors.orange.shade50,
                    iconColor: Colors.orange.shade700,
                    items: [
                      {'title': 'Purchase Invoice', 'page': const PurchaseScreen()},
                      {'title': 'Purchase Entry', 'page': const PurchaseEntryScreen()},
                      {'title': 'Vendor List', 'page': const PayableScreen()},
                    ],
                  ),

                  const SizedBox(height: 8),

                  buildStyledExpansionTile(
                    context,
                    title: 'Cash/Bank',
                    icon: Icons.attach_money,
                    iconBgColor: Colors.orange.shade50,
                    iconColor: Colors.orange.shade700,
                    items: [
                      {'title': 'Cash/Bank Ac', 'page': const CashBankEntryScreen()},
                      
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- SECTION 2: REPORTS & ANALYTICS ---
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      "REPORTS & INSIGHTS",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
                    ),
                  ),

                  buildStyledExpansionTile(
                    context,
                    title: 'Financial Reports',
                    icon: Icons.bar_chart_rounded,
                    iconBgColor: Colors.blue.shade50,
                    iconColor: Colors.blue.shade700,
                    items: [
                      {'title': 'Receivables', 'page': const ReceivableScreen()},
                      {'title': 'Payables', 'page': const PayableScreen()},
                      {'title': 'Stock Ledger', 'page': const InventoryScreen()},
                      {'title': 'Customer Outstanding', 'page': const OutstandingScreen(), 'badge': 'NEW'},
                      {'title': 'Customer Ageing', 'page': const AgeingScreen()},
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- SECTION 3: SYSTEM SETTINGS ---
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.settings_outlined, color: Colors.black87),
                        ),
                        title: const Text('Settings', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        onTap: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // --- LOGOUT BUTTON AT THE BOTTOM ---
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.white,
                child: Material(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Icon(Icons.logout, color: Colors.red.shade600),
                    title: Text(
                      'Logout',
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODERN CARD EXPANSION TILE BUILDER ---
  Widget buildStyledExpansionTile(
    BuildContext context, {
    required String title, 
    required IconData icon, 
    required Color iconBgColor,
    required Color iconColor,
    required List<Map<String, dynamic>> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor),
            ),
            title: Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 15)),
            iconColor: Colors.black54,
            collapsedIconColor: Colors.grey.shade500,
            childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12), 
            children: items.map((mapItem) {
              return Column(
                children: [
                  const Divider(height: 1, color: Colors.black12),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      title: Text(
                        mapItem['title'], 
                        style: TextStyle(color: Colors.grey.shade800, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (mapItem['badge'] != null && mapItem['badge'].toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: mapItem['badge'] == 'NEW' ? Colors.red.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                mapItem['badge'],
                                style: TextStyle(
                                  fontSize: 10, 
                                  fontWeight: FontWeight.bold, 
                                  color: mapItem['badge'] == 'NEW' ? Colors.red.shade700 : Colors.orange.shade800
                                ),
                              ),
                            ),
                          const Icon(Icons.chevron_right, size: 16, color: Colors.black26),
                        ],
                      ),
                      onTap: () {
                        if (mapItem['page'] != null) {
                          Navigator.pop(context); 
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => mapItem['page']),
                          );
                        }
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}