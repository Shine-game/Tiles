package org.shinegame.tiles.gallery;

import android.Manifest;
import android.app.Activity;
import android.content.ClipData;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Collections;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Local image export only; no network, account access or automatic posting. */
public final class GalleryPlugin extends GodotPlugin {
    private static final int PHOTO_PERMISSION = 7318;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile boolean closed;
    private String pendingPath;
    private String pendingName;

    public GalleryPlugin(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "TilesGallery"; }
    @Override public Set<SignalInfo> getPluginSignals() {
        return Collections.singleton(new SignalInfo("operation_completed", String.class, Boolean.class, String.class));
    }
    private void result(String operation, boolean success, String message) {
        if (!closed) runOnRenderThread(() -> { if (!closed) emitSignal("operation_completed", operation, success, message); });
    }
    private File source(String path) throws Exception {
        File file = new File(path).getCanonicalFile();
        File gallery = new File(getContext().getFilesDir(), "gallery").getCanonicalFile();
        if (!file.getParentFile().equals(gallery) || !file.isFile() || !file.getName().endsWith(".png"))
            throw new IllegalArgumentException("Image is unavailable.");
        return file;
    }
    private String filename(String name) {
        return "Tiles_" + name.replaceAll("[^a-zA-Z0-9_-]", "_") + ".png";
    }
    private static void copy(File from, OutputStream to) throws Exception {
        if (to == null) throw new IllegalStateException("Could not create image.");
        try (InputStream in = new FileInputStream(from); OutputStream out = to) {
            byte[] buffer = new byte[16384];
            int size;
            while ((size = in.read(buffer)) != -1) out.write(buffer, 0, size);
        }
    }
    @UsedByGodot public void save_image(String path, String name) {
        if (Build.VERSION.SDK_INT < 29 && getContext().checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            runOnUiThread(() -> {
                Activity activity = getActivity();
                if (activity == null) { result("save", false, "Could not open Photos."); return; }
                pendingPath = path;
                pendingName = name;
                activity.requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, PHOTO_PERMISSION);
            });
            return;
        }
        save(path, name);
    }
    private void save(String path, String name) {
        worker.execute(() -> {
            Uri created = null;
            ContentResolver resolver = getContext().getContentResolver();
            try {
                File image = source(path);
                if (Build.VERSION.SDK_INT >= 29) {
                    ContentValues values = new ContentValues();
                    values.put(MediaStore.Images.Media.DISPLAY_NAME, filename(name));
                    values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
                    values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Tiles");
                    values.put(MediaStore.Images.Media.IS_PENDING, 1);
                    created = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
                    if (created == null) throw new IllegalStateException("Could not create image.");
                    copy(image, resolver.openOutputStream(created));
                    values.clear();
                    values.put(MediaStore.Images.Media.IS_PENDING, 0);
                    if (resolver.update(created, values, null, null) < 1) throw new IllegalStateException("Could not finish image.");
                } else {
                    File folder = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Tiles");
                    if (!folder.isDirectory() && !folder.mkdirs()) throw new IllegalStateException("Could not open Pictures.");
                    File target = File.createTempFile("Tiles_", ".png", folder);
                    try { copy(image, new FileOutputStream(target)); }
                    catch (Exception error) { target.delete(); throw error; }
                    MediaScannerConnection.scanFile(getContext(), new String[]{target.getAbsolutePath()}, new String[]{"image/png"}, null);
                }
                result("save", true, "Saved to Photos in Pictures/Tiles.");
            } catch (Exception error) {
                if (created != null) { try { resolver.delete(created, null, null); } catch (Exception ignored) {} }
                result("save", false, "Could not save this image to Photos.");
            }
        });
    }
    @Override public void onMainRequestPermissionsResult(int request, String[] permissions, int[] grants) {
        if (request != PHOTO_PERMISSION) return;
        String path = pendingPath, name = pendingName;
        pendingPath = null;
        pendingName = null;
        if (path == null) return;
        if (grants.length > 0 && grants[0] == PackageManager.PERMISSION_GRANTED) save(path, name);
        else result("save", false, "Photo permission was declined. You can still use Share.");
    }
    @UsedByGodot public void share_image(String path, String name) {
        worker.execute(() -> {
            try {
                File image = source(path);
                File folder = new File(getContext().getCacheDir(), "gallery_share");
                if (!folder.isDirectory() && !folder.mkdirs()) throw new IllegalStateException();
                File[] previous = folder.listFiles();
                if (previous != null) for (File old : previous)
                    if (old.lastModified() < System.currentTimeMillis() - 86400000L) old.delete();
                File target = File.createTempFile("Tiles_", ".png", folder);
                copy(image, new FileOutputStream(target));
                Uri uri = new Uri.Builder().scheme("content").authority(getContext().getPackageName() + ".galleryshare")
                    .appendPath("images").appendPath(target.getName()).build();
                runOnUiThread(() -> {
                    try {
                        Activity activity = getActivity();
                        if (activity == null) throw new IllegalStateException();
                        Intent send = new Intent(Intent.ACTION_SEND).setType("image/png")
                            .putExtra(Intent.EXTRA_STREAM, uri)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                        send.setClipData(ClipData.newRawUri("Tiles image", uri));
                        activity.startActivity(Intent.createChooser(send, "Share your design"));
                        result("share", true, "Choose an app to share your design.");
                    } catch (Exception error) { result("share", false, "Could not open the sharing menu."); }
                });
            } catch (Exception error) { result("share", false, "Could not prepare this image for sharing."); }
        });
    }
    @Override public void onMainDestroy() { closed = true; worker.shutdown(); super.onMainDestroy(); }
}
