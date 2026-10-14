package androidx.media3.common.audio;
import java.nio.ByteBuffer;
public interface AudioProcessor {
  final class AudioFormat {
    public static final AudioFormat NOT_SET = new AudioFormat(-1,-1,-1);
    public final int sampleRate, channelCount, encoding;
    public AudioFormat(int sr,int ch,int enc){sampleRate=sr;channelCount=ch;encoding=enc;}
  }
  final class UnhandledAudioFormatException extends Exception { public UnhandledAudioFormatException(AudioFormat f){super("unhandled");} }
  ByteBuffer EMPTY_BUFFER = ByteBuffer.allocateDirect(0);
}
