package com.ryanheise.just_audio;

import androidx.media3.common.PlaybackParameters;
import androidx.media3.common.audio.AudioProcessor;
import androidx.media3.common.audio.AudioProcessorChain;
import androidx.media3.common.audio.SonicAudioProcessor;
import androidx.media3.exoplayer.audio.SilenceSkippingAudioProcessor;

/**
 * müslic addition: the same processors as media3's DefaultAudioProcessorChain
 * (silence skipping, then Sonic for speed/pitch), followed by
 * {@link FxAudioProcessor}. Media3's default chain can only put custom
 * processors before Sonic, which would slow down the reverb tail and echo
 * spacing together with the music.
 */
final class FxProcessorChain implements AudioProcessorChain {
  private final SilenceSkippingAudioProcessor silence = new SilenceSkippingAudioProcessor();
  private final SonicAudioProcessor sonic = new SonicAudioProcessor();
  private final AudioProcessor[] processors;

  FxProcessorChain(FxAudioProcessor fx) {
    processors = new AudioProcessor[] {silence, sonic, fx};
  }

  @Override
  public AudioProcessor[] getAudioProcessors() {
    return processors;
  }

  @Override
  public PlaybackParameters applyPlaybackParameters(PlaybackParameters playbackParameters) {
    sonic.setSpeed(playbackParameters.speed);
    sonic.setPitch(playbackParameters.pitch);
    return playbackParameters;
  }

  @Override
  public boolean applySkipSilenceEnabled(boolean skipSilenceEnabled) {
    silence.setEnabled(skipSilenceEnabled);
    return skipSilenceEnabled;
  }

  @Override
  public long getMediaDuration(long playoutDuration) {
    return sonic.isActive() ? sonic.getMediaDuration(playoutDuration) : playoutDuration;
  }

  @Override
  public long getSkippedOutputFrameCount() {
    return silence.getSkippedFrames();
  }
}
