import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Pure Dart AES-256-CBC with PKCS#7, SHA-256, HMAC-SHA-256, and PBKDF2.
/// Zero native C/NDK dependencies; runs securely across Android, iOS, Desktop, and Web.
class AesCipherUtil {
  static const List<int> _sBox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
  ];

  static const List<int> _invSBox = [
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,
    0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,
    0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,
    0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,
    0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
    0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,
    0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,
    0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,
    0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
    0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,
    0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
    0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
    0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d,
  ];

  static const List<int> _rcon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  static Uint32List _expandKey256(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError('AES-256 key must be exactly 32 bytes (256 bits)');
    }
    const int nk = 8;
    const int nb = 4;
    const int nr = 14;
    final int wLength = nb * (nr + 1); // 60 words
    final w = Uint32List(wLength);

    for (int i = 0; i < nk; i++) {
      w[i] = (key[4 * i] << 24) |
          (key[4 * i + 1] << 16) |
          (key[4 * i + 2] << 8) |
          key[4 * i + 3];
    }

    for (int i = nk; i < wLength; i++) {
      int temp = w[i - 1];
      if (i % nk == 0) {
        temp = _subWord(_rotWord(temp)) ^ (_rcon[i ~/ nk] << 24);
      } else if (i % nk == 4) {
        temp = _subWord(temp);
      }
      w[i] = (w[i - nk] ^ temp) & 0xFFFFFFFF;
    }
    return w;
  }

  static int _rotWord(int w) {
    return (((w << 8) & 0xFFFFFFFF) | ((w >>> 24) & 0xFF)) & 0xFFFFFFFF;
  }

  static int _subWord(int w) {
    return ((_sBox[(w >>> 24) & 0xFF] << 24) |
        (_sBox[(w >>> 16) & 0xFF] << 16) |
        (_sBox[(w >>> 8) & 0xFF] << 8) |
        _sBox[w & 0xFF]) &
        0xFFFFFFFF;
  }

  static int _xt(int x) {
    return ((x << 1) ^ (((x >>> 7) & 1) * 0x11b)) & 0xFF;
  }

  static int _mul(int a, int b) {
    int res = 0;
    int curA = a;
    for (int i = 0; i < 8; i++) {
      if ((b & (1 << i)) != 0) {
        res ^= curA;
      }
      curA = _xt(curA);
    }
    return res & 0xFF;
  }

  static void _encryptBlock(Uint8List state, Uint32List w) {
    // AddRoundKey 0
    for (int c = 0; c < 4; c++) {
      final roundWord = w[c];
      state[c * 4] ^= (roundWord >>> 24) & 0xFF;
      state[c * 4 + 1] ^= (roundWord >>> 16) & 0xFF;
      state[c * 4 + 2] ^= (roundWord >>> 8) & 0xFF;
      state[c * 4 + 3] ^= roundWord & 0xFF;
    }

    for (int round = 1; round <= 14; round++) {
      // SubBytes
      for (int i = 0; i < 16; i++) {
        state[i] = _sBox[state[i]];
      }

      // ShiftRows
      final s1 = state[1];
      state[1] = state[5];
      state[5] = state[9];
      state[9] = state[13];
      state[13] = s1;

      final s2 = state[2];
      final s6 = state[6];
      state[2] = state[10];
      state[6] = state[14];
      state[10] = s2;
      state[14] = s6;

      final s15 = state[15];
      state[15] = state[11];
      state[11] = state[7];
      state[7] = state[3];
      state[3] = s15;

      // MixColumns (rounds 1..13)
      if (round < 14) {
        for (int c = 0; c < 4; c++) {
          final idx = c * 4;
          final a0 = state[idx];
          final a1 = state[idx + 1];
          final a2 = state[idx + 2];
          final a3 = state[idx + 3];

          state[idx] = _xt(a0) ^ _xt(a1) ^ a1 ^ a2 ^ a3;
          state[idx + 1] = a0 ^ _xt(a1) ^ _xt(a2) ^ a2 ^ a3;
          state[idx + 2] = a0 ^ a1 ^ _xt(a2) ^ _xt(a3) ^ a3;
          state[idx + 3] = _xt(a0) ^ a0 ^ a1 ^ a2 ^ _xt(a3);
        }
      }

      // AddRoundKey
      final base = round * 4;
      for (int c = 0; c < 4; c++) {
        final roundWord = w[base + c];
        state[c * 4] ^= (roundWord >>> 24) & 0xFF;
        state[c * 4 + 1] ^= (roundWord >>> 16) & 0xFF;
        state[c * 4 + 2] ^= (roundWord >>> 8) & 0xFF;
        state[c * 4 + 3] ^= roundWord & 0xFF;
      }
    }
  }

  static void _decryptBlock(Uint8List state, Uint32List w) {
    // AddRoundKey 14
    final base14 = 14 * 4;
    for (int c = 0; c < 4; c++) {
      final roundWord = w[base14 + c];
      state[c * 4] ^= (roundWord >>> 24) & 0xFF;
      state[c * 4 + 1] ^= (roundWord >>> 16) & 0xFF;
      state[c * 4 + 2] ^= (roundWord >>> 8) & 0xFF;
      state[c * 4 + 3] ^= roundWord & 0xFF;
    }

    for (int round = 13; round >= 0; round--) {
      // InvShiftRows
      final s13 = state[13];
      state[13] = state[9];
      state[9] = state[5];
      state[5] = state[1];
      state[1] = s13;

      final s2 = state[2];
      final s6 = state[6];
      state[2] = state[10];
      state[6] = state[14];
      state[10] = s2;
      state[14] = s6;

      final s3 = state[3];
      state[3] = state[7];
      state[7] = state[11];
      state[11] = state[15];
      state[15] = s3;

      // InvSubBytes
      for (int i = 0; i < 16; i++) {
        state[i] = _invSBox[state[i]];
      }

      // AddRoundKey
      final base = round * 4;
      for (int c = 0; c < 4; c++) {
        final roundWord = w[base + c];
        state[c * 4] ^= (roundWord >>> 24) & 0xFF;
        state[c * 4 + 1] ^= (roundWord >>> 16) & 0xFF;
        state[c * 4 + 2] ^= (roundWord >>> 8) & 0xFF;
        state[c * 4 + 3] ^= roundWord & 0xFF;
      }

      // InvMixColumns (rounds 13 down to 1)
      if (round > 0) {
        for (int c = 0; c < 4; c++) {
          final idx = c * 4;
          final a0 = state[idx];
          final a1 = state[idx + 1];
          final a2 = state[idx + 2];
          final a3 = state[idx + 3];

          state[idx] = _mul(0x0e, a0) ^ _mul(0x0b, a1) ^ _mul(0x0d, a2) ^ _mul(0x09, a3);
          state[idx + 1] = _mul(0x09, a0) ^ _mul(0x0e, a1) ^ _mul(0x0b, a2) ^ _mul(0x0d, a3);
          state[idx + 2] = _mul(0x0d, a0) ^ _mul(0x09, a1) ^ _mul(0x0e, a2) ^ _mul(0x0b, a3);
          state[idx + 3] = _mul(0x0b, a0) ^ _mul(0x0d, a1) ^ _mul(0x09, a2) ^ _mul(0x0e, a3);
        }
      }
    }
  }

  // PKCS#7 Padding
  static Uint8List padPkcs7(Uint8List data) {
    final padLen = 16 - (data.length % 16);
    final padded = Uint8List(data.length + padLen);
    padded.setRange(0, data.length, data);
    for (int i = data.length; i < padded.length; i++) {
      padded[i] = padLen;
    }
    return padded;
  }

  static Uint8List unpadPkcs7(Uint8List data) {
    if (data.isEmpty || data.length % 16 != 0) {
      throw const FormatException('Invalid ciphertext block size');
    }
    final padLen = data.last;
    if (padLen < 1 || padLen > 16) {
      throw const FormatException('Invalid PKCS7 padding byte');
    }
    for (int i = data.length - padLen; i < data.length; i++) {
      if (data[i] != padLen) {
        throw const FormatException('Corrupted PKCS7 padding');
      }
    }
    return Uint8List.sublistView(data, 0, data.length - padLen);
  }

  // AES-256-CBC Encrypt
  static Uint8List aesCbcEncrypt(Uint8List plaintext, Uint8List key, Uint8List iv) {
    if (key.length != 32) throw ArgumentError('AES-256 requires 32-byte key');
    if (iv.length != 16) throw ArgumentError('IV must be 16 bytes');

    final padded = padPkcs7(plaintext);
    final w = _expandKey256(key);
    final ciphertext = Uint8List(padded.length);

    var prevBlock = Uint8List.fromList(iv);
    final block = Uint8List(16);

    for (int offset = 0; offset < padded.length; offset += 16) {
      for (int i = 0; i < 16; i++) {
        block[i] = padded[offset + i] ^ prevBlock[i];
      }
      _encryptBlock(block, w);
      ciphertext.setRange(offset, offset + 16, block);
      prevBlock = block;
    }
    return ciphertext;
  }

  // AES-256-CBC Decrypt
  static Uint8List aesCbcDecrypt(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    if (key.length != 32) throw ArgumentError('AES-256 requires 32-byte key');
    if (iv.length != 16) throw ArgumentError('IV must be 16 bytes');
    if (ciphertext.isEmpty || ciphertext.length % 16 != 0) {
      throw const FormatException('Ciphertext size must be a multiple of 16');
    }

    final w = _expandKey256(key);
    final plaintext = Uint8List(ciphertext.length);
    var prevBlock = Uint8List.fromList(iv);
    final block = Uint8List(16);

    for (int offset = 0; offset < ciphertext.length; offset += 16) {
      final currentCipher = Uint8List.sublistView(ciphertext, offset, offset + 16);
      block.setRange(0, 16, currentCipher);
      _decryptBlock(block, w);
      for (int i = 0; i < 16; i++) {
        plaintext[offset + i] = block[i] ^ prevBlock[i];
      }
      prevBlock = currentCipher;
    }
    return unpadPkcs7(plaintext);
  }

  // SHA-256
  static const List<int> _kSha256 = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];

  static Uint8List sha256(Uint8List data) {
    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final int bitLen = data.length * 8;
    final int padLen = (data.length % 64 < 56)
        ? (56 - (data.length % 64))
        : (120 - (data.length % 64));
    final padded = Uint8List(data.length + padLen + 8);
    padded.setRange(0, data.length, data);
    padded[data.length] = 0x80;

    final bData = ByteData.view(padded.buffer);
    bData.setUint32(padded.length - 8, bitLen >>> 32);
    bData.setUint32(padded.length - 4, bitLen & 0xFFFFFFFF);

    final w = Uint32List(64);

    for (int offset = 0; offset < padded.length; offset += 64) {
      for (int i = 0; i < 16; i++) {
        w[i] = bData.getUint32(offset + (i * 4));
      }
      for (int i = 16; i < 64; i++) {
        final s0 = (_rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3)) & 0xFFFFFFFF;
        final s1 = (_rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10)) & 0xFFFFFFFF;
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h0;
      int b = h1;
      int c = h2;
      int d = h3;
      int e = h4;
      int f = h5;
      int g = h6;
      int h = h7;

      for (int i = 0; i < 64; i++) {
        final s1 = (_rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25)) & 0xFFFFFFFF;
        final ch = ((e & f) ^ ((~e) & g)) & 0xFFFFFFFF;
        final t1 = (h + s1 + ch + _kSha256[i] + w[i]) & 0xFFFFFFFF;
        final s0 = (_rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22)) & 0xFFFFFFFF;
        final maj = ((a & b) ^ (a & c) ^ (b & c)) & 0xFFFFFFFF;
        final t2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + t1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final result = Uint8List(32);
    final resView = ByteData.view(result.buffer);
    resView.setUint32(0, h0);
    resView.setUint32(4, h1);
    resView.setUint32(8, h2);
    resView.setUint32(12, h3);
    resView.setUint32(16, h4);
    resView.setUint32(20, h5);
    resView.setUint32(24, h6);
    resView.setUint32(28, h7);
    return result;
  }

  static int _rotr(int val, int n) {
    return (((val >>> n) | (val << (32 - n))) & 0xFFFFFFFF);
  }

  // HMAC-SHA256
  static Uint8List hmacSha256(Uint8List key, Uint8List data) {
    var k = Uint8List(64);
    if (key.length > 64) {
      final hashedKey = sha256(key);
      k.setRange(0, hashedKey.length, hashedKey);
    } else {
      k.setRange(0, key.length, key);
    }

    final iPad = Uint8List(64);
    final oPad = Uint8List(64);
    for (int i = 0; i < 64; i++) {
      iPad[i] = k[i] ^ 0x36;
      oPad[i] = k[i] ^ 0x5c;
    }

    final innerMsg = Uint8List(64 + data.length);
    innerMsg.setRange(0, 64, iPad);
    innerMsg.setRange(64, innerMsg.length, data);
    final innerHash = sha256(innerMsg);

    final outerMsg = Uint8List(64 + 32);
    outerMsg.setRange(0, 64, oPad);
    outerMsg.setRange(64, outerMsg.length, innerHash);
    return sha256(outerMsg);
  }

  // PBKDF2-HMAC-SHA256
  static Uint8List pbkdf2(Uint8List password, Uint8List salt, int iterations, int keyLength) {
    final numBlocks = (keyLength + 31) ~/ 32;
    final derived = Uint8List(numBlocks * 32);

    for (int blockIdx = 1; blockIdx <= numBlocks; blockIdx++) {
      final saltBlock = Uint8List(salt.length + 4);
      saltBlock.setRange(0, salt.length, salt);
      saltBlock[salt.length] = (blockIdx >>> 24) & 0xFF;
      saltBlock[salt.length + 1] = (blockIdx >>> 16) & 0xFF;
      saltBlock[salt.length + 2] = (blockIdx >>> 8) & 0xFF;
      saltBlock[salt.length + 3] = blockIdx & 0xFF;

      var u = hmacSha256(password, saltBlock);
      final f = Uint8List.fromList(u);

      for (int iter = 1; iter < iterations; iter++) {
        u = hmacSha256(password, u);
        for (int i = 0; i < 32; i++) {
          f[i] ^= u[i];
        }
      }
      derived.setRange((blockIdx - 1) * 32, blockIdx * 32, f);
    }

    return Uint8List.sublistView(derived, 0, keyLength);
  }

  /// High-level Encrypt: JSON -> Authenticated AES-256 Envelope
  static String encryptBackupPayload(String plaintextJson, String passphrase, {int iterations = 10000}) {
    if (passphrase.trim().isEmpty) {
      throw ArgumentError('Backup passphrase cannot be empty');
    }
    final rand = Random.secure();
    final salt = Uint8List(16);
    final iv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      salt[i] = rand.nextInt(256);
      iv[i] = rand.nextInt(256);
    }

    final passBytes = Uint8List.fromList(utf8.encode(passphrase.trim()));
    final derived = pbkdf2(passBytes, salt, iterations, 64);
    final encKey = Uint8List.sublistView(derived, 0, 32);
    final macKey = Uint8List.sublistView(derived, 32, 64);

    final plainBytes = Uint8List.fromList(utf8.encode(plaintextJson));
    final ciphertext = aesCbcEncrypt(plainBytes, encKey, iv);

    final toMac = Uint8List(salt.length + iv.length + ciphertext.length);
    toMac.setRange(0, salt.length, salt);
    toMac.setRange(salt.length, salt.length + iv.length, iv);
    toMac.setRange(salt.length + iv.length, toMac.length, ciphertext);
    final mac = hmacSha256(macKey, toMac);

    final payload = {
      'format': 'arthatrack_encrypted_backup',
      'version': 1,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'salt': base64.encode(salt),
      'iv': base64.encode(iv),
      'ciphertext': base64.encode(ciphertext),
      'hmac': base64.encode(mac),
    };

    return jsonEncode(payload);
  }

  /// High-level Decrypt: Authenticated AES-256 Envelope -> JSON
  static String decryptBackupPayload(String encryptedJson, String passphrase) {
    if (passphrase.trim().isEmpty) {
      throw const FormatException('Passphrase cannot be empty');
    }

    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(encryptedJson) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Invalid backup file: not valid JSON');
    }

    if (payload['format'] != 'arthatrack_encrypted_backup') {
      throw const FormatException('Unsupported or corrupted backup file format');
    }

    final salt = base64.decode(payload['salt'] as String);
    final iv = base64.decode(payload['iv'] as String);
    final ciphertext = base64.decode(payload['ciphertext'] as String);
    final expectedHmac = base64.decode(payload['hmac'] as String);
    final iterations = (payload['iterations'] as int?) ?? 10000;

    final passBytes = Uint8List.fromList(utf8.encode(passphrase.trim()));
    final derived = pbkdf2(passBytes, Uint8List.fromList(salt), iterations, 64);
    final encKey = Uint8List.sublistView(derived, 0, 32);
    final macKey = Uint8List.sublistView(derived, 32, 64);

    final toMac = Uint8List(salt.length + iv.length + ciphertext.length);
    toMac.setRange(0, salt.length, salt);
    toMac.setRange(salt.length, salt.length + iv.length, iv);
    toMac.setRange(salt.length + iv.length, toMac.length, ciphertext);
    final actualMac = hmacSha256(macKey, toMac);

    // Constant-time comparison
    if (actualMac.length != expectedHmac.length) {
      throw const FormatException('Incorrect password or corrupted backup file');
    }
    int diff = 0;
    for (int i = 0; i < actualMac.length; i++) {
      diff |= (actualMac[i] ^ expectedHmac[i]);
    }
    if (diff != 0) {
      throw const FormatException('Incorrect password or corrupted backup file');
    }

    final plainBytes = aesCbcDecrypt(
      Uint8List.fromList(ciphertext),
      encKey,
      Uint8List.fromList(iv),
    );
    return utf8.decode(plainBytes);
  }

  /// Generates a human-friendly 4-word random recovery passphrase
  static String generatePassphrase() {
    const words = [
      'lotus', 'peacock', 'banyan', 'ganga', 'himalaya', 'saffron', 'emerald', 'sapphire',
      'monsoon', 'sunrise', 'aurora', 'whisper', 'harmony', 'canyon', 'falcon', 'summit',
      'solstice', 'zenith', 'phoenix', 'breeze', 'tamarind', 'cardamom', 'radiant', 'shelter',
      'fortress', 'galaxy', 'starlight', 'orbit', 'compass', 'voyager', 'beacon', 'harbor'
    ];
    final rand = Random.secure();
    final chosen = <String>[];
    for (int i = 0; i < 4; i++) {
      chosen.add(words[rand.nextInt(words.length)]);
    }
    final suffix = (100 + rand.nextInt(900)).toString();
    return '${chosen.join('-')}-$suffix';
  }
}
