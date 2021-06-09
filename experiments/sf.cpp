#include "windows.h"
#include "Dbghelp.h"
#include <stdio.h>

bool ImagehlpStackWalk( PCONTEXT pCtx )
{
    bool result = false;
//  PCONTEXT pContext = pEP->ContextRecord;
    // if( m_Levels == 0 ) {
    //     // dbbTrace::OutputWithoutTimestamp( "\nCall stack:\n" );
    //     // dbbTrace::OutputWithoutTimestamp( "Address   Frame\n" );
    // }

    // Could use SymSetOptions here to add the SYMOPT_DEFERRED_LOADS flag

    STACKFRAME64 sf;
    bool first = true;
    //FIXED_ARRAY( buf, char, 300 );
    //size_t buflen = sizeof(buf);
    // Indexes into MSJExceptionHandler data when m_Levels > 0
    int i_line = 0; // Into char * m_Lines[]
    int i_buf = 0;  // into char m_Buffer[]

    memset( &sf, 0, sizeof(sf) );

    // Initialize the STACKFRAME structure for the first call.  This is only
    // necessary for Intel CPUs, and isn't mentioned in the documentation.

    DWORD64 pFrame = 0;
    DWORD64 pPrevFrame = 0;
    sf.AddrPC.Mode         = AddrModeFlat;
    sf.AddrStack.Mode      = AddrModeFlat;
    sf.AddrFrame.Mode      = AddrModeFlat;
    sf.AddrPC.Offset       = pCtx->Rip;
    sf.AddrStack.Offset    = pCtx->Rsp;
    sf.AddrFrame.Offset    = pCtx->Rbp;

    DWORD MachineType = IMAGE_FILE_MACHINE_AMD64;

    while ( 1 )
    {
        printf("----\n");
        SetLastError( 0 );
        if ( ! StackWalk64( MachineType,
                            GetCurrentProcess(),
                            GetCurrentThread(),
                            &sf,
                            pCtx,
                            0,
                            SymFunctionTableAccess64,
                            SymGetModuleBase64,
                            0 ) )
            break;

        printf( "%016X  %016X  %016X  \n", sf.AddrPC.Offset, pFrame, sf.AddrStack.Offset );

        pFrame = sf.AddrFrame.Offset;
        if ( 0 == pFrame ) // Basic sanity check to make sure
            break;                      // the frame is OK.  Bail if not.



        if( ! first ) {
            if( pFrame <= pPrevFrame ) {
                // Sanity check
                break;
            }
            if( (pFrame - pPrevFrame) > 10000000 ) {
                // Sanity check
                break;
            }
        }
        if( (pFrame % sizeof(void *)) != 0 ) {
            // Sanity check
            break;
        }

        pPrevFrame = pFrame;
        first = false;

        // IMAGEHLP is wacky, and requires you to pass in a pointer to an
        // IMAGEHLP_SYMBOL structure.  The problem is that this structure is
        // variable length.  That is, you determine how big the structure is
        // at runtime.  This means that you can't use sizeof(struct).
        // So...make a buffer that's big enough, and make a pointer
        // to the buffer.  We also need to initialize not one, but TWO
        // members of the structure before it can be used.

        // enum { emMaxNameLength = 512 };
        // // Use union to ensure proper alignment
        // union {
        //     SYMBOL_INFO symb;
        //     BYTE symbolBuffer[ sizeof(SYMBOL_INFO) + emMaxNameLength ];
        // } u;
        // PSYMBOL_INFO pSymbol = & u.symb;
        // pSymbol->SizeOfStruct = sizeof(SYMBOL_INFO);
        // pSymbol->MaxNameLen = emMaxNameLength;

        // PDWORD64 symDisplacement = 0;  // Displacement of the input address,
        //                             // relative to the start of the symbol

        // DWORD lineDisplacement = 0;
        // IMAGEHLP_LINE64  line;
        // line.SizeOfStruct = sizeof(line);
        // line.LineNumber = 0;
        // BOOL bLine = FALSE;

        // bLine = SymGetLineFromAddr64( m_hProcess, sf.AddrPC.Offset,
        //     & lineDisplacement, & line );
        // if ( SymFromAddr(m_hProcess, sf.AddrPC.Offset,
        //                         symDisplacement, pSymbol) )
        // {
        //     if( bLine ) {
        //         _snprintf( buf, buflen,
        //             ADDR_FORMAT "  " ADDR_FORMAT "   %s() line %d\n",
        //             sf.AddrPC.Offset, pFrame,
        //             pSymbol->Name, line.LineNumber );
        //     } else {
        //         _snprintf( buf, buflen,
        //             ADDR_FORMAT "  " ADDR_FORMAT "  %s() + %X\n",
        //             sf.AddrPC.Offset, pFrame,
        //             pSymbol->Name, symDisplacement );
        //     }

        // }
        // else    // No symbol found.  Print out the logical address instead.
        // {
        //     DWORD err = GetLastError();
        //     FIXED_ARRAY( szModule , TCHAR, MAX_PATH );
        //     szModule[0] = '\0';
        //     DWORD section = 0, offset = 0;

        //     GetLogicalAddress(  (PVOID)sf.AddrPC.Offset,
        //                         szModule, sizeof(szModule), section, offset );

        //     _snprintf( buf, buflen,
        //         ADDR_FORMAT "  " ADDR_FORMAT "  %04X:%08X %s (err = %d)\n",
        //         sf.AddrPC.Offset, pFrame,
        //         section, offset, szModule, err );
        //     result = true;
        // }

        // if( m_Levels == 0 ) {
        //     // dbbTrace::OutputString( buf, false );
        // } else {
        //     // Save line
        //     size_t l = strlen(buf);
        //     if( i_line >= m_Levels || i_buf + l >= m_Bytes ) {
        //         // We have saved all of the stack we can save
        //         break;
        //     }
        //     buf[ l - 1 ] = '\0';    // Remove trailing '\n'
        //     char * s = & m_Buffer[ i_buf ];
        //     m_Lines[ i_line++ ] = s;
        //     strncpy( s, buf, l );
        //     i_buf += l;
        // }
    } // while

    return result;
}


int main() {
    printf("started\n");
    CONTEXT context;
    RtlCaptureContext(&context);
    ImagehlpStackWalk(&context);
}
