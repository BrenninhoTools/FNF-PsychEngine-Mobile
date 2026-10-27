package org.psychengine.mobile;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.os.StatFs;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import org.haxe.extension.Extension;

public class AssetCopier
{
	private static final String[] ROOTS = { "assets", "mods", "modsList.txt" };
	private static final String[] PRESERVE = { "mods/", "modsList.txt" };
	private static final String INDEX_FILE = ".psych_asset_index";
	private static final String TEMP_SUFFIX = ".part";
	private static final int WORKERS = Math.max(2, Math.min(4, Runtime.getRuntime().availableProcessors()));
	private static final int BUFFER_SIZE = 262144;
	private static final long SPACE_MARGIN = 16L * 1024L * 1024L;

	private static volatile boolean running = false;
	private static volatile boolean finished = false;
	private static volatile boolean lowSpace = false;
	private static volatile int total = 0;
	private static volatile long bytesTotal = 0;
	private static volatile long bytesNeeded = 0;
	private static volatile long freeBytes = -1;
	private static volatile long startTime = 0;
	private static volatile String current = "";
	private static volatile String stage = "";
	private static final AtomicInteger done = new AtomicInteger();
	private static final AtomicInteger failed = new AtomicInteger();
	private static final AtomicInteger skipped = new AtomicInteger();
	private static final AtomicLong bytesDone = new AtomicLong();
	private static final List<String> failures = new ArrayList<String>();
	private static final Set<String> createdDirs = Collections.newSetFromMap(new ConcurrentHashMap<String, Boolean>());

	public static boolean isRunning() { return running; }
	public static boolean isFinished() { return finished; }
	public static boolean isLowSpace() { return lowSpace; }
	public static int getTotal() { return total; }
	public static int getDone() { return done.get(); }
	public static int getFailed() { return failed.get(); }
	public static int getSkipped() { return skipped.get(); }
	public static String getCurrent() { return current; }
	public static String getStage() { return stage; }
	public static double getBytesTotal() { return (double)bytesTotal; }
	public static double getBytesNeeded() { return (double)bytesNeeded; }
	public static double getBytesDone() { return (double)bytesDone.get(); }
	public static double getFreeBytes() { return (double)freeBytes; }

	public static double getSpeed()
	{
		long elapsed = System.currentTimeMillis() - startTime;
		if (startTime <= 0 || elapsed <= 0) return 0;
		return bytesDone.get() * 1000.0 / elapsed;
	}

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
		lowSpace = false;
		total = 0;
		bytesTotal = 0;
		bytesNeeded = 0;
		freeBytes = -1;
		startTime = 0;
		done.set(0);
		failed.set(0);
		skipped.set(0);
		bytesDone.set(0);
		current = "";
		stage = "Reading the APK";
		createdDirs.clear();
		synchronized (failures) { failures.clear(); }

		new Thread(new Runnable()
		{
			@Override
			public void run()
			{
				try
				{
					copyAll(context, new File(destination));
				}
				catch (Exception e) {}
				current = "";
				stage = "";
				running = false;
				finished = true;
			}
		}).start();
	}

	private static void copyAll(Context context, File base) throws InterruptedException
	{
		final AssetManager manager = context.getAssets();
		final String stamp = Storage.getInstallStamp();
		final long installTime = Storage.getLastUpdateTime();

		Map<String, Long> index = readIndex(base, stamp);
		if (index == null)
		{
			index = new HashMap<String, Long>();
			for (String root : ROOTS) collect(manager, root, index);
			writeIndex(base, stamp, index);
		}

		stage = "Cleaning old files";
		for (String root : ROOTS) cleanTemp(new File(base, root));

		stage = "Checking space";
		final List<String> pending = new ArrayList<String>();
		final Map<String, Long> lengths = index;
		long all = 0;
		long needed = 0;
		for (Map.Entry<String, Long> entry : index.entrySet())
		{
			String path = entry.getKey();
			long length = entry.getValue();
			if (length > 0) all += length;
			File target = new File(base, path);
			if ((preserve(path) && target.exists()) || upToDate(target, length, installTime))
			{
				skipped.incrementAndGet();
				continue;
			}
			pending.add(path);
			if (length > 0) needed += length;
		}
		bytesTotal = all;
		bytesNeeded = needed;
		total = index.size();
		done.set(skipped.get());

		freeBytes = availableBytes(base);
		lowSpace = freeBytes >= 0 && freeBytes < needed + SPACE_MARGIN;

		stage = "Copying from the APK";
		startTime = System.currentTimeMillis();
		final ConcurrentLinkedQueue<String> queue = new ConcurrentLinkedQueue<String>(pending);
		final File root = base;

		Thread[] workers = new Thread[Math.min(WORKERS, Math.max(1, pending.size()))];
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
						Long expected = lengths.get(path);
						if (!copyWithRetry(manager, path, new File(root, path), expected == null ? -1 : expected, buffer))
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

		if (failed.get() > 0) new File(base, INDEX_FILE).delete();
	}

	private static Map<String, Long> readIndex(File base, String stamp)
	{
		File file = new File(base, INDEX_FILE);
		if (stamp == null || stamp.length() == 0 || !file.exists()) return null;
		try
		{
			String text = readText(file);
			String[] lines = text.split("\n");
			if (lines.length < 2 || !lines[0].equals(stamp)) return null;
			Map<String, Long> index = new HashMap<String, Long>();
			for (int i = 1; i < lines.length; i++)
			{
				String line = lines[i];
				int tab = line.lastIndexOf('\t');
				if (tab <= 0) continue;
				index.put(line.substring(0, tab), Long.parseLong(line.substring(tab + 1)));
			}
			return index.isEmpty() ? null : index;
		}
		catch (Exception e)
		{
			return null;
		}
	}

	private static void writeIndex(File base, String stamp, Map<String, Long> index)
	{
		if (stamp == null || stamp.length() == 0 || index.isEmpty()) return;
		StringBuilder builder = new StringBuilder(stamp).append('\n');
		for (Map.Entry<String, Long> entry : index.entrySet())
			builder.append(entry.getKey()).append('\t').append(entry.getValue()).append('\n');
		try
		{
			if (!base.exists()) base.mkdirs();
			FileOutputStream output = new FileOutputStream(new File(base, INDEX_FILE));
			output.write(builder.toString().getBytes(StandardCharsets.UTF_8));
			output.close();
		}
		catch (Exception e) {}
	}

	private static String readText(File file) throws IOException
	{
		FileInputStream input = new FileInputStream(file);
		try
		{
			byte[] bytes = new byte[(int)file.length()];
			int offset = 0;
			while (offset < bytes.length)
			{
				int read = input.read(bytes, offset, bytes.length - offset);
				if (read < 0) break;
				offset += read;
			}
			return new String(bytes, 0, offset, StandardCharsets.UTF_8);
		}
		finally
		{
			input.close();
		}
	}

	private static void collect(AssetManager manager, String path, Map<String, Long> out)
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

		long length = assetLength(manager, path);
		if (length >= 0)
		{
			out.put(path, length);
			return;
		}

		InputStream test = null;
		try
		{
			test = manager.open(path, AssetManager.ACCESS_STREAMING);
			out.put(path, -1L);
		}
		catch (IOException e) {}
		finally
		{
			if (test != null) try { test.close(); } catch (IOException e) {}
		}
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

	private static void cleanTemp(File dir)
	{
		if (!dir.isDirectory()) return;
		File[] children = dir.listFiles();
		if (children == null) return;
		for (File child : children)
		{
			if (child.isDirectory()) cleanTemp(child);
			else if (child.getName().endsWith(TEMP_SUFFIX)) child.delete();
		}
	}

	private static long availableBytes(File base)
	{
		try
		{
			if (!base.exists()) base.mkdirs();
			return new StatFs(base.getAbsolutePath()).getAvailableBytes();
		}
		catch (Exception e)
		{
			return -1;
		}
	}

	private static boolean preserve(String path)
	{
		for (String prefix : PRESERVE)
			if (path.startsWith(prefix)) return true;
		return false;
	}

	private static boolean upToDate(File target, long length, long installTime)
	{
		if (installTime <= 0 || target.lastModified() < installTime) return false;
		long size = target.length();
		if (size == 0 && !target.exists()) return false;
		return length < 0 || length == size;
	}

	private static void ensureParent(File target)
	{
		File parent = target.getParentFile();
		if (parent == null) return;
		String key = parent.getAbsolutePath();
		if (createdDirs.contains(key)) return;
		if (!parent.exists()) parent.mkdirs();
		createdDirs.add(key);
	}

	private static boolean copyWithRetry(AssetManager manager, String path, File target, long expected, byte[] buffer)
	{
		for (int attempt = 0; attempt < 3; attempt++)
		{
			File temp = new File(target.getAbsolutePath() + TEMP_SUFFIX);
			long written = 0;
			try
			{
				ensureParent(target);

				InputStream input = manager.open(path, AssetManager.ACCESS_STREAMING);
				FileOutputStream output = new FileOutputStream(temp);
				try
				{
					int read;
					while ((read = input.read(buffer)) != -1)
					{
						output.write(buffer, 0, read);
						written += read;
						bytesDone.addAndGet(read);
					}
					output.flush();
				}
				finally
				{
					try { input.close(); } catch (Exception e) {}
					try { output.close(); } catch (Exception e) {}
				}

				if (temp.length() != written) throw new IOException("Size mismatch");
				if (expected >= 0 && written != expected) throw new IOException("Length mismatch");
				if (target.exists() && !target.delete()) throw new IOException("Delete failed");
				if (!temp.renameTo(target)) throw new IOException("Rename failed");
				return true;
			}
			catch (Exception e)
			{
				bytesDone.addAndGet(-written);
				temp.delete();
				createdDirs.clear();
			}
		}
		return false;
	}
}
