/*
    Qualcomm HMAC OpenCL Optimized kernel
    (c) B. Kerler 2018-2021
    MIT License
*/

/*
    pbkdf2 and HMAC implementation
    requires implementation of PRF (pseudo-random function),
      probably using HMAC and an implementation of hash_main
*/
/*
    REQ: outBuf.buffer must have space for ceil(dkLen / PRF_output_bytes) * PRF_output_bytes
    REQ: PRF implementation MUST allow that output may be the salt (m in hmac)
    inBuffer / pwdBuffer / the like are not const to allow for padding
*/

// Determine (statically) the actual required buffer size
//   Just allowing for MD padding: 64 bits for int, 1 for the 1-pad = 3 int32s.
#define sizeForHash(reqSize) (ceilDiv((reqSize) + 2 + 1, hashBlockSize_int32) * hashBlockSize_int32)

/* Swaps between little and big-endian*/
#define swapEndian(x) (rotate((x) & 0x00FF00FF, 24U) | rotate((x) & 0xFF00FF00, 8U))

__constant const unsigned int opad = 0x5c5c5c5c;
__constant const unsigned int ipad = 0x36363636;
__constant const unsigned int xoredPad = opad ^ ipad;
// Slightly ugly: large enough for hmac_main usage, and tight for pbkdf2
#define m_buffer_size (saltBufferSize + 1)

static void hmac(__global unsigned int *K, const unsigned int K_len_bytes,
    const unsigned int *m, const unsigned int m_len_bytes, unsigned int *output)
{
    // REQ: If K_len_bytes isn't divisible by 4, final int should be clean (0s to the end)
    // REQ: s digestSize is a multiple of 4 bytes

    /* Declare the space for input to the last hash function:
         Compute and write K_ ^ opad to the first block of this. This will be the only place that we store K_ */

    #define size_2 sizeForHash(hashBlockSize_int32 + hashDigestSize_int32)
    unsigned int input_2[size_2] = {0};
    #undef size_2

    int end;
    if (K_len_bytes <= hashBlockSize_bytes)
    {
        end = (K_len_bytes + 3) / 4;
        // XOR with opad and slightly pad with zeros..
        for (int j = 0; j < end; j++){
            input_2[j] = K[j] ^ opad;
        }
    } else {
        end = hashDigestSize_int32;
        // Hash K to get K'. XOR with opad..
        hash_glbl_to_priv(K, K_len_bytes, input_2);
        for (int j = 0; j < hashDigestSize_int32; j++){
            input_2[j] ^= opad;
        }
    }
    // And if short, pad with 0s to the BLOCKsize, completing xor with opad
    for (int j = end; j < hashBlockSize_int32; j++){
        input_2[j] = opad;
    }

    // Copy K' ^ ipad into the first block.
    // Be careful: hash needs a whole block after the end. ceilDiv from buffer_structs
    #define size_1 sizeForHash(hashBlockSize_int32 + m_buffer_size)

    // K' ^ ipad into the first block
    unsigned int input_1[size_1] = {0};
    #undef size_1
    for (int j = 0; j < hashBlockSize_int32; j++){
        input_1[j] = input_2[j]^xoredPad;
    }

    // Slightly inefficient copying m in..
    int m_len_int32 = (m_len_bytes + 3) / 4;
    for (int j = 0; j < m_len_int32; j++){
        input_1[hashBlockSize_int32 + j] = m[j];
    }

    // Hash input1 into the second half of input2
    int leng = hashBlockSize_bytes + m_len_bytes;
    hash_private(input_1, leng, input_2 + hashBlockSize_int32);

    // Hash input2 into output!
    hash_private(input_2, hashBlockSize_bytes + hashDigestSize_bytes, output);
}

#undef sizeForHash

// Might as well be very clean
#undef swapEndian

// Exposing HMAC in the same way. Useful for testing atleast.
__kernel void hmac_main(__global inbuf *inbuffer, __global const saltbuf *saltbuffer, __global outbuf *outbuffer)
{
    int counter=0;
    int i=0;
    int j=0;
    unsigned int idx = get_global_id(0);
    unsigned int pwdLen_bytes = inbuffer[idx].length;
    __global unsigned int *pwdBuffer = inbuffer[idx].buffer;

    // Copy salt just to cheer the compiler up
    int saltLen_bytes = saltbuffer[0].length;
    int saltLen_int32 = ceilDiv(saltLen_bytes, 4);
    unsigned int personal_salt[saltBufferSize] = {0};

    for (j = 0; j < saltLen_int32; j++){
        personal_salt[j] = saltbuffer[0].buffer[j];
    }

    // Call hmac, with local
    unsigned int out[hashDigestSize_int32];
    
    unsigned int V[hashDigestSize_int32]={0};
    for (counter=0;counter<10000;counter++)
    {
        hmac(pwdBuffer, pwdLen_bytes, personal_salt, saltLen_bytes, out);
        for (j=0;j<hashDigestSize_int32;j++)
        {
            V[j] ^= out[j];
            personal_salt[j] = out[j];
        }
    }
    
    for (int j = 0; j < hashDigestSize_int32; j++){
        outbuffer[idx].buffer[j] = out[j];
        outbuffer[idx].buffer[j+hashDigestSize_int32] = V[j];
    }
}