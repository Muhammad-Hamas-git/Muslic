package com.ryanheise.just_audio;

import androidx.media3.common.C;
import androidx.media3.common.audio.AudioProcessor;
import androidx.media3.common.audio.BaseAudioProcessor;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * müslic addition: reverb + echo (delay) on the decoded audio.
 *
 * Runs after the speed/pitch stage (see {@link FxProcessorChain}), so the
 * reverb tail and echo spacing stay natural on slowed tracks, which is how
 * "slowed + reverb" edits are usually made.
 *
 * Reverb is the public-domain Freeverb design (8 parallel comb filters and
 * 4 series all-pass filters per channel). Echo is a feedback delay line
 * with a low-pass filter in the feedback path, so repeats get darker like a
 * tape echo. All gains glide to new values to avoid clicks, and the output
 * is soft-limited so stacking effects cannot clip.
 *
 * Parameters are set from Dart through {@link MuslicFx}.
 */
final class FxAudioProcessor extends BaseAudioProcessor {

  // ---- Parameters (written from the platform thread, read on the audio thread)
  private volatile float targetDry = 1f;
  private volatile float targetReverbWet = 0f; // 0..1
  private volatile float roomSize = 0.85f;     // 0..1, decay length
  private volatile float damping = 0.4f;       // 0..1, high-frequency absorption
  private volatile float width = 1f;           // 0..1, stereo spread
  private volatile float preDelayMs = 20f;     // gap before the reverb starts
  private volatile float targetDelayWet = 0f;  // 0..1
  private volatile float delayMs = 380f;       // echo spacing
  private volatile float feedback = 0.35f;     // 0..0.95, number of repeats
  private volatile float toneHz = 3500f;       // low-pass on repeats
  private volatile float smoothingMs = 120f;   // glide time for gain changes

  void setParams(float dry, float reverbWet, float roomSize, float damping, float width,
      float preDelayMs, float delayWet, float delayMs, float feedback, float toneHz,
      float smoothingMs) {
    this.roomSize = clamp(roomSize, 0f, 1f);
    this.damping = clamp(damping, 0f, 1f);
    this.width = clamp(width, 0f, 1f);
    this.preDelayMs = clamp(preDelayMs, 0f, MAX_PREDELAY_MS);
    this.delayMs = clamp(delayMs, 1f, MAX_DELAY_MS);
    this.feedback = clamp(feedback, 0f, 0.95f);
    this.toneHz = clamp(toneHz, 200f, 20000f);
    this.smoothingMs = clamp(smoothingMs, 1f, 5000f);
    this.targetDry = clamp(dry, 0f, 2f);
    this.targetReverbWet = clamp(reverbWet, 0f, 1f);
    this.targetDelayWet = clamp(delayWet, 0f, 1f);
  }

  // ---- Freeverb tuning (at 44.1 kHz; scaled to the actual rate)
  private static final int[] COMB = {1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617};
  private static final int[] ALLPASS = {556, 441, 341, 225};
  private static final int STEREO_SPREAD = 23;
  private static final float FIXED_GAIN = 0.015f;
  private static final float SCALE_WET = 3f;
  private static final float MAX_PREDELAY_MS = 250f;
  private static final float MAX_DELAY_MS = 2000f;

  private int sampleRate;
  private int channels;
  private int encoding;

  private float[][] combBuf = new float[16][];
  private int[] combIdx = new int[16];
  private float[] combStore = new float[16];
  private float[][] apBuf = new float[8][];
  private int[] apIdx = new int[8];
  private float[][] preBuf = new float[2][];
  private int preIdx;
  private float[][] delayBuf = new float[2][];
  private int delayIdx;
  private float[] toneState = new float[2];

  private float dry = 1f, reverbWet = 0f, delayWet = 0f;
  private boolean dirty; // buffers hold signal that has not decayed yet

  @Override
  protected AudioFormat onConfigure(AudioFormat in) throws UnhandledAudioFormatException {
    if ((in.encoding != C.ENCODING_PCM_16BIT && in.encoding != C.ENCODING_PCM_FLOAT)
        || in.channelCount < 1 || in.channelCount > 2) {
      throw new UnhandledAudioFormatException(in);
    }
    sampleRate = in.sampleRate;
    channels = in.channelCount;
    encoding = in.encoding;
    allocate();
    return in;
  }

  private void allocate() {
    float scale = sampleRate / 44100f;
    for (int c = 0; c < 2; c++) {
      int spread = c == 0 ? 0 : STEREO_SPREAD;
      for (int i = 0; i < 8; i++) {
        combBuf[c * 8 + i] = new float[Math.max(1, Math.round((COMB[i] + spread) * scale))];
      }
      for (int i = 0; i < 4; i++) {
        apBuf[c * 4 + i] = new float[Math.max(1, Math.round((ALLPASS[i] + spread) * scale))];
      }
      preBuf[c] = new float[(int) (MAX_PREDELAY_MS / 1000f * sampleRate) + 2];
      delayBuf[c] = new float[(int) (MAX_DELAY_MS / 1000f * sampleRate) + 2];
    }
    clear();
  }

  private void clear() {
    for (int i = 0; i < 16; i++) {
      if (combBuf[i] != null) java.util.Arrays.fill(combBuf[i], 0f);
      combIdx[i] = 0;
      combStore[i] = 0f;
    }
    for (int i = 0; i < 8; i++) {
      if (apBuf[i] != null) java.util.Arrays.fill(apBuf[i], 0f);
      apIdx[i] = 0;
    }
    for (int c = 0; c < 2; c++) {
      if (preBuf[c] != null) java.util.Arrays.fill(preBuf[c], 0f);
      if (delayBuf[c] != null) java.util.Arrays.fill(delayBuf[c], 0f);
      toneState[c] = 0f;
    }
    preIdx = 0;
    delayIdx = 0;
    dirty = false;
  }

  @Override
  public void queueInput(ByteBuffer input) {
    int remaining = input.remaining();
    if (remaining == 0) return;
    ByteBuffer out = replaceOutputBuffer(remaining);
    input.order(ByteOrder.nativeOrder());

    boolean effectsOn = targetReverbWet > 0f || targetDelayWet > 0f
        || reverbWet > 1e-4f || delayWet > 1e-4f;
    if (!effectsOn && targetDry == 1f && dry == 1f) {
      // Fully off: pass the audio through untouched.
      if (dirty) clear();
      out.put(input);
      out.flip();
      return;
    }

    final boolean isFloat = encoding == C.ENCODING_PCM_FLOAT;
    final int bytesPerSample = isFloat ? 4 : 2;
    final int frames = remaining / (bytesPerSample * channels);

    // Per-sample glide coefficient for gain changes.
    final float glide = 1f - (float) Math.exp(-1.0 / (smoothingMs / 1000f * sampleRate));
    final float fb = roomSize * 0.28f + 0.7f;           // Freeverb room scaling
    final float damp = damping * 0.4f;                  // Freeverb damping scaling
    final float w = width;
    final int preLen = preBuf[0].length;
    final int preDelay = Math.min(preLen - 1, Math.round(preDelayMs / 1000f * sampleRate));
    final int dLen = delayBuf[0].length;
    final int dSamples = Math.max(1, Math.min(dLen - 1, Math.round(delayMs / 1000f * sampleRate)));
    final float fbk = feedback;
    final float toneCoef = 1f - (float) Math.exp(-2.0 * Math.PI * toneHz / sampleRate);
    final float tDry = targetDry, tRev = targetReverbWet, tDel = targetDelayWet;

    for (int f = 0; f < frames; f++) {
      float l, r;
      if (isFloat) {
        l = input.getFloat();
        r = channels == 2 ? input.getFloat() : l;
      } else {
        l = input.getShort() / 32768f;
        r = channels == 2 ? input.getShort() / 32768f : l;
      }

      dry += (tDry - dry) * glide;
      reverbWet += (tRev - reverbWet) * glide;
      delayWet += (tDel - delayWet) * glide;

      // ---- Reverb (pre-delay, then Freeverb)
      int pr = preIdx - preDelay;
      if (pr < 0) pr += preLen;
      float inL = preBuf[0][pr], inR = preBuf[1][pr];
      preBuf[0][preIdx] = l;
      preBuf[1][preIdx] = r;
      if (++preIdx >= preLen) preIdx = 0;

      float mono = (inL + inR) * FIXED_GAIN;
      float revL = 0f, revR = 0f;
      for (int i = 0; i < 8; i++) {
        revL += comb(i, mono, fb, damp);
        revR += comb(8 + i, mono, fb, damp);
      }
      for (int i = 0; i < 4; i++) {
        revL = allpass(i, revL);
        revR = allpass(4 + i, revR);
      }
      float wet = reverbWet * SCALE_WET;
      float wet1 = wet * (w / 2f + 0.5f);
      float wet2 = wet * ((1f - w) / 2f);
      float reverbL = revL * wet1 + revR * wet2;
      float reverbR = revR * wet1 + revL * wet2;

      // ---- Echo (feedback delay with darkening low-pass)
      int dr = delayIdx - dSamples;
      if (dr < 0) dr += dLen;
      float echoL = delayBuf[0][dr], echoR = delayBuf[1][dr];
      toneState[0] += (echoL - toneState[0]) * toneCoef;
      toneState[1] += (echoR - toneState[1]) * toneCoef;
      delayBuf[0][delayIdx] = l + toneState[0] * fbk;
      delayBuf[1][delayIdx] = r + toneState[1] * fbk;
      if (++delayIdx >= dLen) delayIdx = 0;

      float outL = softClip(l * dry + reverbL + echoL * delayWet);
      float outR = softClip(r * dry + reverbR + echoR * delayWet);

      if (isFloat) {
        out.putFloat(outL);
        if (channels == 2) out.putFloat(outR);
      } else {
        out.putShort((short) Math.round(outL * 32767f));
        if (channels == 2) out.putShort((short) Math.round(outR * 32767f));
      }
    }
    dirty = true;
    out.flip();
  }

  private float comb(int i, float in, float fb, float damp) {
    float[] buf = combBuf[i];
    int idx = combIdx[i];
    float y = buf[idx];
    combStore[i] = y * (1f - damp) + combStore[i] * damp;
    buf[idx] = in + combStore[i] * fb;
    combIdx[i] = idx + 1 >= buf.length ? 0 : idx + 1;
    return y;
  }

  private float allpass(int i, float in) {
    float[] buf = apBuf[i];
    int idx = apIdx[i];
    float b = buf[idx];
    buf[idx] = in + b * 0.5f;
    apIdx[i] = idx + 1 >= buf.length ? 0 : idx + 1;
    return b - in;
  }

  /** Transparent below 0.9, then rounds off smoothly towards ±1. */
  private static float softClip(float v) {
    float a = Math.abs(v);
    if (a <= 0.9f) return v;
    float s = 0.9f + 0.1f * (float) Math.tanh((a - 0.9f) / 0.1f);
    return v < 0 ? -s : s;
  }

  private static float clamp(float v, float lo, float hi) {
    return v < lo ? lo : (v > hi ? hi : v);
  }

  @Override
  protected void onFlush() {
    // Seeking: drop tails so old audio does not echo into the new position.
    clear();
    dry = targetDry;
    reverbWet = targetReverbWet;
    delayWet = targetDelayWet;
  }

  @Override
  protected void onReset() {
    clear();
  }
}
