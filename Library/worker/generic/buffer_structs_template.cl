/*
    In- and out- buffer structures (of int32), with variable sizes, for hashing.
    These allow indexing just using just get_global_id(0)
    Variables tagged with <..> are replaced, so we can specify just enough room for the data.
    These are:
        - hashBlockSize_bits   : The hash's block size in Bits
        - inMaxNumBlocks      : per hash operation
        - hashDigestSize_bits   : The hash's digest size in Bits

    Originally adapted from Bjorn Kerler's sha256.cl
    MIT License
*/

// All macros left defined for usage in the program
#define ceilDiv(n,d) (((n) + (d) - 1) / (d))

#define hashBlockSize_bytes ceilDiv(<hashBlockSize_bits>, 8) // Needs to be a multiple of 4
#define hashBlockSize_int32 ceilDiv(hashBlockSize_bytes, 4)
#define hashDigestSize_bytes ceilDiv(<hashDigestSize_bits>, 8)
#define hashDigestSize_int32 ceilDiv(hashDigestSize_bytes, 4)

// Practical sizes of buffers.
#define inBufferSize ceilDiv(<inBufferSize_bytes>, 4)
#define outBufferSize ceilDiv(<outBufferSize_bytes>, 4)
#define saltBufferSize ceilDiv(<saltBufferSize_bytes>, 4)
#define ctBufferSize ceilDiv(<ctBufferSize_bytes>, 4)

// The structs themselves
typedef struct {
	unsigned int length; // in bytes
	unsigned int buffer[inBufferSize];
} inbuf;

typedef struct {
	unsigned int buffer[outBufferSize];
} outbuf;

// Salt buffer, used by pbkdf2 & pbe
typedef struct {
	unsigned int length; // in bytes
	unsigned int buffer[saltBufferSize];
} saltbuf;

// ciphertext buffer, used in pbe.
// no code relating to this in the opencl.py core, dealt with in signal_pbe_mac.cl as it's a special case
typedef struct {
	unsigned int length; // in bytes
	unsigned int buffer[ctBufferSize];
} ctbuf;



// ========== Debugging functions ============

#define def_printFromInt(tag, funcName, end)               \
/* For printing the string of bytes stored in an array of integers. Option to print hex. */    \
static void funcName(tag const unsigned int *arr, const unsigned int len_bytes, const bool hex)\
{                                           \
    for (int j = 0; j < len_bytes; j++){    \
        int v = arr[j / 4];                 \
        int r = (j % 4) * 8;                \
        /* Prints little endian, since that's what we use */   \
        v = (v >> r) & 0xFF;                \
        if (hex) {                          \
            printf("%02x", v);              \
        } else {                            \
            printf("%c", (char)v);          \
        }                                   \
    }                                       \
    printf(end);                            \
}

def_printFromInt(__private, printFromInt, "")
def_printFromInt(__global, printFromInt_glbl, "")
def_printFromInt(__private, printFromInt_n, "\n")