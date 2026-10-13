using UnityEngine;

namespace Synk
{
    public static class DemoAudio
    {
        // Original procedural synth loop: no external music or licensed assets required.
        public static AudioClip Create(float bpm, float seconds)
        {
            const int rate = 22050;
            var samples = new float[Mathf.CeilToInt(seconds * rate)];
            double beat = 60.0 / bpm;
            int[] melody = { 64, 67, 71, 74, 71, 67, 62, 66, 69, 73, 69, 66, 60, 64, 67, 71 };
            uint noise = 123456;
            for (int i = 0; i < samples.Length; i++)
            {
                double t = (double)i / rate;
                double local = t % beat;
                int step = (int)(t / (beat / 2));
                float f = 440f * Mathf.Pow(2, (melody[step % melody.Length] - 69) / 12f);
                double env = System.Math.Exp(-local * 12);
                double kick = System.Math.Sin(2 * System.Math.PI * (48 * local + 6 * (1 - System.Math.Exp(-local * 35)))) * System.Math.Exp(-local * 18);
                double arpeggio = System.Math.Sin(2 * System.Math.PI * f * t) * System.Math.Exp(-(t % (beat / 2)) * 13);
                noise = noise * 1664525 + 1013904223;
                double hat = ((noise >> 16) / 32768.0 - 1) * System.Math.Exp(-(t % (beat / 2)) * 90);
                float fade = Mathf.Clamp01((float)t) * Mathf.Clamp01((float)(seconds - t));
                samples[i] = (float)(kick * .32 + arpeggio * .16 + hat * .07 + System.Math.Sin(2 * System.Math.PI * f / 4 * t) * env * .08) * fade;
            }
            var clip = AudioClip.Create("Eclipse • original synth demo", samples.Length, 1, rate, false);
            clip.SetData(samples, 0);
            return clip;
        }
    }
}
