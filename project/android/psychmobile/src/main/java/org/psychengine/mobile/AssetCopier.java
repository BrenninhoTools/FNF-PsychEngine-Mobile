package org.psychengine.mobile;

import android.content.Context;
import android.content.res.AssetManager;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import org.haxe.extension.Extension;

public class AssetCopier
{
	private static final String[] ROOTS = { "assets", "mods", "modsList.txt" };
	private static final String[] PRESERVE = { "mods/", "modsList.txt" };

	private static volatile boolean running = false;
	private static volatile boolean finished = false;
	private static volatile int total = 0;
	private static volatile int done = 0;
	private static volatile int failed = 0;
	private static volatile int skipped = 0;
	private static volatile String current = "";
	private static final List<String> failures = new ArrayList<String>();

	public static boolean isRunning() { return running; }
	public static boolean isFinished() { return finished; }
	public static int getTotal() { return total; }
	public static int getDone() { return done; }
	public static int getFailed() { return failed; }
	public static int getSkipped() { return skipped; }
	public static String getCurrent() { return current; }

	public static String getFailures()
	{
		synchronized (failures)
		{
			StringBuilder builder = new StringBuilder();
			for (String path : failures) builder.append(path).append('\n');
			return builder.toString();
		}
	}

	public static void start(final String destination)
	{
		if (running) return;
		final Context context = Extension.mainContext;
		if (context == null)
		{
			finished = true;
			return;
		}

		running = true;
		finished = false;
		total = done = failed = skipped = 0;
		current = "";
		synchronized (failures) { failures.clear(); }

		new Thread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					AssetManager manager = context.getAssets();
					List<String> files = new ArrayList<String>();
					for (String root : ROOTS) collect(manager, root, files);
					total = files.size();

					File base = new File(destination);
					for (String path : files)
					{
						current = path;
						if (!copyWithRetry(manager, path, new File(base, path)))
						{
							failed++;
							synchronized (failures) { failures.add(path); }
						}
						done++;
					}
				}
				catch (Exception e) {}
				current = "";
				running = false;
				finished = true;
			}
		}).start();
	}

	private static void collect(AssetManager manager, String path, List<String> out)
	{
		String[] children;
		try
		{
			children = manager.list(path);
		}
		catch (IOException e)
		{
			children = null;
		}

		if (children != null && children.length > 0)
		{
			for (String child : children)
				collect(manager, path + "/" + child, out);
			return;
		}

		InputStream test = null;
		try
		{
			test = manager.open(path);
			out.add(path);
		}
		catch (IOException e) {}
		finally
		{
			if (test != null) try { test.close(); } catch (IOException e) {}
		}
	}

	private static boolean preserve(String path)
	{
		for (String prefix : PRESERVE)
			if (path.startsWith(prefix)) return true;
		return false;
	}

	private static boolean copyWithRetry(AssetManager manager, String path, File target)
	{
		if (preserve(path) && target.exists())
		{
			skipped++;
			return true;
		}

		for (int attempt = 0; attempt < 3; attempt++)
		{
			try
			{
				File parent = target.getParentFile();
				if (parent != null && !parent.exists()) parent.mkdirs();

				File temp = new File(target.getAbsolutePath() + ".part");
				long written = 0;
				InputStream input = manager.open(path, AssetManager.ACCESS_STREAMING);
				FileOutputStream output = new FileOutputStream(temp);
				try
				{
					byte[] buffer = new byte[131072];
					int read;
					while ((read = input.read(buffer)) != -1)
					{
						output.write(buffer, 0, read);
						written += read;
					}
					output.flush();
					output.getFD().sync();
				}
				finally
				{
					try { input.close(); } catch (Exception e) {}
					try { output.close(); } catch (Exception e) {}
				}

				if (temp.length() != written) throw new IOException("Size mismatch");
				if (target.exists()) target.delete();
				if (!temp.renameTo(target)) throw new IOException("Rename failed");
				return true;
			}
			catch (Exception e)
			{
				new File(target.getAbsolutePath() + ".part").delete();
			}
		}
		return false;
	}
}
