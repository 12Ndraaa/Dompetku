/**
 * Google Apps Script Web App untuk menerima sync dari Dompetku.
 *
 * Cara pakai singkat:
 * 1) Buka script.google.com -> New project
 * 2) Paste script ini
 * 3) Ganti nilai SECRET di bawah (opsional tapi disarankan)
 * 4) Deploy > New deployment > Web app
 *    - Execute as: Me
 *    - Who has access: Anyone with the link
 * 5) Copy URL web app, lalu tempel ke:
 *    lib/config/google_sheets_sync_config.dart
 */

const SECRET = ''; // samakan dengan GoogleSheetsSyncConfig.secret
const TRANSACTIONS_SHEET = 'Transactions';
const SUMMARY_SHEET = 'Summary';

function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents || '{}');

    if (SECRET && payload.secret !== SECRET) {
      return jsonResponse({ ok: false, message: 'Unauthorized' }, 401);
    }

    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const txSheet = getOrCreateSheet(ss, TRANSACTIONS_SHEET);
    const summarySheet = getOrCreateSheet(ss, SUMMARY_SHEET);

    const tx = Array.isArray(payload.transactions) ? payload.transactions : [];
    const summary = payload.summary || {};

    // Rewrite penuh agar data di sheet selalu identik dengan data app
    txSheet.clearContents();
    txSheet.appendRow([
      'ID',
      'Title',
      'Amount',
      'Type',
      'Category',
      'Account',
      'Date',
    ]);

    if (tx.length > 0) {
      const rows = tx.map((item) => [
        item.id ?? '',
        item.title ?? '',
        item.amount ?? 0,
        item.type ?? '',
        item.category ?? '',
        item.account ?? '',
        item.date ?? '',
      ]);
      txSheet
        .getRange(2, 1, rows.length, rows[0].length)
        .setValues(rows);
    }

    summarySheet.clearContents();
    summarySheet.appendRow(['Metric', 'Value']);
    summarySheet.getRange(2, 1, 6, 2).setValues([
      ['Generated At', payload.generatedAt || ''],
      ['Total Balance', summary.totalBalance ?? 0],
      ['Wallet Balance', summary.walletBalance ?? 0],
      ['ATM/E-Wallet Balance', summary.digitalBalance ?? 0],
      ['Income', summary.income ?? 0],
      ['Expense', summary.expense ?? 0],
    ]);

    return jsonResponse({ ok: true, message: 'Synced', rows: tx.length });
  } catch (err) {
    return jsonResponse({ ok: false, message: String(err) }, 500);
  }
}

function getOrCreateSheet(ss, name) {
  return ss.getSheetByName(name) || ss.insertSheet(name);
}

function jsonResponse(obj, statusCode) {
  return ContentService.createTextOutput(
    JSON.stringify({ statusCode: statusCode || 200, ...obj })
  ).setMimeType(ContentService.MimeType.JSON);
}
