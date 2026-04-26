import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/admin_data_table.dart';

void main() {
  testWidgets('AdminDataTable renders readable headers and row content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: SizedBox(
              width: 900,
              height: 420,
              child: AdminDataTable(
                minWidth: 640,
                columns: <DataColumn>[
                  DataColumn(
                    label: AdminDataTable.headerLabel(
                      context,
                      'Patient',
                      width: 220,
                    ),
                  ),
                  DataColumn(
                    label: AdminDataTable.headerLabel(
                      context,
                      'Status',
                      width: 110,
                      alignment: Alignment.center,
                    ),
                  ),
                ],
                rows: <DataRow>[
                  DataRow.byIndex(
                    index: 0,
                    color: AdminDataTable.rowColor(context, 0),
                    cells: <DataCell>[
                      DataCell(
                        AdminDataTable.cellText(
                          context,
                          'Ava Stone',
                          width: 220,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      DataCell(
                        AdminDataTable.cellText(
                          context,
                          'Approved',
                          width: 110,
                          alignment: Alignment.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('PATIENT'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('Ava Stone'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);

    final DataTable table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.headingRowHeight, 60);
    expect(table.dataRowMinHeight, 72);
    expect(table.dataRowMaxHeight, 84);
  });
}
