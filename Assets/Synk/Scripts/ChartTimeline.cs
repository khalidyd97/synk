using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Synk
{
    public sealed class ChartTimeline : MaskableGraphic, IPointerDownHandler, IBeginDragHandler, IDragHandler
    {
        public SynkGame game;
        public float seconds = 8;
        VertexHelper mesh;
        bool draggingNote;
        double grabbedStart, grabOffset;
        readonly Text[] stamps = new Text[5];
        protected override void Start()
        {
            base.Start();
            for (int i = 0; i < stamps.Length; i++)
            {
                var obj = new GameObject("Timestamp", typeof(RectTransform), typeof(Text)); obj.transform.SetParent(transform, false);
                var rt = obj.GetComponent<RectTransform>(); rt.anchorMin = new Vector2(i * .2f, .92f); rt.anchorMax = new Vector2((i + 1) * .2f, 1); rt.offsetMin = rt.offsetMax = Vector2.zero;
                var label = obj.GetComponent<Text>(); label.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); label.fontSize = 15; label.color = new Color(.7f, .8f, 1); label.raycastTarget = false; stamps[i] = label;
            }
        }
        void Update()
        {
            SetVerticesDirty(); if (game == null) return;
            for (int i = 0; i < stamps.Length; i++) if (stamps[i] != null) stamps[i].text = (game.EditorWindowStart + i * seconds / 5).ToString("F2") + " s";
        }
        Vector2 Position(PointerEventData data)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(rectTransform, data.position, data.pressEventCamera, out var p);
            return new Vector2(p.x / rectTransform.rect.width + .5f, p.y / rectTransform.rect.height + .5f);
        }
        static int Lane(float y) => Mathf.Clamp(Mathf.FloorToInt((1 - y / .78f) * 13), 0, 12);
        public void OnPointerDown(PointerEventData data)
        {
            var p = Position(data); grabbedStart = game.EditorWindowStart;
            double time = grabbedStart + p.x * seconds;
            int nearest = -1; double best = seconds * .02;
            if (p.y < .78f)
                for (int i = 0; i < game.EditorDocument.notes.Count; i++)
                {
                    var n = game.EditorDocument.notes[i]; double distance = Math.Abs(time - n.time);
                    if (n.lane == Lane(p.y) && distance < best) { best = distance; nearest = i; }
                }
            draggingNote = nearest >= 0;
            game.SelectEditorNote(nearest);
            if (draggingNote) grabOffset = time - game.EditorDocument.Selection.time;
            else game.SeekEditor(time);
        }
        public void OnBeginDrag(PointerEventData data) { if (draggingNote) game.BeginNoteDrag(); }
        public void OnDrag(PointerEventData data)
        {
            var p = Position(data); double time = grabbedStart + p.x * seconds;
            if (draggingNote) game.DragEditorNote(time - grabOffset, Lane(p.y)); else game.SeekEditor(time);
        }
        void Box(float x0, float y0, float x1, float y1, Color c)
        {
            x0 = Mathf.Clamp01(x0); x1 = Mathf.Clamp01(x1); y0 = Mathf.Clamp01(y0); y1 = Mathf.Clamp01(y1);
            if (x1 <= x0 || y1 <= y0) return;
            int i = mesh.currentVertCount; var r = rectTransform.rect;
            mesh.AddVert(new Vector3((x0 - .5f) * r.width, (y0 - .5f) * r.height), c, Vector2.zero);
            mesh.AddVert(new Vector3((x0 - .5f) * r.width, (y1 - .5f) * r.height), c, Vector2.zero);
            mesh.AddVert(new Vector3((x1 - .5f) * r.width, (y1 - .5f) * r.height), c, Vector2.zero);
            mesh.AddVert(new Vector3((x1 - .5f) * r.width, (y0 - .5f) * r.height), c, Vector2.zero);
            mesh.AddTriangle(i, i + 1, i + 2); mesh.AddTriangle(i, i + 2, i + 3);
        }
        protected override void OnPopulateMesh(VertexHelper vh)
        {
            vh.Clear(); mesh = vh; Box(0, 0, 1, 1, new Color(.018f, .02f, .06f)); if (game == null) return;
            double start = game.EditorWindowStart;
            if (game.EditorLoopEnabled)
            {
                float a = (float)((game.EditorLoopA - start) / seconds), b = (float)((game.EditorLoopB - start) / seconds);
                Box(a, 0, b, .78f, new Color(.12f, .25f, .16f, .3f));
                Box(a, 0, a + .002f, .92f, Color.green); Box(b, 0, b + .002f, .92f, Color.green);
            }
            for (int lane = 0; lane <= 13; lane++) Box(0, lane * .78f / 13, 1, lane * .78f / 13 + .002f, new Color(.15f, .1f, .25f));
            double step = 60 / Math.Max(30, game.beatmap.bpm);
            for (double t = Math.Ceiling(start / step) * step; t <= start + seconds; t += step)
            { float x = (float)((t - start) / seconds); Box(x, 0, x + .001f, .92f, new Color(.18f, .15f, .3f)); }
            var peaks = game.EditorWaveform;
            for (int i = 0; i < 256; i++)
            {
                double t = start + i * seconds / 256;
                if (t > game.EditorEnd || peaks.Length == 0) continue;
                float peak = peaks[Mathf.Clamp((int)(t / game.EditorEnd * peaks.Length), 0, peaks.Length - 1)];
                Box(i / 256f, .855f - peak * .055f, (i + .65f) / 256f, .855f + peak * .055f, new Color(.12f, .65f, .8f));
            }
            int shown = 0;
            for (int i = 0; i < game.EditorDocument.notes.Count; i++)
            {
                var n = game.EditorDocument.notes[i]; if (n.time + n.duration < start || n.time > start + seconds) continue;
                if (++shown > 1000) break;
                Color c = n.kind == NoteKind.Flick ? new Color(1, .25f, .8f) : new Color(.1f, .7f, 1);
                float x = (float)((n.time - start) / seconds), y = (12 - n.lane + .5f) * .78f / 13;
                if (n.duration > 0)
                    for (int segment = 0; segment < 12; segment++)
                    {
                        double t = n.time + segment * n.duration / 12;
                        float sx = (float)((t - start) / seconds), ex = (float)((t + n.duration / 12 - start) / seconds);
                        float sy = (12 - n.LaneAt(t) + .5f) * .78f / 13;
                        Box(sx, sy - .009f, ex, sy + .009f, new Color(c.r, c.g, c.b, .45f));
                    }
                if (i == game.EditorDocument.selected) Box(x - .009f, y - .026f, x + .009f, y + .026f, Color.white);
                Box(x - .006f, y - .021f, x + .006f, y + .021f, c);
                if (n.kind == NoteKind.Flick) Box(x - .012f, y - .003f, x + .012f, y + .003f, Color.white);
            }
            float cursor = (float)((game.EditorCursor - start) / seconds); Box(cursor, 0, cursor + .002f, .92f, new Color(1, .9f, .4f));
        }
    }
}
