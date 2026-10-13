using System;
using System.Collections.Generic;

namespace Synk
{
    public enum NoteKind { Tap, Hold, Slide, Flick }
    public enum FlickDirection { Up, Right, Down, Left }
    public enum CaptureTool { Auto, Tap, Hold, Slide, Flick }

    [Serializable]
    public sealed class SlidePoint
    {
        public float offset;
        public float lane;
    }

    [Serializable]
    public sealed class ChartNote
    {
        public double time;
        public int lane;
        public NoteKind kind;
        public float duration;
        public int endLane;
        public FlickDirection direction;
        public List<SlidePoint> path = new List<SlidePoint>();

        public float LaneAt(double songTime)
        {
            if (kind != NoteKind.Slide) return lane;
            float elapsed = (float)Math.Max(0, Math.Min(duration, songTime - time));
            if (path != null && path.Count > 1)
            {
                for (int i = 1; i < path.Count; i++)
                {
                    if (elapsed > path[i].offset) continue;
                    var a = path[i - 1]; var b = path[i];
                    float t = (elapsed - a.offset) / Math.Max(.0001f, b.offset - a.offset);
                    return a.lane + (b.lane - a.lane) * t;
                }
                return path[path.Count - 1].lane;
            }
            float progress = elapsed / Math.Max(.01f, duration);
            return lane + (endLane - lane) * progress * progress * (3 - 2 * progress);
        }
    }

    // Pure C#: gesture timestamps use the same chart clock as playback.
    public sealed class ChartCapture
    {
        public const double HoldThreshold = .22;
        public const float FlickDistance = .035f;
        sealed class Gesture
        {
            public ChartNote note;
            public CaptureTool tool;
            public float x, y, lastX, lastY, maxDelta;
        }
        readonly Dictionary<int, Gesture> gestures = new Dictionary<int, Gesture>();
        public readonly List<ChartNote> notes = new List<ChartNote>();
        public IEnumerable<ChartNote> ActiveNotes
        {
            get { foreach (var gesture in gestures.Values) yield return gesture.note; }
        }
        static float Lane(float x) { return Math.Max(0, Math.Min(12, (x - .07f) / .86f * 13 - .5f)); }
        static int RoundLane(float x) { return (int)Math.Round(Lane(x), MidpointRounding.AwayFromZero); }

        public bool Begin(int id, double time, float x, float y, CaptureTool tool)
        {
            if (time < 0 || x < .07f || x > .93f || y < .08f || y > .4f || gestures.ContainsKey(id)) return false;
            var note = new ChartNote { time = time, lane = RoundLane(x), endLane = RoundLane(x) };
            note.path.Add(new SlidePoint { offset = 0, lane = note.lane });
            gestures[id] = new Gesture { note = note, tool = tool, x = x, y = y, lastX = x, lastY = y };
            return true;
        }
        public void Move(int id, double time, float x, float y)
        {
            Gesture g;
            if (!gestures.TryGetValue(id, out g)) return;
            g.lastX = x; g.lastY = y;
            g.maxDelta = Math.Max(g.maxDelta, Math.Abs(Lane(x) - g.note.lane));
            float elapsed = (float)Math.Max(0, time - g.note.time);
            var path = g.note.path;
            if (elapsed > path[path.Count - 1].offset + .016f)
                path.Add(new SlidePoint { offset = elapsed, lane = Lane(x) });
            g.note.duration = elapsed;
            g.note.endLane = RoundLane(x);
            g.note.kind = g.maxDelta >= .8f ? NoteKind.Slide : NoteKind.Hold;
        }
        public ChartNote End(int id, double time, float x, float y, bool canceled)
        {
            Gesture g;
            if (!gestures.TryGetValue(id, out g)) return null;
            Move(id, time, x, y); gestures.Remove(id);
            if (canceled) return null;
            var n = g.note;
            float dx = x - g.x, dy = y - g.y;
            bool quickFlick = n.duration <= HoldThreshold && Math.Max(Math.Abs(dx), Math.Abs(dy)) >= FlickDistance;
            n.kind = g.tool == CaptureTool.Auto
                ? (quickFlick ? NoteKind.Flick : n.duration < HoldThreshold ? NoteKind.Tap : g.maxDelta >= .8f ? NoteKind.Slide : NoteKind.Hold)
                : (NoteKind)((int)g.tool - 1);
            if (n.kind == NoteKind.Flick)
            {
                if (Math.Max(Math.Abs(dx), Math.Abs(dy)) < FlickDistance) return null;
                n.direction = Math.Abs(dx) > Math.Abs(dy) ? (dx > 0 ? FlickDirection.Right : FlickDirection.Left)
                    : (dy > 0 ? FlickDirection.Up : FlickDirection.Down);
            }
            if (n.kind == NoteKind.Tap || n.kind == NoteKind.Flick) { n.duration = 0; n.path.Clear(); }
            else
            {
                if (n.duration < .04f) return null;
                if (n.kind == NoteKind.Hold) { n.endLane = n.lane; n.path.Clear(); }
                else
                {
                    if (n.path[n.path.Count - 1].offset == n.duration) n.path.RemoveAt(n.path.Count - 1);
                    n.path.Add(new SlidePoint { offset = n.duration, lane = n.endLane });
                }
            }
            notes.Add(n);
            return n;
        }
        public void CancelActive() { gestures.Clear(); }
        public void Clear() { gestures.Clear(); notes.Clear(); }
        public void Undo() { if (notes.Count > 0) notes.RemoveAt(notes.Count - 1); }
        public List<ChartNote> SortedNotes()
        {
            var result = new List<ChartNote>(notes);
            result.Sort((a, b) => a.time.CompareTo(b.time));
            return result;
        }
    }
}
