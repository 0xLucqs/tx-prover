#ifndef TX_PROVER_FFI_H
#define TX_PROVER_FFI_H

#include <stdint.h>

typedef void (*LogCallback)(const char *message);

/// Run the privacy demo prover end-to-end.
/// Returns 0 on success, non-zero on failure.
/// Progress and errors are reported through `callback`.
int32_t prove_privacy_demo(LogCallback callback);

#endif
