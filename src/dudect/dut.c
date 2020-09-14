#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "random.h"
#include "dut.h"
#include "api.h"
#include "crypto_aead.h"
#include "settings.h"


const size_t chunk_size = CRYPTO_KEYBYTES;
const size_t clen = CRYPTO_MSGBYTES + CRYPTO_ABYTES;
const size_t number_measurements = DUDECT_MEASUREMENTS;

uint8_t *npub;
uint8_t *nsec;
uint8_t *msg;
uint8_t *ad;
uint8_t *cipher;
unsigned long long int *cipher_size;


uint8_t do_one_computation(uint8_t *data) {
  #if ANALYSE_ENCRYPT
  return (uint8_t)crypto_aead_encrypt(cipher, cipher_size, msg, CRYPTO_MSGBYTES, ad, CRYPTO_ADBYTES, nsec, npub, data);
  #else
  return (uint8_t)crypto_aead_decrypt(cipher, cipher_size, nsec, msg, CRYPTO_MSGBYTES, ad, CRYPTO_ADBYTES, npub, data);
  #endif
}


void generate_test_vectors() {
  npub = calloc(CRYPTO_NPUBBYTES, sizeof(uint8_t));
  msg = calloc(CRYPTO_MSGBYTES, sizeof(uint8_t));
  ad = calloc(CRYPTO_ADBYTES, sizeof(uint8_t));
  cipher = calloc(clen, sizeof(uint8_t));
  cipher_size = calloc(1, sizeof(unsigned long long int));

  if (CRYPTO_NSECBYTES > 0) {
    nsec = calloc(CRYPTO_NSECBYTES, sizeof(uint8_t));
    randombytes(nsec, CRYPTO_NSECBYTES * sizeof(uint8_t));
  } else {
    //Dont do anything
  }

  //Fill randombytes
  randombytes(npub, CRYPTO_NPUBBYTES * sizeof(uint8_t));
  randombytes(msg, CRYPTO_MSGBYTES * sizeof(uint8_t));
  randombytes(ad, CRYPTO_ADBYTES * sizeof(uint8_t));
}

void init_dut(void) {
  printf("Generating test vectors\n");
  generate_test_vectors();

  printf("Starting dudect\n");
}

/*
 * This is a simple example on how good test vectors
 * accelerate leakage detection. The code below defines
 * two input classes:
 *  a) random input
 *  b) input fixed to 0
 *
 * This helps to detect timing leakage in do_one_computation()
 * above. The process is faster if the input is equal to the
 * `secret` variable inside do_one_computation(). In that case,
 * the timing difference is be much larger and hence more
 * easily detectable. Otherwise, the timing difference is still
 * detectable but more measurements are needed. (Try changing
 * the value of `secret` variable.)
 *
 * Morale: carefully crafted input vectors detect much faster
 * leakage (``whitebox'' testing).
 * 
 */
void prepare_inputs(uint8_t *input_data, uint8_t *classes) {
  randombytes(input_data, number_measurements * chunk_size);
  for (size_t i = 0; i < number_measurements; i++) {
    classes[i] = randombit();
    if (classes[i] == 0) {
      memset(input_data + (size_t)i * chunk_size, 0x00, chunk_size);
    } else {
      // leave random
    }
  }
}
