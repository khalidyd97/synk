using UnityEngine;
using UnityEngine.UI;

namespace Synk
{
    // One batched UI mesh draws the highway, ribbons, notes, and glow layers.
    public sealed class NeonHighway : MaskableGraphic
    {
        public SynkGame game;
        VertexHelper mesh;
        readonly Color purple = new Color(.65f, .12f, 1);
        readonly Color pink = new Color(1, .12f, .94f);
        readonly Color blue = new Color(.05f, .65f, 1);
        void Update() => SetVerticesDirty();

        Vector2 Project(float lane, float depth)
        {
            float width = Mathf.Lerp(.86f, .15f, depth);
            return new Vector2(.5f + ((lane + .5f) / 13f - .5f) * width,
                Mathf.Lerp(.235f, .88f, depth));
        }
        float Depth(double time) => Mathf.Clamp((float)((time - game.SongTime) / SynkGame.Approach), -.12f, 1);
        Vector2 Pixel(Vector2 p) => new Vector2((p.x - .5f) * rectTransform.rect.width, (p.y - .5f) * rectTransform.rect.height);
        void Quad(Vector2 a, Vector2 b, Vector2 c, Vector2 d, Color color)
        {
            int index = mesh.currentVertCount;
            mesh.AddVert(Pixel(a), color, Vector2.zero); mesh.AddVert(Pixel(b), color, Vector2.zero);
            mesh.AddVert(Pixel(c), color, Vector2.zero); mesh.AddVert(Pixel(d), color, Vector2.zero);
            mesh.AddTriangle(index, index + 1, index + 2); mesh.AddTriangle(index + 2, index + 3, index);
        }
        void Line(Vector2 a, Vector2 b, float thickness, Color color)
        {
            Vector2 pa = Pixel(a), pb = Pixel(b);
            Vector2 normal = new Vector2(-(pb - pa).y, (pb - pa).x).normalized * thickness / 2;
            normal = new Vector2(normal.x / rectTransform.rect.width, normal.y / rectTransform.rect.height);
            Quad(a - normal, a + normal, b + normal, b - normal, color);
        }
        static Color Alpha(Color c, float alpha) { c.a = alpha; return c; }
        void GlowLine(Vector2 a, Vector2 b, float thickness, Color color)
        {
            Line(a, b, thickness * 8, Alpha(color, .025f));
            Line(a, b, thickness * 4, Alpha(color, .07f));
            Line(a, b, thickness * 2, Alpha(color, .18f));
            Line(a, b, thickness, color);
            Line(a, b, Mathf.Max(1, thickness * .22f), new Color(.95f, .88f, 1, .9f));
        }
        protected override void OnPopulateMesh(VertexHelper vh)
        {
            vh.Clear(); mesh = vh;
            Quad(Vector2.zero, Vector2.up, Vector2.one, Vector2.right, new Color(.006f, .007f, .025f));
            if (game == null) return;
            for (int i = 0; i < 5; i++)
            {
                float spread = .17f + i * .07f;
                Color c = Alpha(blue, .07f - i * .01f);
                GlowLine(new Vector2(.5f - spread, .7f - i * .08f), new Vector2(.46f, 1.05f), 2, c);
                GlowLine(new Vector2(.5f + spread, .7f - i * .08f), new Vector2(.54f, 1.05f), 2, c);
            }
            Quad(Project(-.5f, -.1f), Project(-.5f, 1), Project(12.5f, 1), Project(12.5f, -.1f), new Color(.012f, .008f, .038f));
            for (int i = 0; i <= 13; i++)
            {
                Color c = i % 2 == 0 ? purple : blue;
                GlowLine(Project(i - .5f, -.12f), Project(i - .5f, 1), i == 0 || i == 13 ? 2 : .65f, Alpha(c, i == 0 || i == 13 ? .85f : game.State == SynkGame.Phase.Recording ? .65f : .25f));
            }
            double visualTime = game.State == SynkGame.Phase.Menu ? Time.unscaledTime * .4 : game.SongTime;
            for (int i = 0; i < 15; i++)
            {
                float d = Mathf.Repeat(i / 15f - (float)visualTime * .12f, 1);
                Line(Project(-.5f, d), Project(12.5f, d), 1, Alpha(purple, .1f * (1 - d)));
            }
            for (int i = 0; i < 36; i++)
            {
                float x = Mathf.Repeat(i * .618f, 1);
                float y = Mathf.Repeat(i * .137f + Time.unscaledTime * .015f, .8f) + .1f;
                if (x > .3f && x < .7f) continue;
                GlowLine(new Vector2(x, y), new Vector2(x + .001f, y + .002f), 2, Alpha(purple, .35f));
            }
            if (game.State == SynkGame.Phase.Playing || game.State == SynkGame.Phase.Paused)
            {
                // Draw far notes first, allowing foreground notes to cover their tails.
                for (int i = game.Notes.Count - 1; i >= 0; i--)
                {
                    var note = game.Notes[i];
                    if (note.done || note.data.time - game.SongTime > SynkGame.Approach) continue;
                    DrawNote(note);
                }
            }
            if (game.State == SynkGame.Phase.Recording)
            {
                foreach (var note in game.OverdubNotes)
                {
                    if (note.time + note.duration < game.SongTime || note.time - game.SongTime > SynkGame.Approach) continue;
                    DrawNote(new SynkGame.LiveNote { data = note, started = note.time <= game.SongTime });
                }
                foreach (var note in game.RecordingNotes)
                    DrawNote(new SynkGame.LiveNote { data = note, started = true });
            }
            GlowLine(Project(-1, 0), Project(13, 0), 3, pink);
            for (int lane = 0; lane < 13; lane++)
            {
                Vector2 p = Project(lane, 0);
                float radius = .008f;
                for (int j = 0; j < 20; j++)
                {
                    float a = j / 20f * Mathf.PI * 2, b = (j + 1) / 20f * Mathf.PI * 2;
                    Vector2 r = new Vector2(radius, radius * rectTransform.rect.width / rectTransform.rect.height);
                    Line(p + Vector2.Scale(new Vector2(Mathf.Cos(a), Mathf.Sin(a)), r), p + Vector2.Scale(new Vector2(Mathf.Cos(b), Mathf.Sin(b)), r), 1, Alpha(purple, .7f));
                }
                if (game.Flash > 0 && game.FlashLane == lane)
                {
                    GlowLine(p - new Vector2(.015f, 0), p + new Vector2(.015f, 0), 12 * game.Flash, Alpha(pink, game.Flash));
                    GlowLine(p, p + new Vector2(0, .09f * game.Flash), 3, Alpha(blue, game.Flash));
                }
            }
        }
        void DrawNote(SynkGame.LiveNote note)
        {
            var n = note.data;
            Color color = n.lane % 2 == 0 ? pink : blue;
            float d = note.started ? 0 : Depth(n.time);
            float currentLane = note.started ? game.ExpectedLane(note) : n.lane;
            if (n.kind == NoteKind.Hold || n.kind == NoteKind.Slide)
            {
                float startT = note.started ? Mathf.Clamp01((float)((game.SongTime - n.time) / Mathf.Max(.01f, n.duration))) : 0;
                for (int segment = 0; segment < 24; segment++)
                {
                    float t0 = Mathf.Lerp(startT, 1, segment / 24f), t1 = Mathf.Lerp(startT, 1, (segment + 1) / 24f);
                    float l0 = n.LaneAt(n.time + n.duration * t0);
                    float l1 = n.LaneAt(n.time + n.duration * t1);
                    float d0 = Mathf.Clamp01(Depth(n.time + n.duration * t0)), d1 = Mathf.Clamp01(Depth(n.time + n.duration * t1));
                    if (n.time + n.duration * t0 - game.SongTime > SynkGame.Approach) continue;
                    Quad(Project(l0 - .3f, d0), Project(l1 - .3f, d1), Project(l1 + .3f, d1), Project(l0 + .3f, d0), Alpha(color, .33f));
                    GlowLine(Project(l0 - .3f, d0), Project(l1 - .3f, d1), 1.5f, Alpha(color, .8f));
                    GlowLine(Project(l0 + .3f, d0), Project(l1 + .3f, d1), 1.5f, Alpha(color, .8f));
                }
                if (n.time + n.duration - game.SongTime <= SynkGame.Approach)
                    Cap(n.kind == NoteKind.Slide ? n.endLane : n.lane, Depth(n.time + n.duration), color);
            }
            if (n.kind != NoteKind.Flick) { Cap(currentLane, d, color); return; }
            Vector2 p = Project(currentLane, d);
            float scale = Mathf.Lerp(1, .2f, d);
            Vector2 dir = n.direction == FlickDirection.Up ? Vector2.up : n.direction == FlickDirection.Down ? Vector2.down : n.direction == FlickDirection.Left ? Vector2.left : Vector2.right;
            Vector2 side = new Vector2(-dir.y, dir.x);
            // Build arrow in pixel space so it remains legible at any aspect ratio.
            Vector2 unit = new Vector2(1 / rectTransform.rect.width, 1 / rectTransform.rect.height);
            for (int j = 0; j < 2; j++)
            {
                Vector2 tip = p + Vector2.Scale(dir * (12 - j * 15) * scale, unit);
                GlowLine(tip + Vector2.Scale((-dir * 15 + side * 17) * scale, unit), tip, 4 * scale, color);
                GlowLine(tip, tip + Vector2.Scale((-dir * 15 - side * 17) * scale, unit), 4 * scale, color);
            }
        }
        void Cap(float lane, float depth, Color color)
        {
            Vector2 a = Project(lane - .36f, depth), b = Project(lane + .36f, depth);
            GlowLine(a, b, Mathf.Lerp(14, 3, depth), color);
        }
    }
}
