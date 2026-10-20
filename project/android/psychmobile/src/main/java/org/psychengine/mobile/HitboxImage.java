package org.psychengine.mobile;

import android.content.ContentResolver;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.net.Uri;
import android.os.Build;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

public class HitboxImage
{
	private static volatile String message = "";

	public static String getMessage()
	{
		return message;
	}

	public static void reset()
	{
		message = "";
	}

	public static boolean save(ContentResolver resolver, Uri uri, String targetPath, int maxSize)
	{
		message = "";
		try
		{
			BitmapFactory.Options bounds = new BitmapFactory.Options();
			bounds.inJustDecodeBounds = true;
			InputStream probe = resolver.openInputStream(uri);
			BitmapFactory.decodeStream(probe, null, bounds);
			probe.close();

			if (bounds.outWidth <= 0 || bounds.outHeight <= 0)
			{
				message = "The selected file is not an image Android can read.";
				return false;
			}

			int sample = 1;
			while (bounds.outWidth / (sample * 2) >= maxSize || bounds.outHeight / (sample * 2) >= maxSize)
				sample *= 2;

			BitmapFactory.Options options = new BitmapFactory.Options();
			options.inSampleSize = sample;
			options.inPreferredConfig = Bitmap.Config.ARGB_8888;
			InputStream input = resolver.openInputStream(uri);
			Bitmap bitmap = BitmapFactory.decodeStream(input, null, options);
			input.close();

			if (bitmap == null)
			{
				message = "Could not decode the selected image.";
				return false;
			}

			bitmap = applyOrientation(resolver, uri, bitmap);

			int largest = Math.max(bitmap.getWidth(), bitmap.getHeight());
			if (largest > maxSize)
			{
				float ratio = (float)maxSize / largest;
				Bitmap scaled = Bitmap.createScaledBitmap(bitmap, Math.max(1, Math.round(bitmap.getWidth() * ratio)), Math.max(1, Math.round(bitmap.getHeight() * ratio)), true);
				if (scaled != bitmap) bitmap.recycle();
				bitmap = scaled;
			}

			File target = new File(targetPath);
			File parent = target.getParentFile();
			if (parent != null && !parent.exists()) parent.mkdirs();
			File temp = new File(targetPath + ".part");
			FileOutputStream output = new FileOutputStream(temp);
			boolean written = bitmap.compress(Bitmap.CompressFormat.PNG, 100, output);
			output.close();
			bitmap.recycle();

			if (!written)
			{
				temp.delete();
				message = "Could not save the image.";
				return false;
			}
			if (target.exists()) target.delete();
			if (!temp.renameTo(target))
			{
				message = "Could not save the image.";
				return false;
			}
			return true;
		}
		catch (Exception e)
		{
			message = "Could not import the image: " + e.getMessage();
			return false;
		}
	}

	private static Bitmap applyOrientation(ContentResolver resolver, Uri uri, Bitmap bitmap)
	{
		if (Build.VERSION.SDK_INT < 24) return bitmap;
		try
		{
			InputStream input = resolver.openInputStream(uri);
			ExifInterface exif = new ExifInterface(input);
			int orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL);
			input.close();

			int degrees = 0;
			if (orientation == ExifInterface.ORIENTATION_ROTATE_90) degrees = 90;
			else if (orientation == ExifInterface.ORIENTATION_ROTATE_180) degrees = 180;
			else if (orientation == ExifInterface.ORIENTATION_ROTATE_270) degrees = 270;
			if (degrees == 0) return bitmap;

			Matrix matrix = new Matrix();
			matrix.postRotate(degrees);
			Bitmap rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), matrix, true);
			if (rotated != bitmap) bitmap.recycle();
			return rotated;
		}
		catch (Exception e)
		{
			return bitmap;
		}
	}
}
