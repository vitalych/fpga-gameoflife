using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

namespace BitmapUtils
{
    public static class IntegerExtensions
    {
        internal static byte ToByte(this int value)
        {
            if (value < 0) {
                value = 0;
            } else if (value > 255) {
                value = 255;
            }

            return (byte) value;
        }
    }

    public struct IntRgb
    {
        public int R, G, B;
    }

    /// <summary>
    /// This is the in-memory color information.
    /// The order of the fields is important.
    /// </summary>
    public struct ByteRgb
    {
        public byte B, G, R, A;

        public static ByteRgb FromArgb(byte a, byte r, byte g, byte b)
        {
            ByteRgb ret;
            ret.A = a;
            ret.R = r;
            ret.G = g;
            ret.B = b;
            return ret;
        }
    }

    public static class Utils
    {
        [DllImport("msvcrt.dll", SetLastError = false)]
        private static extern IntPtr memcpy(IntPtr dest, IntPtr src, int count);

        public static unsafe ByteRgb[] ScanLineToRgbArray(IntPtr scanLine, int byteCount)
        {
            ByteRgb[] colors = new ByteRgb[byteCount / sizeof(ByteRgb)];

            fixed (void* tempC = &colors[0]) {
                memcpy((IntPtr) tempC, scanLine, colors.Length * sizeof(ByteRgb));
            }

            return colors;
        }

        public static unsafe void RgbArrayToScanLine(IntPtr scanLine, ByteRgb[] array)
        {
            fixed (void* tempC = &array[0]) {
                memcpy(scanLine, (IntPtr) tempC, array.Length * sizeof(ByteRgb));
            }
        }

        public static List<ByteRgb[]> RawDataFromBitmap(this Bitmap source)
        {
            var array = new List<ByteRgb[]>();
            var sourceData = source.LockBits(
                new Rectangle(0, 0, source.Width, source.Height),
                ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb
            );

            // Copy the old image into the new one
            for (var y = 0; y < source.Height; ++y) {
                var line = Utils.ScanLineToRgbArray(sourceData.Scan0 + y * sourceData.Stride, source.Width * Marshal.SizeOf(typeof(ByteRgb)));
                array.Add(line);
            }

            source.UnlockBits(sourceData);
            return array;
        }

        public static void RawDataToBitmap(this Bitmap dest, List<ByteRgb[]> data)
        {
            // Copy the array of the new image into the bitmap
            var destData = dest.LockBits(
                new Rectangle(0, 0, dest.Width, dest.Height),
                ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb
            );

            for (var y = 0; y < dest.Height; ++y) {
                Utils.RgbArrayToScanLine(destData.Scan0 + y * destData.Stride, data[y]);
            }

            dest.UnlockBits(destData);
        }
    }
}
