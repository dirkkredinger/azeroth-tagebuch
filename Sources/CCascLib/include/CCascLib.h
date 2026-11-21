// Schlanke C-Schnittstelle zu CascLib für Swift.
// Nur die Funktionen, die die App braucht; Signaturen entsprechen src/CascLib.h (macOS: WINAPI ist leer).
#ifndef CCASCLIB_H
#define CCASCLIB_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void * CascHandle;

#define CCASC_OPEN_BY_NAME   0x00000000u
#define CCASC_OPEN_BY_FILEID 0x00000003u
#define CCASC_OVERCOME_ENCRYPTED 0x00000020u

bool         CascOpenStorage(const char * szParams, unsigned int dwLocaleMask, CascHandle * phStorage);
bool         CascCloseStorage(CascHandle hStorage);
bool         CascOpenFile(CascHandle hStorage, const void * pvFileName, unsigned int dwLocaleFlags, unsigned int dwOpenFlags, CascHandle * PtrFileHandle);
bool         CascGetFileSize64(CascHandle hFile, unsigned long long * PtrFileSize);
bool         CascReadFile(CascHandle hFile, void * lpBuffer, unsigned int dwToRead, unsigned int * pdwRead);
bool         CascCloseFile(CascHandle hFile);
unsigned int GetCascError(void);

#ifdef __cplusplus
}
#endif

#endif
