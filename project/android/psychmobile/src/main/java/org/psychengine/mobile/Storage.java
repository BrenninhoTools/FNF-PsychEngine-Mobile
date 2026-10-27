package org.psychengine.mobile;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.StatFs;
import android.provider.Settings;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import org.haxe.extension.Extension;

public class Storage
{
	public static final String FOLDER = ".PsychEngine";
	public static final String TYPE_DATA = "Data";
	public static final String TYPE_MEDIA = "Media";
	public static final String TYPE_EXTERNAL = "External";
	public static final String TYPE_OBB = "Obb";

	private static final String TYPE_MARKER = ".storage_type";
	private static final String LEGACY_EXTERNAL_MARKER = ".use_external";
	private static final String PROBE = ".psych_probe";
	private static final int BUFFER_SIZE = 262144;

	public static File getAppDir(Context context)
	{
		File dir = context.getExternalFilesDir(null);
		if (dir == null) dir = context.getFilesDir();
		return dir;
	}

	public static File getMediaDir(Context context)
	{
		if (Build.VERSION.SDK_INT >= 21)
		{
			File[] dirs = context.getExternalMediaDirs();
			if (dirs != null)
			{
				for (File dir : dirs)
				{
					if (dir == null) continue;
					if (isWritable(dir)) return dir;
				}
			}
		}
		return null;
	}

	public static boolean isWritable(File dir)
	{
		if (dir == null) return false;
		if (!dir.exists() && !dir.mkdirs()) return false;
		if (!dir.isDirectory()) return false;
		File probe = new File(dir, PROBE);
		try
		{
			FileOutputStream output = new FileOutputStream(probe);
			output.write(1);
			output.close();
			probe.delete();
			return true;
		}
		catch (Exception e)
		{
			probe.delete();
			return false;
		}
	}

	public static boolean isWritable(String path)
	{
		return path != null && path.length() > 0 && isWritable(new File(path));
	}

	public static File getPublicDir()
	{
		return new File(Environment.getExternalStorageDirectory(), FOLDER);
	}

	public static boolean hasAccess(Context context)
	{
		if (Build.VERSION.SDK_INT >= 30) return Environment.isExternalStorageManager();
		if (Build.VERSION.SDK_INT >= 23) return context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
		return true;
	}

	public static String getStorageType(Context context)
	{
		File marker = new File(getAppDir(context), TYPE_MARKER);
		if (marker.exists())
		{
			String value = readText(marker).trim();
			if (value.equals(TYPE_MEDIA) || value.equals(TYPE_EXTERNAL) || value.equals(TYPE_DATA) || value.equals(TYPE_OBB)) return value;
		}
		if (new File(getAppDir(context), LEGACY_EXTERNAL_MARKER).exists()) return TYPE_EXTERNAL;
		return TYPE_DATA;
	}

	public static File getDirFor(Context context, String type)
	{
		if (TYPE_EXTERNAL.equals(type) && hasAccess(context))
		{
			File dir = getPublicDir();
			if (isWritable(dir)) return dir;
		}
		if (TYPE_MEDIA.equals(type))
		{
			File dir = getMediaDir(context);
			if (dir != null) return dir;
		}
		if (TYPE_OBB.equals(type))
		{
			File dir = context.getObbDir();
			if (isWritable(dir)) return dir;
		}
		return getAppDir(context);
	}

	public static File getGameDir(Context context)
	{
		return getDirFor(context, getStorageType(context));
	}

	public static String getStorageType()
	{
		Context context = Extension.mainContext;
		return context == null ? TYPE_DATA : getStorageType(context);
	}

	public static void setStorageType(String type)
	{
		Context context = Extension.mainContext;
		if (context == null) return;
		File dir = getAppDir(context);
		new File(dir, LEGACY_EXTERNAL_MARKER).delete();
		writeText(new File(dir, TYPE_MARKER), type == null ? TYPE_DATA : type);
	}

	public static String getDirPathFor(String type)
	{
		Context context = Extension.mainContext;
		if (context == null) return "";
		return getDirFor(context, type).getAbsolutePath();
	}

	public static boolean hasAccess()
	{
		Context context = Extension.mainContext;
		return context != null && hasAccess(context);
	}

	public static boolean useExternal()
	{
		return TYPE_EXTERNAL.equals(getStorageType());
	}

	public static void setUseExternal(boolean value)
	{
		setStorageType(value ? TYPE_EXTERNAL : TYPE_DATA);
	}

	public static String getGameDirPath()
	{
		Context context = Extension.mainContext;
		if (context == null) return "";
		return getGameDir(context).getAbsolutePath();
	}

	public static double getFreeSpace()
	{
		return getFreeSpaceFor(getGameDirPath());
	}

	public static double getFreeSpaceFor(String path)
	{
		try
		{
			File dir = new File(path);
			while (dir != null && !dir.exists()) dir = dir.getParentFile();
			if (dir == null) return -1;
			return (double)new StatFs(dir.getAbsolutePath()).getAvailableBytes();
		}
		catch (Exception e)
		{
			return -1;
		}
	}

	public static double getTotalSpaceFor(String path)
	{
		try
		{
			File dir = new File(path);
			while (dir != null && !dir.exists()) dir = dir.getParentFile();
			if (dir == null) return -1;
			return (double)new StatFs(dir.getAbsolutePath()).getTotalBytes();
		}
		catch (Exception e)
		{
			return -1;
		}
	}

	public static double getFolderSize(String path)
	{
		return (double)folderSize(new File(path));
	}

	private static long folderSize(File file)
	{
		if (!file.exists()) return 0;
		if (!file.isDirectory()) return file.length();
		long size = 0;
		File[] children = file.listFiles();
		if (children != null)
			for (File child : children) size += folderSize(child);
		return size;
	}

	public static int deleteFolder(String path)
	{
		return deleteRecursive(new File(path));
	}

	private static int deleteRecursive(File file)
	{
		if (!file.exists()) return 0;
		int count = 0;
		if (file.isDirectory())
		{
			File[] children = file.listFiles();
			if (children != null)
				for (File child : children) count += deleteRecursive(child);
		}
		if (file.delete() && !file.isDirectory()) count++;
		return count;
	}

	public static int cleanTemp(String path)
	{
		return cleanTempRecursive(new File(path));
	}

	private static int cleanTempRecursive(File dir)
	{
		if (!dir.isDirectory()) return 0;
		int count = 0;
		File[] children = dir.listFiles();
		if (children == null) return 0;
		for (File child : children)
		{
			if (child.isDirectory()) count += cleanTempRecursive(child);
			else if ((child.getName().endsWith(".part") || child.getName().equals(PROBE)) && child.delete()) count++;
		}
		return count;
	}

	public static int moveFolder(String from, String to)
	{
		File source = new File(from);
		File target = new File(to);
		if (!source.exists()) return 0;
		if (!target.exists())
		{
			File parent = target.getParentFile();
			if (parent != null && !parent.exists()) parent.mkdirs();
			if (source.renameTo(target)) return Math.max(1, countFiles(target));
		}
		int count = copyRecursive(source, target, false);
		deleteRecursive(source);
		return count;
	}

	private static int countFiles(File file)
	{
		if (!file.isDirectory()) return file.exists() ? 1 : 0;
		int count = 0;
		File[] children = file.listFiles();
		if (children != null)
			for (File child : children) count += countFiles(child);
		return count;
	}

	public static long getLastUpdateTime()
	{
		Context context = Extension.mainContext;
		if (context == null) return 0;
		try
		{
			return context.getPackageManager().getPackageInfo(context.getPackageName(), 0).lastUpdateTime;
		}
		catch (Exception e)
		{
			return 0;
		}
	}

	public static String getInstallStamp()
	{
		Context context = Extension.mainContext;
		if (context == null) return "";
		try
		{
			PackageInfo info = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
			return info.versionName + "-" + info.lastUpdateTime;
		}
		catch (Exception e)
		{
			return "";
		}
	}

	public static int copyFolder(String from, String to, boolean overwrite)
	{
		return copyRecursive(new File(from), new File(to), overwrite);
	}

	private static int copyRecursive(File source, File target, boolean overwrite)
	{
		if (!source.exists()) return 0;
		if (source.isDirectory())
		{
			if (!target.exists()) target.mkdirs();
			int count = 0;
			File[] children = source.listFiles();
			if (children == null) return 0;
			for (File child : children)
				count += copyRecursive(child, new File(target, child.getName()), overwrite);
			return count;
		}
		if (target.exists() && !overwrite && target.length() == source.length()) return 0;
		File temp = new File(target.getAbsolutePath() + ".part");
		try
		{
			File parent = target.getParentFile();
			if (parent != null && !parent.exists()) parent.mkdirs();
			copyStream(new FileInputStream(source), new FileOutputStream(temp));
			if (temp.length() != source.length()) throw new IOException("Size mismatch");
			if (target.exists() && !target.delete()) throw new IOException("Delete failed");
			if (!temp.renameTo(target)) throw new IOException("Rename failed");
			target.setLastModified(source.lastModified());
			return 1;
		}
		catch (Exception e)
		{
			temp.delete();
			return 0;
		}
	}

	static void copyStream(InputStream input, OutputStream output) throws IOException
	{
		try
		{
			byte[] buffer = new byte[BUFFER_SIZE];
			int read;
			while ((read = input.read(buffer)) != -1)
				output.write(buffer, 0, read);
			output.flush();
		}
		finally
		{
			try { input.close(); } catch (Exception e) {}
			try { output.close(); } catch (Exception e) {}
		}
	}

	private static String readText(File file)
	{
		try
		{
			FileInputStream input = new FileInputStream(file);
			byte[] bytes = new byte[(int)file.length()];
			int offset = 0;
			while (offset < bytes.length)
			{
				int read = input.read(bytes, offset, bytes.length - offset);
				if (read < 0) break;
				offset += read;
			}
			input.close();
			return new String(bytes, 0, offset, StandardCharsets.UTF_8);
		}
		catch (Exception e)
		{
			return "";
		}
	}

	private static void writeText(File file, String text)
	{
		try
		{
			FileOutputStream output = new FileOutputStream(file);
			output.write(text.getBytes(StandardCharsets.UTF_8));
			output.close();
		}
		catch (Exception e) {}
	}

	public static void requestAccess()
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				if (Build.VERSION.SDK_INT >= 30)
				{
					try
					{
						Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
						intent.setData(Uri.parse("package:" + activity.getPackageName()));
						activity.startActivity(intent);
					}
					catch (Exception e)
					{
						try
						{
							activity.startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
						}
						catch (Exception ignored) {}
					}
				}
				else if (Build.VERSION.SDK_INT >= 23)
				{
					activity.requestPermissions(new String[] {
						Manifest.permission.READ_EXTERNAL_STORAGE,
						Manifest.permission.WRITE_EXTERNAL_STORAGE
					}, 7001);
				}
			}
		});
	}
}
