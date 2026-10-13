using System;
using System.Collections.Generic;

namespace Synk
{
    // Editing history owns deep snapshots, so preview and saved charts cannot be mutated accidentally.
    public sealed class ChartDocument
    {
        public readonly List<ChartNote> notes = new List<ChartNote>();
        readonly Stack<List<ChartNote>> undo = new Stack<List<ChartNote>>();
        readonly Stack<List<ChartNote>> redo = new Stack<List<ChartNote>>();
        public bool dirty { get; private set; }
        public int selected = -1;
        public static List<ChartNote> Copy(IEnumerable<ChartNote> source)
        {
            var result = new List<ChartNote>();
            foreach (var n in source)
            {
                var copy = new ChartNote { time = n.time, lane = n.lane, kind = n.kind, duration = n.duration, endLane = n.endLane, direction = n.direction };
                if (n.path != null) foreach (var p in n.path) copy.path.Add(new SlidePoint { offset = p.offset, lane = p.lane });
                result.Add(copy);
            }
            return result;
        }
        public ChartNote Selection { get { return selected >= 0 && selected < notes.Count ? notes[selected] : null; } }
        public void Load(IEnumerable<ChartNote> source)
        { notes.Clear(); notes.AddRange(Copy(source)); undo.Clear(); redo.Clear(); selected = -1; dirty = false; }
        public void Checkpoint() { undo.Push(Copy(notes)); redo.Clear(); dirty = true; }
        public void Saved() { dirty = false; }
        public void MarkDirty() { dirty = true; }
        void Restore(List<ChartNote> source) { notes.Clear(); notes.AddRange(source); selected = -1; dirty = true; }
        public void Undo() { if (undo.Count == 0) return; redo.Push(Copy(notes)); Restore(undo.Pop()); }
        public void Redo() { if (redo.Count == 0) return; undo.Push(Copy(notes)); Restore(redo.Pop()); }
        public void Add(double time, int lane)
        { Checkpoint(); notes.Add(new ChartNote { time = Math.Max(0, time), lane = Math.Max(0, Math.Min(12, lane)), endLane = Math.Max(0, Math.Min(12, lane)) }); selected = notes.Count - 1; }
        public void Delete() { if (Selection == null) return; Checkpoint(); notes.RemoveAt(selected); selected = -1; }
        public void Convert(NoteKind kind, float defaultDuration)
        {
            var n = Selection; if (n == null) return; Checkpoint(); n.kind = kind;
            if (kind == NoteKind.Tap || kind == NoteKind.Flick) { n.duration = 0; n.path.Clear(); n.endLane = n.lane; }
            else { n.duration = Math.Max(.04f, n.duration > 0 ? n.duration : defaultDuration); if (kind == NoteKind.Hold) { n.path.Clear(); n.endLane = n.lane; } }
        }
        public void Move(double time, int lane, double songEnd)
        {
            var n = Selection; if (n == null) return;
            n.time = Math.Max(0, Math.Min(Math.Max(0, songEnd - n.duration), time));
            int delta = Math.Max(0, Math.Min(12, lane)) - n.lane;
            n.lane += delta; n.endLane = Math.Max(0, Math.Min(12, n.endLane + delta));
            if (n.path != null) foreach (var point in n.path) point.lane = Math.Max(0, Math.Min(12, point.lane + delta));
            dirty = true;
        }
        public void Resize(float duration, double songEnd)
        {
            var n = Selection; if (n == null || n.kind == NoteKind.Tap || n.kind == NoteKind.Flick) return;
            Checkpoint(); float previous = Math.Max(.04f, n.duration);
            n.duration = (float)Math.Max(.04, Math.Min(Math.Max(.04, songEnd - n.time), duration));
            if (n.path != null) foreach (var p in n.path) p.offset *= n.duration / previous;
        }
        public void SetEndLane(int lane)
        {
            var n = Selection; if (n == null || n.kind != NoteKind.Slide) return;
            Checkpoint(); n.endLane = Math.Max(0, Math.Min(12, lane)); n.path.Clear();
        }
        public double Snap(double time, double bpm, int division)
        {
            if (division <= 0) return Math.Max(0, time);
            double step = 60.0 / Math.Max(1, bpm) / division;
            return Math.Max(0, Math.Round(time / step, MidpointRounding.AwayFromZero) * step);
        }
    }
}
