using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Linq;
using System.Text;

using BitmapUtils;

namespace Dithering
{
    public static class Dithering
    {
        private static void UpdatePixel(List<ByteRgb[]> pixels, int x, int y, IntRgb qerr, float fraction)
        {
            var col = pixels[y][x];
            var qr = (int) (qerr.R * fraction);
            var qg = (int) (qerr.G * fraction);
            var qb = (int) (qerr.B * fraction);
            var newCol = ByteRgb.FromArgb(0, (col.R + qr).ToByte(),
                                          (col.G + qg).ToByte(), (col.B + qb).ToByte());
            pixels[y][x] = newCol;
        }

        public static void Dither(List<ByteRgb[]> array, int width, int height)
        {
            for (var y = 0; y < height; ++y) {
                for (var x = 0; x < width; ++x) {
                    var oldPixel = array[y][x];
                    var nr = oldPixel.R >= 128 ? 255 : 0;
                    var ng = oldPixel.G >= 128 ? 255 : 0;
                    var nb = oldPixel.B >= 128 ? 255 : 0;

                    var newPixel = ByteRgb.FromArgb(0, (byte) nr, (byte) ng, (byte) nb);
                    array[y][x] = newPixel;

                    // Compute quantization error
                    IntRgb qerr;
                    qerr.R = oldPixel.R - newPixel.R;
                    qerr.G = oldPixel.G - newPixel.G;
                    qerr.B = oldPixel.B - newPixel.B;

                    if (x + 1 < width) {
                        UpdatePixel(array, x + 1, y, qerr, 7.0f / 16.0f);
                    }

                    if (((x - 1) >= 0) && ((y + 1) < height)) {
                        UpdatePixel(array, x - 1, y + 1, qerr, 3.0f / 16.0f);
                    }

                    if (((y + 1) < height)) {
                        UpdatePixel(array, x, y + 1, qerr, 5.0f / 16.0f);
                    }

                    if (((x + 1) < width) && ((y + 1) < height)) {
                        UpdatePixel(array, x + 1, y + 1, qerr, 1.0f / 16.0f);
                    }
                }
            }
        }

        public static Bitmap Dither(this Bitmap sourceBmp)
        {
            var destBmp = new Bitmap(sourceBmp.Width, sourceBmp.Height, PixelFormat.Format24bppRgb);
            var rawBitmap = sourceBmp.RawDataFromBitmap();
            Dither(rawBitmap, sourceBmp.Width, sourceBmp.Height);
            destBmp.RawDataToBitmap(rawBitmap);
            return destBmp;
        }
    }
}
