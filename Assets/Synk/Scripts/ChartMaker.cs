using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;
using UnityEngine.UI;

namespace Synk
{
    public sealed partial class SynkGame
    {
        [Serializable]
        sealed class SavedChart
        {
            public int version = 1;
            public string songKey;
            public List<ChartNote> notes;
        }
        readonly ChartCapture capture = new ChartCapture();
        CaptureTool captureTool;
        Phase pausedFrom = Phase.Playing;
        List<ChartNote> selectedChart, savedNotes;
        bool draftAvailable;
        string chartPath, songKey, loadMessage = "";
        GameObject makerMenu, recordingTools;
        Button savedButton, testButton;
        readonly List<Button> toolButtons = new List<Button>();
        IEnumerable<ChartNote> PlaybackNotes => selectedChart ?? beatmap.notes;
        public IEnumerable<ChartNote> RecordingNotes => capture.ActiveNotes;

        static string Hash(string value)
        {
            using (var sha = SHA256.Create())
                return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(value))).Replace("-", "").ToLowerInvariant();
        }
        void BuildChartMaker()
        {
            songKey = Hash(beatmap.songTitle + "|" + beatmap.artist + "|" + audioSource.clip.length.ToString("R", CultureInfo.InvariantCulture) + "|" + beatmap.audioOffset.ToString("R", CultureInfo.InvariantCulture));
            chartPath = Path.Combine(Application.persistentDataPath, "Charts", songKey + ".json");
            LoadRecording();
            // Secondary actions sit below the modal, away from the recording surface.
            var parent = panel.transform.parent;
            makerMenu = new GameObject("Chart Actions", typeof(RectTransform));
            makerMenu.transform.SetParent(parent, false);
            var mr = makerMenu.GetComponent<RectTransform>(); Stretch(mr);
            MakeButton(mr, "RECORD NEW CHART", new Vector2(.04f, .04f), new Vector2(.32f, .11f), StartRecording);
            savedButton = MakeButton(mr, "PLAY SAVED CHART", new Vector2(.36f, .04f), new Vector2(.64f, .11f), () => { selectedChart = savedNotes; StartSong(); });
            MakeButton(mr, "PLAY ORIGINAL", new Vector2(.68f, .04f), new Vector2(.96f, .11f), () => { selectedChart = null; StartSong(); });
            testButton = MakeButton(mr, "TEST DRAFT", new Vector2(.36f, .115f), new Vector2(.64f, .165f), () => {
                if (State == Phase.Results) StopRecording();
                else { selectedChart = capture.SortedNotes(); StartSong(); }
            });
            var studio = MakeButton(mr, "CHART STUDIO / IMPORT AUDIO", new Vector2(.65f, .115f), new Vector2(.98f, .165f), OpenEditor);
            studio.GetComponentInChildren<Text>().fontSize = 18;
            recordingTools = new GameObject("Recorder Controls", typeof(RectTransform));
            recordingTools.transform.SetParent(parent, false);
            var rr = recordingTools.GetComponent<RectTransform>(); Stretch(rr);
            for (int i = 0; i < 5; i++)
            {
                var tool = (CaptureTool)i;
                toolButtons.Add(MakeButton(rr, tool.ToString().ToUpperInvariant(), new Vector2(.15f + i * .12f, .91f), new Vector2(.26f + i * .12f, .98f), () => { captureTool = tool; UpdateToolColors(); }));
            }
            MakeButton(rr, "UNDO", new Vector2(.77f, .91f), new Vector2(.87f, .98f), () => { capture.Undo(); Judgement = "UNDONE"; Flash = 1; });
            MakeButton(rr, "STOP", new Vector2(.89f, .91f), new Vector2(.99f, .98f), StopRecording);
            Label(rr, "Recording Help", new Vector2(.05f, .025f), new Vector2(.95f, .11f), 21, TextAnchor.MiddleCenter).text =
                "AUTO: tap • hold still • drag to slide • quick swipe to flick\nRecord near the glowing line. STOP to review and save.";
            UpdateToolColors(); UpdateMakerUI();
        }
        void UpdateToolColors()
        {
            for (int i = 0; i < toolButtons.Count; i++) toolButtons[i].GetComponent<Image>().color = i == (int)captureTool
                ? new Color(.12f, .4f, .6f) : new Color(.26f, .09f, .48f);
        }
        void UpdateMakerUI()
        {
            if (makerMenu == null) return;
            bool menus = State == Phase.Menu || State == Phase.Results || State == Phase.ChartReview;
            makerMenu.SetActive(menus);
            recordingTools.SetActive(State == Phase.Recording);
            if (editorRoot != null) editorRoot.SetActive(State == Phase.Editing);
            judgementLabel.gameObject.SetActive(State != Phase.Editing);
            savedButton.interactable = savedNotes != null && savedNotes.Count > 0;
            testButton.gameObject.SetActive(draftAvailable && capture.notes.Count > 0 && (State == Phase.ChartReview || State == Phase.Results));
            testButton.GetComponentInChildren<Text>().text = State == Phase.Results ? "BACK TO DRAFT" : "TEST DRAFT";
            offsetSlider.gameObject.SetActive(State != Phase.ChartReview);
            offsetLabel.gameObject.SetActive(State != Phase.ChartReview);
            songLabel.gameObject.SetActive(State != Phase.Recording && State != Phase.Editing);
            scoreLabel.gameObject.SetActive(State != Phase.Editing);
            if (State == Phase.Recording)
            {
                var rt = scoreLabel.rectTransform;
                rt.anchorMin = new Vector2(.62f, .77f); rt.anchorMax = new Vector2(.97f, .88f);
            }
            else
            {
                scoreLabel.rectTransform.anchorMin = new Vector2(.62f, .84f);
                scoreLabel.rectTransform.anchorMax = new Vector2(.97f, .98f);
            }
            if (State == Phase.Menu && !string.IsNullOrEmpty(loadMessage)) centerBody.text += "\n" + loadMessage;
        }
        void StartRecording()
        {
            if (document.dirty) { OpenEditor(); EditorStatus("Save or RELOAD your edits before starting a new chart."); return; }
            recordingFromEditor = false;
            StartRecordingAt(0);
        }
        void StartRecordingAt(double chartTime)
        {
            capture.Clear(); pointers.Clear(); Notes.Clear(); draftAvailable = false;
            captureTool = CaptureTool.Auto; UpdateToolColors();
            scheduledStart = AudioSettings.dspTime + 3;
            recordingAudioStart = Math.Max(0, Math.Min(audioSource.clip.length - .01, chartTime + beatmap.audioOffset - timingOffsetMs / 1000.0));
            origin = scheduledStart - recordingAudioStart;
            SongTime = chartTime - 3; audioSource.Stop(); audioSource.pitch = 1; audioSource.time = (float)recordingAudioStart; audioSource.PlayScheduled(scheduledStart);
            State = Phase.Recording; panel.SetActive(false); pauseButton.gameObject.SetActive(true);
            Judgement = "GET READY"; Flash = 1; UpdateMakerUI();
        }
        void UpdateRecording()
        {
            SongTime = AudioSettings.dspTime - origin - beatmap.audioOffset + timingOffsetMs / 1000.0;
            double untilAudio = scheduledStart - AudioSettings.dspTime;
            if (untilAudio > 0) { Judgement = "RECORD IN " + Math.Ceiling(untilAudio); Flash = 1; }
            if (untilAudio > 0) return;
            for (int i = 0; i < Input.touchCount; i++)
            {
                var touch = Input.GetTouch(i);
                RecordPointer(touch.fingerId, Normalize(touch.position), touch.phase == TouchPhase.Began,
                    touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled, touch.phase == TouchPhase.Canceled);
            }
            if (Input.touchCount == 0 && (Input.GetMouseButton(0) || Input.GetMouseButtonUp(0)))
                RecordPointer(-1, Normalize(Input.mousePosition), Input.GetMouseButtonDown(0), Input.GetMouseButtonUp(0), false);
            if (AudioSettings.dspTime - origin >= audioSource.clip.length) StopRecording();
        }
        void RecordPointer(int id, Vector2 p, bool began, bool ended, bool canceled)
        {
            if (began) capture.Begin(id, SongTime, p.x, p.y, captureTool);
            capture.Move(id, SongTime, p.x, p.y);
            if (!ended) return;
            var note = capture.End(id, SongTime, p.x, p.y, canceled);
            if (note == null) return;
            FlashLane = note.endLane; Flash = 1;
            Judgement = note.kind.ToString().ToUpperInvariant() + " RECORDED";
        }
        void StopRecording()
        {
            // Unfinished touches are discarded, just like OS-canceled touches.
            capture.CancelActive(); audioSource.Stop();
            if (recordingFromEditor) { FinishEditorTake(); return; }
            State = Phase.ChartReview; draftAvailable = true; panel.SetActive(true); pauseButton.gameObject.SetActive(false);
            centerTitle.text = "CHART RECORDED";
            int taps = 0, holds = 0, slides = 0, flicks = 0;
            foreach (var note in capture.notes)
                switch (note.kind) { case NoteKind.Tap: taps++; break; case NoteKind.Hold: holds++; break; case NoteKind.Slide: slides++; break; case NoteKind.Flick: flicks++; break; }
            centerBody.text = capture.notes.Count + " NOTES\n\n" + taps + " TAP   " + holds + " HOLD   " + slides + " SLIDE   " + flicks + " FLICK\n\nTest your draft or save it on this device.\nSaving replaces your previous saved chart for this song.\nRECORD NEW CHART discards this draft.\nUnfinished gestures are discarded when stopped.";
            buttonLabel.text = "SAVE CHART";
            UpdateMakerUI();
        }
        void SaveRecording()
        {
            var notes = capture.SortedNotes();
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(chartPath));
                var json = JsonUtility.ToJson(new SavedChart { songKey = songKey, notes = notes }, true);
                string temp = chartPath + ".tmp";
                File.WriteAllText(temp, json);
                if (File.Exists(chartPath)) File.Replace(temp, chartPath, chartPath + ".bak");
                else File.Move(temp, chartPath);
                savedNotes = notes; selectedChart = savedNotes; draftAvailable = false;
                if (State == Phase.Editing) document.Saved(); else document.Load(notes);
                ShowMenu(); centerBody.text = "CHART SAVED\n\n" + notes.Count + " notes saved on this device.\n\nPress PLAY to test your chart.\nPLAY ORIGINAL returns to the original chart.";
                buttonLabel.text = "PLAY MY CHART";
            }
            catch (Exception error) when (error is IOException || error is UnauthorizedAccessException || error is NotSupportedException)
            { centerBody.text = "Could not save the chart. Your draft is still here.\n\nFree up storage and try SAVE CHART again."; Debug.LogWarning(error.Message); }
        }
        void LoadRecording()
        {
            if (!File.Exists(chartPath)) return;
            try
            {
                var saved = JsonUtility.FromJson<SavedChart>(File.ReadAllText(chartPath));
                if (saved == null || saved.version != 1 || saved.songKey != songKey || saved.notes == null || saved.notes.Count > 100000)
                    throw new InvalidDataException("Unsupported chart file");
                foreach (var note in saved.notes)
                {
                    if (note == null || double.IsNaN(note.time) || double.IsInfinity(note.time) || note.time < 0 ||
                        note.lane < 0 || note.lane > 12 || note.endLane < 0 || note.endLane > 12 ||
                        float.IsNaN(note.duration) || float.IsInfinity(note.duration) || note.duration < 0 ||
                        !Enum.IsDefined(typeof(NoteKind), note.kind) || !Enum.IsDefined(typeof(FlickDirection), note.direction))
                        throw new InvalidDataException("Invalid chart note");
                    float previous = -1;
                    if (note.path == null) continue;
                    foreach (var point in note.path)
                    {
                        if (point == null || float.IsNaN(point.offset) || float.IsInfinity(point.offset) || point.offset <= previous ||
                            point.offset < 0 || point.offset > note.duration || float.IsNaN(point.lane) || point.lane < 0 || point.lane > 12)
                            throw new InvalidDataException("Invalid slide path");
                        previous = point.offset;
                    }
                }
                saved.notes.Sort((a, b) => a.time.CompareTo(b.time));
                savedNotes = saved.notes;
            }
            catch (Exception error) when (error is IOException || error is UnauthorizedAccessException || error is ArgumentException)
            { loadMessage = "Saved chart could not be loaded. You can record a new one."; Debug.LogWarning(error.Message); }
        }
    }
}
