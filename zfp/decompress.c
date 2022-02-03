#include <emscripten.h>
#include "zfp.h"

int decompress(float* array, size_t nx, size_t ny, size_t nz, void *buffer, int bufsize)
{
  int status = 0;    /* return value: 0 = success */
  zfp_type type;     /* array scalar type */
  zfp_field* field;  /* array meta data */
  zfp_stream* zfp;   /* compressed stream */
  // void* buffer;      /* storage for compressed stream */
  // size_t bufsize;    /* byte size of compressed buffer */
  bitstream* stream; /* bit stream to write to or read from */
  size_t zfpsize;    /* byte size of compressed stream */

  /* allocate meta data for the 3D array a[nz][ny][nx] */
  type = zfp_type_float;
  field = zfp_field_3d(array, type, nx, ny, nz);

  /* allocate meta data for a compressed stream */
  zfp = zfp_stream_open(NULL);

  /* set compression mode and parameters via one of four functions */
  // zfp_stream_set_reversible(zfp);
  // zfp_stream_set_rate(zfp, 1, type, zfp_field_dimensionality(field), zfp_false);
  zfp_stream_set_precision(zfp, 10);
  // zfp_stream_set_accuracy(zfp, 1e-3);

  /* allocate buffer for compressed data */
  // bufsize = zfp_stream_maximum_size(zfp, field);
  // buffer = malloc(bufsize);

  /* associate bit stream with allocated buffer */
  stream = stream_open(buffer, bufsize);
  zfp_stream_set_bit_stream(zfp, stream);
  zfp_stream_rewind(zfp);

  status = zfp_decompress(zfp, field);

  /* clean up */
  zfp_field_free(field);
  zfp_stream_close(zfp);
  stream_close(stream);
  // free(buffer);
  // free(array);

  return status;
}

int main()
{
  EM_ASM( ready() );
}
