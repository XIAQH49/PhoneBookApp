/**
 * SheetJS xlsx（Community Edition，Apache-2.0）最小类型声明。
 * 仅声明本应用使用的 API；实现见同目录 xlsx.full.min.js。
 * 许可文本见 libs/LICENSE.xlsx.txt。
 */

export interface XlsxWorkSheet {
  [key: string]: Object;
}

export interface XlsxWorkBook {
  SheetNames: string[];
  Sheets: Record<string, XlsxWorkSheet>;
}

export interface XlsxReadOptions {
  type?: string;
}

export interface XlsxWriteOptions {
  type?: string;
  bookType?: string;
}

export interface XlsxToJsonOptions {
  header?: number;
  raw?: boolean;
  defval?: string;
}

export interface XlsxUtils {
  sheet_to_json(ws: XlsxWorkSheet,
    opts?: XlsxToJsonOptions): Array<Array<string | number | boolean | null | undefined>>;
  aoa_to_sheet(rows: Array<Array<string | number | boolean>>): XlsxWorkSheet;
  book_new(): XlsxWorkBook;
  book_append_sheet(wb: XlsxWorkBook, ws: XlsxWorkSheet, name: string): void;
}

export interface XlsxModule {
  read(data: ArrayBuffer | Uint8Array, opts?: XlsxReadOptions): XlsxWorkBook;
  write(wb: XlsxWorkBook, opts?: XlsxWriteOptions): ArrayBuffer;
  utils: XlsxUtils;
}

declare const XLSX: XlsxModule;
export default XLSX;
