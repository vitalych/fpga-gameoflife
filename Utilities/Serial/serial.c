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

#include <windows.h>
#include <stdio.h>
#include <fcntl.h>
#include <io.h>

#pragma warning(disable:4996)

void PrintError(LPCSTR str)
{
    LPVOID MessageBuffer;
    DWORD Error = GetLastError();
    FormatMessage(
        FORMAT_MESSAGE_ALLOCATE_BUFFER |
        FORMAT_MESSAGE_FROM_SYSTEM,
        NULL,
        Error,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPTSTR) &MessageBuffer,
        0,
        NULL
    );

    printf("%s: (%#x) %s\n", str, Error, (LPCSTR)MessageBuffer);
    LocalFree(MessageBuffer);
}

#define BUFSIZE 4096

int main(int argc, char *argv[])
{
    unsigned char Buffer[BUFSIZE];
    COMMTIMEOUTS ComTimeouts = { 1, 100, 1000, 0, 0 };
    DCB Dcb;
    HANDLE PortHandle;
    int fd;

    if (argc < 4) {
        printf(
	"Copy to serial port with even parity, 1 stop bit, custom speed\n\n"
           "Usage:   serial.exe bps source_file comport\n"
           "Example: serial.exe 115200 test.bin \\\\.\\com1\n"
	    );
        return -1;
    }

	LPCSTR SpeedStr = argv[1];
	LPCSTR SourcePath = argv[2];
	LPCSTR PortPath = argv[3];

	DWORD Speed = atol(SpeedStr);

    fd = open(SourcePath, O_RDONLY | O_BINARY);
    if (fd < 0) {
        printf("Can't open file %s (%d)\n", SourcePath, fd);
        return -1;
    }

    PortHandle = CreateFile(PortPath,
                   GENERIC_READ | GENERIC_WRITE,
                   0,NULL,
                   OPEN_EXISTING, 0,NULL);

    if (PortHandle == INVALID_HANDLE_VALUE) {
        printf("Can't open file %s\n", PortPath);
		PrintError("");
        return -1;
    }

    if (!SetCommTimeouts(PortHandle, &ComTimeouts)) {
        PrintError("Can't set timeout");
    }

    // set DCB
    memset(&Dcb, 0, sizeof(Dcb));
    Dcb.DCBlength = sizeof(Dcb);
    Dcb.BaudRate = Speed;
    Dcb.fBinary = 1;
    Dcb.fDtrControl = DTR_CONTROL_DISABLE;
    Dcb.fRtsControl = RTS_CONTROL_DISABLE;

    Dcb.Parity = EVENPARITY;
    Dcb.StopBits = ONESTOPBIT;
    Dcb.ByteSize = 8;

    if (!SetCommState(PortHandle, &Dcb)) {
        PrintError("Can't set communication parameters");
		return -1;
    }
   
	DWORD TotalWritten = 0;

    while (1) {
		int ReadCount = read(fd, Buffer, BUFSIZE);
		if (ReadCount < 0) {
			printf("Could not read file: %d\n", ReadCount);
			break;
		}

        if (ReadCount == 0) {
			break;
        }

		int Written = 0;
        
        if (!WriteFile(PortHandle, Buffer, ReadCount, &Written,NULL)) {
			PrintError("Could not write to serial port");
			break;
        }

        if (Written != ReadCount) {
			printf("Did not write expected number of bytes (expected %d bytes, wrote %d)\n", ReadCount, Written);
			break;
        }
        
        printf("\rWritten %d bytes", TotalWritten);

		TotalWritten += Written;
    }

	printf("\n");

    CloseHandle(PortHandle);
    close(fd);

    return 0;
}
