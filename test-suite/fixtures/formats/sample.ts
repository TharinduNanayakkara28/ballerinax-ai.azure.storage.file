// TypeScript fixture — exercises direct decoding of .ts content by extension.
export const MARKER = "FORMAT_MARKER_TS" as const;

export interface LoadedDocument {
    fileName: string;
    fileSize?: number;
    content: string;
}

export type LoadResult = LoadedDocument | LoadedDocument[];

export function flatten(result: LoadResult): LoadedDocument[] {
    return Array.isArray(result) ? result : [result];
}

export function totalChars(documents: LoadedDocument[]): number {
    return documents.reduce((sum, doc) => sum + doc.content.length, 0);
}
