using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace Synk
{
    public sealed partial class SynkGame
    {
        readonly ChartDocument document = new ChartDocument();
        GameObject editorRoot;
        ChartTimeline timeline;
        RectTransform songListContent;
        Text editorTitle, editorInfo, editorMessage, transportLabel, snapLabel, loopLabel, speedLabel;
        Slider seekSlider;
        double editCursor, auditionStart, auditionAudio, loopA, loopB = 8;
        float auditionSpeed = 1;
        bool auditioning, loopEnabled, updatingSeek, recordingFromEditor;
        int snapDivision = 4;
        float[] waveform = new float[0];
        double scheduledStart, recordingAudioStart;
        public double EditorCursor => editCursor;
        public double EditorWindowStart => Math.Max(0, editCursor - timeline.seconds * .35);
        public ChartDocument EditorDocument => document;
        public float[] EditorWaveform => waveform;
        public bool EditorLoopEnabled => loopEnabled;
        public double EditorLoopA => loopA;
        public double EditorLoopB => loopB;
        public double EditorEnd => Math.Max(.1, audioSource.clip.length - beatmap.audioOffset + timingOffsetMs / 1000.0);

        void BuildChartEditor()
        {
            InitializeAudioLibrary();
            editorRoot = new GameObject("Chart Studio", typeof(RectTransform), typeof(Image), typeof(CanvasGroup));
            editorRoot.transform.SetParent(panel.transform.parent, false); Stretch(editorRoot.GetComponent<RectTransform>());
            editorRoot.GetComponent<Image>().color = new Color(.009f, .012f, .035f, .99f);
            var root = editorRoot.transform;
            editorTitle = Label(root, "Studio Title", new Vector2(.025f, .9f), new Vector2(.7f, .985f), 28, TextAnchor.MiddleLeft);
            EditorButton(root, "SAVE", .73f, .92f, .84f, .98f, SaveEditor);
            EditorButton(root, "CLOSE", .86f, .92f, .98f, .98f, CloseEditor);
            EditorButton(root, "IMPORT AUDIO", .02f, .81f, .23f, .88f, PickAudio);
            var list = new GameObject("Song Library", typeof(RectTransform), typeof(Image), typeof(Mask), typeof(ScrollRect));
            list.transform.SetParent(root, false); SetRect(list.GetComponent<RectTransform>(), .02f, .2f, .23f, .79f);
            list.GetComponent<Image>().color = new Color(.035f, .025f, .08f); list.GetComponent<Mask>().showMaskGraphic = true;
            songListContent = new GameObject("Songs", typeof(RectTransform)).GetComponent<RectTransform>();
            songListContent.SetParent(list.transform, false); songListContent.anchorMin = new Vector2(0, 1); songListContent.anchorMax = Vector2.one;
            songListContent.pivot = new Vector2(.5f, 1); songListContent.anchoredPosition = Vector2.zero;
            var scroll = list.GetComponent<ScrollRect>(); scroll.content = songListContent; scroll.viewport = list.GetComponent<RectTransform>(); scroll.horizontal = false;
            var grid = new GameObject("Timeline", typeof(RectTransform), typeof(ChartTimeline));
            grid.transform.SetParent(root, false); SetRect(grid.GetComponent<RectTransform>(), .26f, .43f, .98f, .79f);
            timeline = grid.GetComponent<ChartTimeline>(); timeline.game = this;
            seekSlider = MakeSlider(root, .26f, .385f, .98f, .415f);
            seekSlider.onValueChanged.AddListener(value => { if (!updatingSeek) SeekEditor(value); });
            var play = EditorButton(root, "PLAY", .26f, .82f, .35f, .88f, ToggleAudition); transportLabel = play.GetComponentInChildren<Text>();
            EditorButton(root, "REC HERE", .36f, .82f, .48f, .88f, RecordEditorTake);
            EditorButton(root, "−5s", .49f, .82f, .56f, .88f, () => SeekEditor(editCursor - 5));
            EditorButton(root, "+5s", .57f, .82f, .64f, .88f, () => SeekEditor(editCursor + 5));
            EditorButton(root, "ZOOM +", .65f, .82f, .75f, .88f, () => { timeline.seconds = Mathf.Max(2, timeline.seconds / 2); });
            EditorButton(root, "ZOOM −", .76f, .82f, .86f, .88f, () => { timeline.seconds = Mathf.Min(64, timeline.seconds * 2); });
            speedLabel = EditorButton(root, "SPEED", .87f, .82f, .98f, .88f, () => { bool playing = auditioning; StopAudition(); auditionSpeed = auditionSpeed == 1 ? .75f : auditionSpeed == .75f ? .5f : 1; if (playing) BeginAudition(); RefreshEditor(); }).GetComponentInChildren<Text>();
            var snap = EditorButton(root, "SNAP 1/16", .26f, .315f, .41f, .37f, () => { snapDivision = snapDivision == 4 ? 2 : snapDivision == 2 ? 1 : snapDivision == 1 ? 0 : 4; RefreshEditor(); }); snapLabel = snap.GetComponentInChildren<Text>();
            EditorButton(root, "SET A", .42f, .315f, .51f, .37f, () => { loopA = editCursor; if (loopB <= loopA) loopB = Math.Min(EditorEnd, loopA + 4); RefreshEditor(); });
            EditorButton(root, "SET B", .52f, .315f, .61f, .37f, () => { if (editCursor > loopA + .1) loopB = editCursor; else EditorStatus("Loop B must be after A."); RefreshEditor(); });
            var loop = EditorButton(root, "LOOP OFF", .62f, .315f, .75f, .37f, () => { loopEnabled = !loopEnabled; RefreshEditor(); }); loopLabel = loop.GetComponentInChildren<Text>();
            EditorButton(root, "BPM −", .76f, .315f, .86f, .37f, () => ChangeBpm(-1));
            EditorButton(root, "BPM +", .87f, .315f, .98f, .37f, () => ChangeBpm(1));
            editorInfo = Label(root, "Selection", new Vector2(.26f, .235f), new Vector2(.98f, .31f), 18, TextAnchor.MiddleLeft);
            string[] types = { "TAP", "HOLD", "SLIDE", "FLICK" };
            for (int i = 0; i < 4; i++) { var kind = (NoteKind)i; EditorButton(root, types[i], .26f + i * .105f, .17f, .355f + i * .105f, .225f, () => { document.Convert(kind, 60 / beatmap.bpm); var n = document.Selection; if (n != null) document.Move(n.time, n.lane, EditorEnd); RefreshEditor(); }); }
            EditorButton(root, "DIRECTION", .69f, .17f, .83f, .225f, () => EditSelection(n => n.direction = (FlickDirection)(((int)n.direction + 1) % 4)));
            EditorButton(root, "DELETE", .84f, .17f, .98f, .225f, () => { document.Delete(); RefreshEditor(); });
            EditorButton(root, "LANE −", .26f, .105f, .35f, .16f, () => NudgeNote(0, -1));
            EditorButton(root, "LANE +", .36f, .105f, .45f, .16f, () => NudgeNote(0, 1));
            EditorButton(root, "TIME −", .46f, .105f, .55f, .16f, () => NudgeNote(-1, 0));
            EditorButton(root, "TIME +", .56f, .105f, .65f, .16f, () => NudgeNote(1, 0));
            EditorButton(root, "TAIL −", .66f, .105f, .75f, .16f, () => { var n = document.Selection; if (n != null) document.Resize(n.duration - 60 / beatmap.bpm / 4, EditorEnd); RefreshEditor(); });
            EditorButton(root, "TAIL +", .76f, .105f, .85f, .16f, () => { var n = document.Selection; if (n != null) document.Resize(n.duration + 60 / beatmap.bpm / 4, EditorEnd); RefreshEditor(); });
            EditorButton(root, "END LANE", .86f, .105f, .98f, .16f, () => { var n = document.Selection; if (n != null) document.SetEndLane((n.endLane + 1) % 13); RefreshEditor(); });
            EditorButton(root, "ADD", .26f, .04f, .35f, .095f, () => { document.Add(document.Snap(editCursor, beatmap.bpm, snapDivision), 6); RefreshEditor(); });
            EditorButton(root, "UNDO", .36f, .04f, .45f, .095f, () => { document.Undo(); RefreshEditor(); });
            EditorButton(root, "REDO", .46f, .04f, .55f, .095f, () => { document.Redo(); RefreshEditor(); });
            EditorButton(root, "RELOAD", .56f, .04f, .68f, .095f, () => { document.Load(savedNotes ?? beatmap.notes); RefreshEditor(); EditorStatus("Reloaded saved chart. Unsaved edits discarded."); });
            EditorButton(root, "TEST CHART", .69f, .04f, .83f, .095f, () => { StopAudition(); capture.Clear(); capture.notes.AddRange(ChartDocument.Copy(document.notes)); draftAvailable = true; selectedChart = ChartDocument.Copy(document.notes); StartSong(); });
            EditorButton(root, "DUPLICATE", .84f, .04f, .98f, .095f, DuplicateNote);
            editorMessage = Label(root, "Status", new Vector2(.02f, .015f), new Vector2(.23f, .19f), 18, TextAnchor.UpperLeft);
            RefreshLibrary(); BuildWaveform(); editorRoot.SetActive(false);
        }
        static void SetRect(RectTransform r, float x, float y, float right, float top)
        { r.anchorMin = new Vector2(x, y); r.anchorMax = new Vector2(right, top); r.offsetMin = r.offsetMax = Vector2.zero; }
        static Button EditorButton(Transform parent, string text, float x, float y, float right, float top, UnityEngine.Events.UnityAction action)
        { var b = MakeButton(parent, text, new Vector2(x, y), new Vector2(right, top), action); b.GetComponentInChildren<Text>().fontSize = 18; return b; }
        static Slider MakeSlider(Transform parent, float x, float y, float right, float top)
        {
            var obj = new GameObject("Seek", typeof(RectTransform), typeof(Image), typeof(Slider)); obj.transform.SetParent(parent, false); SetRect(obj.GetComponent<RectTransform>(), x, y, right, top);
            obj.GetComponent<Image>().color = new Color(.15f, .12f, .28f);
            var handle = new GameObject("Handle", typeof(RectTransform), typeof(Image)); handle.transform.SetParent(obj.transform, false); handle.GetComponent<RectTransform>().sizeDelta = new Vector2(18, 26); handle.GetComponent<Image>().color = Color.cyan;
            var slider = obj.GetComponent<Slider>(); slider.handleRect = handle.GetComponent<RectTransform>(); slider.targetGraphic = handle.GetComponent<Image>(); return slider;
        }
        void RefreshLibrary()
        {
            if (songListContent == null) return;
            foreach (Transform child in songListContent) Destroy(child.gameObject);
            var entries = new List<SongEntry> { null }; entries.AddRange(library.songs);
            songListContent.sizeDelta = new Vector2(0, entries.Count * 60);
            for (int i = 0; i < entries.Count; i++)
            {
                var entry = entries[i]; var b = EditorButton(songListContent, entry == null ? "ECLIPSE / DEMO" : entry.title, 0, 1, 1, 1, () => ChooseSong(entry));
                var r = b.GetComponent<RectTransform>(); r.offsetMin = new Vector2(4, -i * 60 - 56); r.offsetMax = new Vector2(-4, -i * 60 - 4);
            }
        }
        void OpenEditor()
        {
            StopAudition();
            if (!document.dirty)
            {
                document.Load(draftAvailable ? capture.notes : savedNotes ?? beatmap.notes);
                if (draftAvailable) document.MarkDirty();
            }
            State = Phase.Editing; panel.SetActive(false); pauseButton.gameObject.SetActive(false); UpdateMakerUI();
            EditorStatus("Tap a note to select. Drag to move it. Tap empty timeline to seek. RELOAD discards unsaved edits."); RefreshEditor();
        }
        void CloseEditor()
        {
            StopAudition();
            if (document.dirty) { EditorStatus("Save your chart or use RELOAD to discard changes before closing."); return; }
            ShowMenu();
        }
        void EditorStatus(string message) { if (editorMessage != null) editorMessage.text = message; }
        void RefreshEditor()
        {
            if (editorRoot == null) return;
            editorTitle.text = "SYNK STUDIO  /  " + beatmap.songTitle + "  /  " + beatmap.bpm + " BPM" + (document.dirty ? "  *" : "");
            var n = document.Selection;
            editorInfo.text = n == null ? "No note selected  •  " + document.notes.Count + " notes  •  " + beatmap.bpm + " BPM  •  " + auditionSpeed + "× audition"
                : n.kind + "   " + n.time.ToString("F3") + " s   LANE " + (n.lane + 1) + "   TAIL " + n.duration.ToString("F2") + " s   END " + (n.endLane + 1) + "   " + (n.kind == NoteKind.Flick ? n.direction.ToString() : "");
            snapLabel.text = snapDivision == 0 ? "SNAP OFF" : "SNAP 1/" + (snapDivision * 4);
            loopLabel.text = loopEnabled ? "LOOP ON" : "LOOP OFF";
            transportLabel.text = auditioning ? "PAUSE" : "PLAY";
            speedLabel.text = auditionSpeed + "× SPEED";
            updatingSeek = true; seekSlider.maxValue = (float)EditorEnd; seekSlider.value = (float)editCursor; updatingSeek = false;
        }
        public void SeekEditor(double time)
        {
            bool playing = auditioning; StopAudition(); editCursor = Math.Max(0, Math.Min(EditorEnd - .001, time));
            if (playing) BeginAudition(); RefreshEditor();
        }
        public void SelectEditorNote(int index) { document.selected = index; RefreshEditor(); }
        public void BeginNoteDrag() { StopAudition(); document.Checkpoint(); }
        public void DragEditorNote(double time, int lane) { document.Move(document.Snap(time, beatmap.bpm, snapDivision), lane, EditorEnd); RefreshEditor(); }
        void EditSelection(Action<ChartNote> action)
        { if (document.Selection == null) return; document.Checkpoint(); action(document.Selection); RefreshEditor(); }
        void NudgeNote(int direction, int lane)
        {
            var n = document.Selection; if (n == null) return; document.Checkpoint();
            double step = snapDivision == 0 ? .01 : 60 / beatmap.bpm / snapDivision;
            document.Move(n.time + direction * step, n.lane + lane, EditorEnd); RefreshEditor();
        }
        void DuplicateNote()
        {
            var n = document.Selection; if (n == null) return;
            document.Checkpoint(); var copy = ChartDocument.Copy(new[] { n })[0];
            copy.time = Math.Min(Math.Max(0, EditorEnd - copy.duration), copy.time + 60 / beatmap.bpm);
            document.notes.Add(copy); document.selected = document.notes.Count - 1; RefreshEditor();
        }
        void ChangeBpm(float delta)
        {
            beatmap.bpm = Mathf.Clamp(beatmap.bpm + delta, 30, 300); RefreshEditor();
            var entry = library.songs.Find(s => s.id == songKey);
            if (entry != null) { entry.bpm = beatmap.bpm; try { WriteLibrary(); } catch (Exception e) { EditorStatus("BPM changed, but could not be saved: " + e.Message); } }
        }
        void ToggleAudition() { if (auditioning) StopAudition(); else BeginAudition(); RefreshEditor(); }
        void BeginAudition()
        {
            if (importing) return;
            double position = editCursor + beatmap.audioOffset - timingOffsetMs / 1000.0;
            audioSource.pitch = auditionSpeed; audioSource.time = Mathf.Clamp((float)position, 0, audioSource.clip.length - .001f);
            auditionAudio = audioSource.time; auditionStart = AudioSettings.dspTime; audioSource.Play(); auditioning = true;
        }
        void StopAudition() { auditioning = false; audioSource.Stop(); audioSource.pitch = 1; }
        void UpdateEditor()
        {
            if (!auditioning) return;
            editCursor = Math.Max(0, auditionAudio + (AudioSettings.dspTime - auditionStart) * auditionSpeed - beatmap.audioOffset + timingOffsetMs / 1000.0);
            if (loopEnabled && loopB > loopA + .1 && editCursor >= loopB) { SeekEditor(loopA); return; }
            if (editCursor >= EditorEnd) { editCursor = EditorEnd; StopAudition(); }
            RefreshEditor();
        }
        void SaveEditor()
        {
            StopAudition(); capture.Clear(); capture.notes.AddRange(ChartDocument.Copy(document.notes));
            SaveRecording();
            if (State == Phase.Menu)
            {
                document.Saved(); State = Phase.Editing; panel.SetActive(false); UpdateMakerUI(); RefreshEditor();
                EditorStatus("Chart saved with its audio. It is ready to play from the menu.");
            }
            else EditorStatus("Save failed. Your edits are still here; check device storage and retry.");
        }
        void RecordEditorTake()
        {
            if (importing) return;
            StopAudition(); recordingFromEditor = true;
            StartRecordingAt(editCursor);
        }
        void FinishEditorTake()
        {
            recordingFromEditor = false;
            if (capture.notes.Count > 0) { document.Checkpoint(); document.notes.AddRange(ChartDocument.Copy(capture.notes)); }
            editCursor = Math.Max(0, Math.Min(EditorEnd, SongTime));
            State = Phase.Editing; panel.SetActive(false); pauseButton.gameObject.SetActive(false); UpdateMakerUI(); RefreshEditor();
            EditorStatus("Take added to your chart. Previous notes were kept. Undo removes this take.");
        }
        public IEnumerable<ChartNote> OverdubNotes => recordingFromEditor ? (IEnumerable<ChartNote>)document.notes : Array.Empty<ChartNote>();
        void BuildWaveform()
        {
            waveform = new float[512];
            var clip = audioSource.clip;
            var buffer = new float[256 * clip.channels];
            for (int i = 0; i < waveform.Length; i++)
            {
                int offset = Mathf.Clamp((int)((long)i * clip.samples / waveform.Length), 0, Math.Max(0, clip.samples - 256));
                if (!clip.GetData(buffer, offset)) break;
                float peak = 0; foreach (float sample in buffer) peak = Mathf.Max(peak, Mathf.Abs(sample)); waveform[i] = peak;
            }
        }
    }
}
