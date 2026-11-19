package org.shinegame.tiles.gallery;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.File;
import java.io.FileNotFoundException;

/** A read-only provider restricted to temporary shared PNGs. */
public final class GalleryImageProvider extends ContentProvider {
    @Override public boolean onCreate() { return true; }
    private File image(Uri uri) throws FileNotFoundException {
        try {
            if (!getContext().getPackageName().concat(".galleryshare").equals(uri.getAuthority()) || uri.getPathSegments().size() != 2
                || !"images".equals(uri.getPathSegments().get(0))) throw new Exception();
            String name = uri.getLastPathSegment();
            if (name == null || !name.matches("Tiles_[A-Za-z0-9_-]+\\.png")) throw new Exception();
            File folder = new File(getContext().getCacheDir(), "gallery_share").getCanonicalFile();
            File file = new File(folder, name).getCanonicalFile();
            if (!file.getParentFile().equals(folder) || !file.isFile()) throw new Exception();
            return file;
        } catch (Exception error) { throw new FileNotFoundException("Image is unavailable."); }
    }
    @Override public String getType(Uri uri) { return "image/png"; }
    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode)) throw new FileNotFoundException("Read-only image.");
        return ParcelFileDescriptor.open(image(uri), ParcelFileDescriptor.MODE_READ_ONLY);
    }
    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] args, String sort) {
        try {
            File file = image(uri);
            String[] columns = projection == null ? new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE} : projection;
            MatrixCursor cursor = new MatrixCursor(columns, 1);
            Object[] row = new Object[columns.length];
            for (int i=0; i<columns.length; i++) {
                if (OpenableColumns.DISPLAY_NAME.equals(columns[i])) row[i] = file.getName();
                if (OpenableColumns.SIZE.equals(columns[i])) row[i] = file.length();
            }
            cursor.addRow(row);
            return cursor;
        } catch (FileNotFoundException error) { return null; }
    }
    @Override public Uri insert(Uri uri, ContentValues values) { throw new UnsupportedOperationException(); }
    @Override public int delete(Uri uri, String where, String[] args) { throw new UnsupportedOperationException(); }
    @Override public int update(Uri uri, ContentValues values, String where, String[] args) { throw new UnsupportedOperationException(); }
}
