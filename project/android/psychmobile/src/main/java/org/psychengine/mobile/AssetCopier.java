package org.psychengine.mobile;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicInteger;
import org.haxe.extension.Extension;

public class AssetCopier
{
	private static final String[] ROOTS = { "assets", "mods", "modsList.txt" };
	private static final String[] PRESERVE = { "mods/", "modsList.txt" };
	private static final int WORKERS = Math.max(2, Math.min(4, Runtime.getRuntime().availableProcessors()));
	private static final int BUFFER_SIZE = 262144;

	private static volatile boolean running = false;
	private static volatile boolean finished = false;
	private static volatile int total = 0;
	private static final AtomicInteger done = new AtomicInteger();
	private static final AtomicInteger failed = new AtomicInteger();
	private static final AtomicInteger skipped = new AtomicInteger();
	private static volatile String current = "";
	private static final List<String> failures = new ArrayList<String>();

	public static boolean isRunning() { return running; }
	public static boolean isFinished() { return finished; }
	public static int getTotal() { return total; }
	public static int getDone() { return done.get(); }
	public static int getFailed() { return failed.get(); }
	public static int getSkipped() { return skipped.get(); }
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
		total = 0;
		done.set(0);
		failed.set(0);
		skipped.set(0);
		current = "";
		synchronized (failures) { failures.clear(); }

		new Thread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					final AssetManager manager = context.getAssets();
					List<String> files = new ArrayList<String>();
					for (String root : ROOTS) collect(manager, root, files);
					total = files.size();

					final ConcurrentLinkedQueue<String> queue = new ConcurrentLinkedQueue<String>(files);
					final File base = new File(destination);
					final long installTime = Storage.getLastUpdateTime();

					Thread[] workers = new Thread[WORKERS];
					for (int i = 0; i < workers.length; i++)
					{
						workers[i] = new Thread(new Runnable()
						{
							@Override
							public void run()
							{
								byte[] buffer = new byte[BUFFER_SIZE];
								String path;
								while ((path = queue.poll()) != null)
								{
									current = path;
									if (!copyWithRetry(manager, path, new File(base, path), installTime, buffer))
									{
										failed.incrementAndGet();
										synchronized (failures) { failures.add(path); }
									}
									done.incrementAndGet();
								}
							}
						});
						workers[i].start();
					}
					for (Thread worker : workers) worker.join();
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

	private static long assetLength(AssetManager manager, String path)
	{
		AssetFileDescriptor descriptor = null;
		try
		{
			descriptor = manager.openFd(path);
			return descriptor.getLength();
		}
		catch (IOException e)
		{
			return -1;
		}
		finally
		{
			if (descriptor != null) try { descriptor.close(); } catch (IOException e) {}
		}
	}

	private static boolean upToDate(AssetManager manager, String path, File target, long installTime)
	{
		if (!target.exists() || installTime <= 0 || target.lastModified() < installTime) return false;
		long length = assetLength(manager, path);
		return length < 0 || length == target.length();
	}

	private static boolean copyWithRetry(AssetManager manager, String path, File target, long installTime, byte[] buffer)
	{
		if (preserve(path) && target.exists())
		{
			skipped.incrementAndGet();
			return true;
		}
		if (upToDate(manager, path, target, installTime))
		{
			skipped.incrementAndGet();
			return true;
		}

		for (int attempt = 0; attempt < 3; attempt++)
		{
			File temp = new File(target.getAbsolutePath() + ".part");
			try
			{
				File parent = target.getParentFile();
				if (parent != null && !parent.exists()) parent.mkdirs();

				long written = 0;
				InputStream input = manager.open(path, AssetManager.ACCESS_STREAMING);
				FileOutputStream output = new FileOutputStream(temp);
				try
				{
					int read;
					while ((read = input.read(buffer)) != -1)
					{
						output.write(buffer, 0, read);
						written += read;
					}
					output.flush();
				}
				finally
				{
					try { input.close(); } catch (Exception e) {}
					try { output.close(); } catch (Exception e) {}
				}

				if (temp.length() != written) throw new IOException("Size mismatch");
				if (target.exists() && !target.delete()) throw new IOException("Delete failed");
				if (!temp.renameTo(target)) throw new IOException("Rename failed");
				return true;
			}
			catch (Exception e)
			{
				temp.delete();
			}
		}
		return false;
	}
}
