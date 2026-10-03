# Generates the game's music and sound effects (WAV, 22.05 kHz mono) into assets/audio.
#   powershell -ExecutionPolicy Bypass -File .\tools\gen_audio.ps1
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot '..\assets\audio'
New-Item -ItemType Directory -Force $out | Out-Null

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;

public static class Synth {
    const int SR = 22050;
    static Random rnd = new Random(7);

    static double F(string n) {
        string[] names = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"};
        string pitch = n.Substring(0, n.Length - 1);
        int oct = int.Parse(n.Substring(n.Length - 1));
        int semi = Array.IndexOf(names, pitch);
        int midi = (oct + 1) * 12 + semi;
        return 440.0 * Math.Pow(2, (midi - 69) / 12.0);
    }

    static float[] Buf(double sec) { return new float[(int)(sec * SR)]; }

    // wave: sine | square | tri | saw | noise.  decay > 0 adds exponential decay.
    static void Tone(float[] b, double start, double dur, double f, double vol, string wave,
                     double f2 = -1, double duty = 0.5, double decay = 0, double attack = 0.005, double release = 0.04) {
        int s0 = (int)(start * SR), n = (int)(dur * SR);
        double phase = 0;
        for (int i = 0; i < n && s0 + i < b.Length; i++) {
            double t = (double)i / SR;
            double ff = f2 > 0 ? f + (f2 - f) * i / n : f;
            phase += ff / SR;
            double p = phase - Math.Floor(phase);
            double v;
            switch (wave) {
                case "sine": v = Math.Sin(2 * Math.PI * p); break;
                case "square": v = p < duty ? 1 : -1; break;
                case "tri": v = 4 * Math.Abs(p - 0.5) - 1; break;
                case "saw": v = 2 * p - 1; break;
                default: v = rnd.NextDouble() * 2 - 1; break;
            }
            double env = Math.Min(1, t / attack) * Math.Min(1, (dur - t) / release);
            if (decay > 0) env *= Math.Exp(-t * decay);
            if (env < 0) env = 0;
            b[s0 + i] += (float)(v * vol * env);
        }
    }

    static void Save(float[] b, string path, double peak) {
        float max = 0.0001f;
        foreach (float x in b) max = Math.Max(max, Math.Abs(x));
        double g = peak / max;
        using (var w = new BinaryWriter(File.Create(path))) {
            int bytes = b.Length * 2;
            w.Write(new char[] {'R','I','F','F'}); w.Write(36 + bytes);
            w.Write(new char[] {'W','A','V','E','f','m','t',' '}); w.Write(16);
            w.Write((short)1); w.Write((short)1); w.Write(SR); w.Write(SR * 2);
            w.Write((short)2); w.Write((short)16);
            w.Write(new char[] {'d','a','t','a'}); w.Write(bytes);
            foreach (float x in b) w.Write((short)Math.Max(-32767, Math.Min(32767, x * g * 32767)));
        }
    }

    // ---------------- Background music: 8 bars, 120 BPM, seamless loop ----------------
    static void Music(string dir) {
        double beat = 0.5;
        float[] b = Buf(32 * beat);
        string[][] melody = {
            new[]{"C5",".5","E5",".5","G5",".5","E5",".5","C6","1","G5","1"},
            new[]{"B4",".5","D5",".5","G5",".5","D5",".5","B5","1","G5","1"},
            new[]{"A4",".5","C5",".5","E5",".5","C5",".5","A5","1","E5","1"},
            new[]{"F5",".5","A5",".5","C6",".5","A5",".5","G5","1.5","-",".5"},
            new[]{"E5","1","G5",".5","A5",".5","G5","1","E5","1"},
            new[]{"D5","1","G5",".5","A5",".5","B5","1","G5","1"},
            new[]{"C6",".5","B5",".5","A5",".5","G5",".5","E5","1","A5","1"},
            new[]{"F5",".5","E5",".5","D5",".5","F5",".5","E5","1","D5","1"},
        };
        string[] bass = {"C3","G2","A2","F2","C3","G2","A2","F2"};
        for (int bar = 0; bar < 8; bar++) {
            double t0 = bar * 4 * beat, t = t0;
            string[] m = melody[bar];
            for (int i = 0; i < m.Length; i += 2) {
                double len = double.Parse(m[i + 1], System.Globalization.CultureInfo.InvariantCulture) * beat;
                if (m[i] != "-") {
                    Tone(b, t, len * 0.92, F(m[i]), 0.16, "square", duty: 0.25, release: 0.05);
                    Tone(b, t, len * 0.92, F(m[i]), 0.10, "sine", release: 0.05);
                }
                t += len;
            }
            double root = F(bass[bar]);
            for (int k = 0; k < 8; k++) {
                double f = (k % 2 == 0) ? root : root * 2;
                Tone(b, t0 + k * beat / 2, beat / 2 * 0.9, f, 0.28, "tri", release: 0.03);
            }
            for (int k = 0; k < 4; k++) {
                double bt = t0 + k * beat;
                if (k % 2 == 0) Tone(b, bt, 0.14, 140, 0.45, "sine", f2: 45, decay: 18);
                else Tone(b, bt, 0.10, 0, 0.12, "noise", decay: 30);
                Tone(b, bt + beat / 2, 0.03, 0, 0.05, "noise", decay: 60);
            }
        }
        Save(b, Path.Combine(dir, "music.wav"), 0.55);
    }

    public static void GenerateAll(string dir) {
        Music(dir);

        // Correct: bright two-note "ding".
        float[] c = Buf(0.45);
        Tone(c, 0.00, 0.18, F("E6"), 0.5, "sine", decay: 14);
        Tone(c, 0.00, 0.18, F("E6"), 0.12, "square", decay: 18);
        Tone(c, 0.09, 0.36, F("A6"), 0.6, "sine", decay: 9);
        Tone(c, 0.09, 0.36, F("A6"), 0.12, "square", decay: 14);
        Save(c, Path.Combine(dir, "correct.wav"), 0.9);

        // Wrong: descending buzzy "bwomp".
        float[] w = Buf(0.6);
        Tone(w, 0.0, 0.55, 330, 0.4, "saw", f2: 150, release: 0.12);
        Tone(w, 0.0, 0.55, 311, 0.25, "square", f2: 140, release: 0.12);
        Save(w, Path.Combine(dir, "wrong.wav"), 0.85);

        // Level up: "boing" jump followed by a rising arpeggio.
        float[] l = Buf(1.0);
        Tone(l, 0.0, 0.22, 220, 0.5, "sine", f2: 880, release: 0.05);
        string[] arp = {"C5","E5","G5","C6"};
        for (int i = 0; i < 4; i++) {
            double st = 0.22 + i * 0.09, d = i == 3 ? 0.5 : 0.16;
            Tone(l, st, d, F(arp[i]), 0.25, "square", duty: 0.25, decay: i == 3 ? 4 : 10);
            Tone(l, st, d, F(arp[i]), 0.25, "sine", decay: i == 3 ? 4 : 10);
        }
        Save(l, Path.Combine(dir, "levelup.wav"), 0.9);

        // New record: fanfare + sparkles.
        float[] r = Buf(2.0);
        object[][] fan = {
            new object[]{"G4",0.00,0.12}, new object[]{"C5",0.13,0.12}, new object[]{"E5",0.26,0.12},
            new object[]{"G5",0.39,0.24}, new object[]{"E5",0.66,0.12}, new object[]{"G5",0.79,0.75},
        };
        foreach (var n in fan) {
            double st = (double)n[1], d = (double)n[2];
            Tone(r, st, d, F((string)n[0]), 0.28, "square", duty: 0.25, release: 0.06);
            Tone(r, st, d, F((string)n[0]), 0.22, "tri", release: 0.06);
            Tone(r, st, d, F((string)n[0]) / 2, 0.18, "tri", release: 0.06);
        }
        string[] sparkle = {"C7","E7","G7","E7","C7","G7","E7","C7"};
        for (int i = 0; i < sparkle.Length; i++)
            Tone(r, 0.85 + i * 0.12, 0.3, F(sparkle[i]), 0.15, "sine", decay: 10);
        Save(r, Path.Combine(dir, "record.wav"), 0.9);
    }
}
'@

[Synth]::GenerateAll((Resolve-Path $out).Path)
Get-ChildItem $out | Select-Object Name, Length
