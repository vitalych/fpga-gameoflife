// Copyright(c) 2020 Vitaly Chipounov
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

using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

namespace Grid2Bmp
{
    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length != 4) {
                Console.WriteLine("Converts a gameofline grid to a bitmap file\n");
                Console.WriteLine("Usage: Grid2Bmp bmp_width bmp_height source.grid bitmap.bmp");
                return;
            }

            if (!int.TryParse(args[0], out var bmpWidth)) {
                Console.WriteLine("Could not parse width\n");
                return;
            }

            if (!int.TryParse(args[1], out var bmpHeight)) {
                Console.WriteLine("Could not parse height\n");
                return;
            }

            string filePath = args[2];
            string bitmapPath = args[3];

            if (!File.Exists(filePath)) {
                Console.WriteLine("File %s does not exist", filePath);
                return;
            }

            var lines = new List<string>();

            // Read the grid
            using (var reader = new StreamReader(filePath)) {
                string line;
                while ((line = reader.ReadLine()) != null) {
                    line = line.Trim();
                    if (line.Length == 0 || line[0] == '#') {
                        continue;
                    }

                    lines.Add(line);
                }
            }

            // Determine the size of the grid
            var minGridHeight = lines.Count;
            var minGridWidth = 0;
            foreach (var line in lines) {
                minGridWidth = Math.Max(minGridWidth, line.Length);
            }

            if (minGridWidth > bmpWidth) {
                Console.WriteLine($"Specified width is too small ({bmpWidth}). Input grid is {minGridWidth} pixels wide\n");
                return;
            }

            if (minGridHeight > bmpHeight) {
                Console.WriteLine($"Specified height is too small ({bmpWidth}). Input grid is {minGridHeight} pixels tall\n");
                return;
            }

            Console.WriteLine($"Creating bitmap {bmpWidth}x{bmpHeight}");

            // Generate the bitmap, center the pattern
            using (var bmp = new Bitmap(bmpWidth, bmpHeight, PixelFormat.Format32bppRgb)) {
                int y = (bmpHeight - minGridHeight) / 2, x = 0;

                foreach (var line in lines) {
                    x = (bmpWidth - minGridWidth) / 2;
                    foreach (var c in line) {
                        if (c == '*') {
                            bmp.SetPixel(x, y, Color.White);
                        }

                        ++x;
                    }

                    ++y;
                }

                bmp.Save(bitmapPath);
            }
        }
    }
}
