// Copyright(c) 2007 - 2020 Vitaly Chipounov
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


using BitmapUtils;

using Dithering;

using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;

namespace BitmapConverter
{
    class Program
    {
        static byte To4Bits(ByteRgb c)
        {
            var r = (c.R & 0x80) >> 7;
            var g = (c.G & 0x80) >> 7;
            var b = (c.B & 0x80) >> 7;
            return (byte) ((b << 2) | (g << 1) | r);
        }

        static byte ExtractBW(List<ByteRgb[]> rawBitmap, int x, int y, int width)
        {
            byte b = 0;

            b |= (byte) (rawBitmap[y][x].R == 0 ? 0 : 1);

            if (x + 1 < width)
                b |= (byte) (rawBitmap[y][x + 1].R == 0 ? 0 : 2);

            if (x + 2 < width)
                b |= (byte) (rawBitmap[y][x + 2].R == 0 ? 0 : 4);

            if (x + 3 < width)
                b |= (byte) (rawBitmap[y][x + 3].R == 0 ? 0 : 8);

            if (x + 4 < width)
                b |= (byte) (rawBitmap[y][x + 4].R == 0 ? 0 : 16);

            if (x + 5 < width)
                b |= (byte) (rawBitmap[y][x + 5].R == 0 ? 0 : 32);

            if (x + 6 < width)
                b |= (byte) (rawBitmap[y][x + 6].R == 0 ? 0 : 64);

            if (x + 7 < width)
                b |= (byte) (rawBitmap[y][x + 7].R == 0 ? 0 : 128);

            return b;
        }

        static byte Extract4B(List<ByteRgb[]> rawBitmap, int x, int y, int width)
        {
            var col1 = rawBitmap[y][x];
            var col2 = x + 1 < width ? rawBitmap[y][x + 1] : new ByteRgb();

            var c1 = To4Bits(col1);
            var c2 = To4Bits(col2);
            var c = (byte) ((c1 << 4) | c2);
            return c;
        }

        static void GenerateBin(Bitmap bmp, string destBin, int colorDepth)
        {
            var rawBitmap = bmp.RawDataFromBitmap();
            using (var file = File.OpenWrite(destBin)) {
                if (colorDepth == 1) {
                    for (var y = 0; y < bmp.Height; ++y) {
                        for (var x = 0; x < bmp.Width; x += 8) {
                            var b = ExtractBW(rawBitmap, x, y, bmp.Width);
                            file.WriteByte(b);
                        }
                    }
                } else if (colorDepth == 4) {
                    for (var y = 0; y < bmp.Height; ++y) {
                        for (var x = 0; x < bmp.Width; x += 2) {
                            var c = Extract4B(rawBitmap, x, y, bmp.Width);
                            file.WriteByte(c);
                        }
                    }
                }
            }
        }

        static void WriteHeader(StreamWriter f, int size, int bits)
        {
            f.WriteLine($"WIDTH={bits};");
            f.WriteLine($"DEPTH={size};");
            f.WriteLine("");
            f.WriteLine($"ADDRESS_RADIX=HEX;");
            f.WriteLine($"DATA_RADIX=UNS;");
            f.WriteLine("");
            f.WriteLine("CONTENT BEGIN");
        }

        static void WriteLineData(Bitmap bmp, StreamWriter[] s, int colorDepth, bool split)
        {
            var rawBitmap = bmp.RawDataFromBitmap();

            for (var y = 0; y < bmp.Height; ++y) {
                for (var x = 0; x < bmp.Width; x++) {
                    var col1 = rawBitmap[y][x];
                    byte c1 = 0;
                    if (colorDepth == 1) {
                        c1 = (byte) (col1.R == 0 ? 0 : 1);
                    } else if (colorDepth == 4) {
                        c1 = To4Bits(col1);
                    }

                    s[0].WriteLine($"{y * bmp.Width + x:X}: {c1};");

                    if (split) {
                        var line = $"{y / 3 * bmp.Width + x:X}: {c1};";
                        switch (y % 3) {
                            case 0:
                                s[1].WriteLine(line);
                                break;
                            case 1:
                                s[2].WriteLine(line);
                                break;
                            case 2:
                                s[3].WriteLine(line);
                                break;
                        }
                    }
                }
            }
        }

        static void GenerateMif(Bitmap bmp, string sourceFile, string destMifDir, int colorDepth)
        {
            var split = true;
            if ((bmp.Height % 3) != 0) {
                Console.WriteLine("Bitmap height must be a multiple of 3 to generate split mif files!");
                split = false;
            }

            var fileNames = new List<string>();
            var files = new List<FileStream>();
            var fs = new List<StreamWriter>();

            var baseName = Path.GetFileNameWithoutExtension(sourceFile);
            fileNames.Add(Path.Combine(destMifDir, baseName + ".mif"));
            if (split) {
                fileNames.Add(Path.Combine(destMifDir, baseName + "_0.mif"));
                fileNames.Add(Path.Combine(destMifDir, baseName + "_1.mif"));
                fileNames.Add(Path.Combine(destMifDir, baseName + "_2.mif"));
            }

            foreach (var fileName in fileNames) {
                var f = File.OpenWrite(fileName);
                files.Add(f);
                fs.Add(new StreamWriter(f));
            }


            var size = bmp.Width * bmp.Height;

            WriteHeader(fs[0], size, colorDepth);

            if (split) {
                WriteHeader(fs[1], size / 3, colorDepth);
                WriteHeader(fs[2], size / 3, colorDepth);
                WriteHeader(fs[3], size / 3, colorDepth);
            }

            WriteLineData(bmp, fs.ToArray(), colorDepth, split);

            if (split) {
                fs[3].WriteLine("END;");
                fs[2].WriteLine("END;");
                fs[1].WriteLine("END;");
            }

            fs[0].WriteLine("END;");

            foreach (var f in fs) {
                f.Dispose();
            }

            foreach (var f in files) {
                f.Dispose();
            }
        }

        static void Main(string[] args)
        {
            if (args.Length != 4) {
                Console.WriteLine("Bitmap to binary converter\n");
                Console.WriteLine("Usage:");
                Console.WriteLine("  BitmapConverter.exe [bin|mif] source.bmp [1|4] [dest.bin|dest_dir]");
                return;
            }

            var format = args[0];
            var sourceBmp = args[1];
            var colorDepthStr = args[2];
            var destFileOrDir = args[3];

            if (!int.TryParse(colorDepthStr, out var colorDepth) || (colorDepth != 1 && colorDepth != 4)) {
                Console.WriteLine("Invalid output color depth. Must be 1 or 4 bits");
                return;
            }

            using (var bitmap = new Bitmap(sourceBmp)) {
                Bitmap ditheredBitmap = null;
                if (colorDepth == 4) {
                    ditheredBitmap = bitmap.Dither();
                }

                var actualBitmap = ditheredBitmap == null ? bitmap : ditheredBitmap;

                if (format == "bin") {
                    GenerateBin(actualBitmap, destFileOrDir, colorDepth);
                } else if (format == "mif") {
                    GenerateMif(actualBitmap, sourceBmp, destFileOrDir, colorDepth);
                } else {
                    Console.WriteLine($"Invalid format: {format}");
                }

                if (ditheredBitmap != null) {
                    ditheredBitmap.Dispose();
                }
            }
        }
    }
}
