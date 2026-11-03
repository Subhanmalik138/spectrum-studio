import 'dart:math' as math;

/// Pure-Dart radix-2 FFT (iterative Cooley-Tukey) plus helpers that turn a
/// raw PCM window into log-spaced frequency band magnitudes.
///
/// This is real frequency analysis: no randomness anywhere in the pipeline.
/// The visualizer is driven only by these magnitudes and the beat tracker.
class Fft {
  /// In-place FFT on interleaved-free real/imag arrays. [n] must be a power
  /// of two and equal to both arrays' length.
  static void fft(List<double> real, List<double> imag) {
    final n = real.length;
    // Bit-reversal permutation.
    for (int i = 1, j = 0; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tr = real[i];
        real[i] = real[j];
        real[j] = tr;
        final ti = imag[i];
        imag[i] = imag[j];
        imag[j] = ti;
      }
    }
    // Butterfly stages.
    for (int len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wr = math.cos(ang);
      final wi = math.sin(ang);
      for (int i = 0; i < n; i += len) {
        double cwr = 1.0, cwi = 0.0;
        for (int k = 0; k < len ~/ 2; k++) {
          final ur = real[i + k];
          final ui = imag[i + k];
          final vr = real[i + k + len ~/ 2] * cwr -
              imag[i + k + len ~/ 2] * cwi;
          final vi = real[i + k + len ~/ 2] * cwi +
              imag[i + k + len ~/ 2] * cwr;
          real[i + k] = ur + vr;
          imag[i + k] = ui + vi;
          real[i + k + len ~/ 2] = ur - vr;
          imag[i + k + len ~/ 2] = ui - vi;
          final nwr = cwr * wr - cwi * wi;
          cwi = cwr * wi + cwi * wr;
          cwr = nwr;
        }
      }
    }
  }

  /// Hann window coefficient for sample [i] of [n].
  static double hann(int i, int n) =>
      0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));

  /// Computes [bandCount] log-spaced band magnitudes (0..1, roughly) from a
  /// PCM [window] of length [fftSize]. Samples are expected in -1..1.
  /// Returns one value per band, already smoothed with [previous] if given.
  static List<double> bandsFromWindow(
    List<double> pcm,
    int offset,
    int fftSize,
    int sampleRate,
    int bandCount, {
    List<double>? previous,
    double smoothing = 0.55,
  }) {
    final real = List<double>.filled(fftSize, 0);
    final imag = List<double>.filled(fftSize, 0);
    for (int i = 0; i < fftSize; i++) {
      final idx = offset + i;
      final s = (idx >= 0 && idx < pcm.length) ? pcm[idx] : 0.0;
      real[i] = s * hann(i, fftSize);
    }
    fft(real, imag);
    final bins = fftSize ~/ 2;
    final mags = List<double>.generate(
      bins,
      (i) => math.sqrt(real[i] * real[i] + imag[i] * imag[i]) / fftSize,
    );
    // Log-spaced bands from 20 Hz to Nyquist.
    const minFreq = 20.0;
    final maxFreq = sampleRate / 2;
    final bands = List<double>.filled(bandCount, 0);
    for (int b = 0; b < bandCount; b++) {
      final f0 = minFreq * math.pow(maxFreq / minFreq, b / bandCount);
      final f1 = minFreq * math.pow(maxFreq / minFreq, (b + 1) / bandCount);
      final bin0 = ((f0 / sampleRate) * fftSize).floor().clamp(1, bins - 1);
      final bin1 = ((f1 / sampleRate) * fftSize).ceil().clamp(bin0 + 1, bins);
      double sum = 0;
      for (int k = bin0; k < bin1; k++) {
        sum += mags[k];
      }
      double v = sum / (bin1 - bin0);
      // Log compression into a 0..1-ish range.
      v = (math.log(1 + v * 220) / math.log(221)).clamp(0.0, 1.0);
      if (previous != null) {
        v = previous[b] * smoothing + v * (1 - smoothing);
      }
      bands[b] = v;
    }
    return bands;
  }
}

/// Spectral-flux beat tracker: watches bass-band energy rises against a
/// short moving average and emits a decaying beat pulse in 0..1.
class BeatTracker {
  final List<double> _history = [];
  double _pulse = 0;

  /// Feed one frame's band magnitudes; returns the current beat pulse.
  double update(List<double> bands) {
    double bass = 0;
    final n = (bands.length * 0.18).ceil().clamp(1, bands.length);
    for (int i = 0; i < n; i++) {
      bass += bands[i];
    }
    bass /= n;
    _history.add(bass);
    if (_history.length > 43) _history.removeAt(0);
    final avg = _history.reduce((a, b) => a + b) / _history.length;
    double variance = 0;
    for (final v in _history) {
      variance += (v - avg) * (v - avg);
    }
    variance /= _history.length;
    final threshold = avg + 0.6 * math.sqrt(variance);
    if (bass > threshold && bass > avg * 1.12) {
      _pulse = 1.0;
    } else {
      _pulse = (_pulse - 0.09).clamp(0.0, 1.0);
    }
    return _pulse;
  }
}
