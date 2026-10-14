// Test harness for FxAudioProcessor (used by preview.py).
package com.ryanheise.just_audio;
import androidx.media3.common.C; import androidx.media3.common.audio.AudioProcessor.AudioFormat;
import java.io.*; import java.nio.*;
// Feeds raw 16-bit stereo PCM through FxAudioProcessor in 4096-frame chunks.
// args: in.raw out.raw rate dry rev room damp width pre delWet delMs fb tone
public class Harness {
  public static void main(String[] a) throws Exception {
    byte[] in = java.nio.file.Files.readAllBytes(new File(a[0]).toPath());
    int sr = Integer.parseInt(a[2]);
    FxAudioProcessor p = new FxAudioProcessor();
    p.configure(new AudioFormat(sr, 2, C.ENCODING_PCM_16BIT));
    float[] v = new float[10]; for (int i=0;i<10;i++) v[i]=Float.parseFloat(a[3+i]);
    p.setParams(v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],v[9],1f);
    OutputStream out = new BufferedOutputStream(new FileOutputStream(a[1]));
    int chunk = 4096*4; long t0=System.nanoTime();
    for (int off=0; off<in.length; off+=chunk) {
      int n = Math.min(chunk, in.length-off);
      ByteBuffer b = ByteBuffer.allocateDirect(n).order(ByteOrder.nativeOrder()); b.put(in, off, n); b.flip();
      p.queueInput(b); ByteBuffer o = p.getOutput(); byte[] tmp = new byte[o.remaining()]; o.get(tmp); out.write(tmp);
    }
    out.close();
    double secs=(System.nanoTime()-t0)/1e9, audio=in.length/4.0/sr;
    System.err.printf("processed %.1fs of audio in %.3fs (%.0fx realtime)%n", audio, secs, audio/secs);
  }
}
