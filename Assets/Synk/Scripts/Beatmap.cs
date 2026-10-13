using System;
using System.Collections.Generic;
using UnityEngine;

namespace Synk
{
    [CreateAssetMenu(menuName = "SYNK/Beatmap")]
    public sealed class Beatmap : ScriptableObject
    {
        public string songTitle = "Eclipse";
        public string artist = "SYNK Originals";
        public string difficulty = "EXPERT";
        public int level = 12;
        public float bpm = 128;
        public AudioClip music;
        public float audioOffset;
        public List<ChartNote> notes = new List<ChartNote>();

        public static Beatmap Demo()
        {
            var map = CreateInstance<Beatmap>();
            var random = new System.Random(42);
            double beat = 60.0 / map.bpm;
            // One active note at a time makes all gestures learnable on a phone.
            for (int i = 0; i < 96; i++)
            {
                int lane = random.Next(1, 12);
                var kind = i < 8 ? NoteKind.Tap : (NoteKind)(i % 4);
                map.notes.Add(new ChartNote {
                    time = 3 + i * beat * 2, lane = lane, kind = kind,
                    duration = kind == NoteKind.Hold || kind == NoteKind.Slide ? (float)beat : 0,
                    endLane = Mathf.Clamp(lane + (i % 2 == 0 ? 3 : -3), 0, 12),
                    direction = (FlickDirection)((i / 4) % 4)
                });
            }
            return map;
        }
    }
}
