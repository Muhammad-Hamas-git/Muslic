package androidx.media3.common.audio;
import java.nio.ByteBuffer; import java.nio.ByteOrder;
// Minimal stand-in with the same contract as media3 1.4.1 for testing.
public abstract class BaseAudioProcessor implements AudioProcessor {
  protected AudioFormat inputAudioFormat = AudioFormat.NOT_SET, outputAudioFormat = AudioFormat.NOT_SET;
  private ByteBuffer buffer = EMPTY_BUFFER, outputBuffer = EMPTY_BUFFER;
  public final AudioFormat configure(AudioFormat in) throws UnhandledAudioFormatException { inputAudioFormat=in; outputAudioFormat=onConfigure(in); return outputAudioFormat; }
  public abstract void queueInput(ByteBuffer b);
  public ByteBuffer getOutput(){ ByteBuffer o=outputBuffer; outputBuffer=EMPTY_BUFFER; return o; }
  public final void flush(){ outputBuffer=EMPTY_BUFFER; onFlush(); }
  public final void reset(){ flush(); onReset(); }
  protected final ByteBuffer replaceOutputBuffer(int size){ if(buffer.capacity()<size) buffer=ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder()); else buffer.clear(); outputBuffer=buffer; return buffer; }
  protected AudioFormat onConfigure(AudioFormat in) throws UnhandledAudioFormatException { return AudioFormat.NOT_SET; }
  protected void onFlush(){} protected void onReset(){}
}
