using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace Synk
{
    public sealed class SynkGame : MonoBehaviour
    {
        public Beatmap beatmap;
        public float timingOffsetMs;
        public const float Approach = 2.6f;
        public const double Window = .16;
        public enum Phase { Menu, Playing, Paused, Results }
        public Phase State { get; private set; }
        public double SongTime { get; private set; }
        public int Score { get; private set; }
        public int Combo { get; private set; }
        public int BestCombo { get; private set; }
        public string Judgement { get; private set; } = "";
        public float Flash { get; private set; }
        public int FlashLane { get; private set; } = 6;
        public List<LiveNote> Notes { get; } = new List<LiveNote>();
        public sealed class LiveNote
        {
            public ChartNote data;
            public bool started, done;
            public int pointer = int.MinValue;
            public double error;
        }
        sealed class Pointer
        {
            public Vector2 start, position;
            public double time;
        }
        readonly Dictionary<int, Pointer> pointers = new Dictionary<int, Pointer>();
        readonly List<int> released = new List<int>();
        AudioSource audioSource;
        AudioClip generatedAudio;
        double origin, pausedAt, endTime, resumeGrace;
        float earned;
        int judged, perfect, great, good, misses;
        RectTransform surface;
        Text songLabel, scoreLabel, judgementLabel, centerTitle, centerBody, buttonLabel;
        GameObject panel;
        Button pauseButton;
        Slider offsetSlider;
        Text offsetLabel;

        public float Accuracy => judged == 0 ? 100 : earned / judged * 100;
        public string Rank => Accuracy >= 98 ? "SS" : Accuracy >= 95 ? "S" : Accuracy >= 90 ? "A" : Accuracy >= 80 ? "B" : "C";

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Bootstrap()
        {
            if (FindFirstObjectByType<SynkGame>() == null)
                new GameObject("SYNK").AddComponent<SynkGame>();
        }

        void Awake()
        {
            Application.targetFrameRate = 120;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            if (beatmap == null) beatmap = Beatmap.Demo();
            timingOffsetMs = PlayerPrefs.GetFloat("SynkTimingOffset", timingOffsetMs);
            audioSource = gameObject.AddComponent<AudioSource>();
            audioSource.playOnAwake = false;
            endTime = 0;
            foreach (var note in beatmap.notes)
                endTime = Math.Max(endTime, note.time + note.duration + 2);
            endTime = Math.Max(endTime, 10);
            audioSource.clip = beatmap.music;
            if (audioSource.clip == null)
            {
                generatedAudio = DemoAudio.Create(beatmap.bpm, (float)endTime + 1);
                audioSource.clip = generatedAudio;
            }
            BuildUI();
            ShowMenu();
        }

        void BuildUI()
        {
            var canvasObject = new GameObject("SYNK Canvas", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            canvasObject.transform.SetParent(transform, false);
            canvasObject.GetComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasObject.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1600, 900);
            scaler.matchWidthOrHeight = .5f;
            surface = canvasObject.GetComponent<RectTransform>();
            var field = new GameObject("Neon Highway", typeof(RectTransform), typeof(NeonHighway));
            field.transform.SetParent(surface, false);
            Stretch(field.GetComponent<RectTransform>());
            field.GetComponent<NeonHighway>().game = this;
            field.GetComponent<NeonHighway>().raycastTarget = false;

            // HUD stays inside the device safe area, including camera cutouts.
            var safe = new GameObject("Safe Area", typeof(RectTransform)).GetComponent<RectTransform>();
            safe.SetParent(surface, false);
            var area = Screen.safeArea;
            safe.anchorMin = new Vector2(area.xMin / Screen.width, area.yMin / Screen.height);
            safe.anchorMax = new Vector2(area.xMax / Screen.width, area.yMax / Screen.height);
            safe.offsetMin = safe.offsetMax = Vector2.zero;
            songLabel = Label(safe, "Song", new Vector2(.13f, .86f), new Vector2(.38f, .98f), 27, TextAnchor.UpperLeft);
            songLabel.text = beatmap.songTitle + "\n<size=18>" + beatmap.artist + "   /   " + beatmap.difficulty + "  Lv. " + beatmap.level + "</size>";
            scoreLabel = Label(safe, "Score", new Vector2(.62f, .84f), new Vector2(.97f, .98f), 34, TextAnchor.UpperRight);
            judgementLabel = Label(safe, "Judgement", new Vector2(.3f, .12f), new Vector2(.7f, .22f), 42, TextAnchor.MiddleCenter);
            pauseButton = MakeButton(safe, "II", new Vector2(.02f, .88f), new Vector2(.09f, .98f), TogglePause);

            panel = new GameObject("Menu", typeof(RectTransform), typeof(Image));
            panel.transform.SetParent(safe, false);
            var pr = panel.GetComponent<RectTransform>();
            pr.anchorMin = new Vector2(.19f, .17f); pr.anchorMax = new Vector2(.81f, .83f); pr.offsetMin = pr.offsetMax = Vector2.zero;
            panel.GetComponent<Image>().color = new Color(.015f, .02f, .065f, .96f);
            centerTitle = Label(pr, "Title", new Vector2(.05f, .72f), new Vector2(.95f, .95f), 62, TextAnchor.MiddleCenter);
            centerTitle.color = new Color(.75f, .52f, 1);
            centerBody = Label(pr, "Instructions", new Vector2(.06f, .32f), new Vector2(.94f, .72f), 22, TextAnchor.MiddleCenter);
            var start = MakeButton(pr, "PLAY ECLIPSE", new Vector2(.22f, .07f), new Vector2(.78f, .2f), PrimaryAction);
            buttonLabel = start.GetComponentInChildren<Text>();
            offsetLabel = Label(pr, "Offset", new Vector2(.08f, .24f), new Vector2(.92f, .31f), 17, TextAnchor.MiddleCenter);
            var sliderObj = new GameObject("Timing Offset", typeof(RectTransform), typeof(Image), typeof(Slider));
            sliderObj.transform.SetParent(pr, false);
            var sr = sliderObj.GetComponent<RectTransform>();
            sr.anchorMin = new Vector2(.25f, .21f); sr.anchorMax = new Vector2(.75f, .23f); sr.offsetMin = sr.offsetMax = Vector2.zero;
            sliderObj.GetComponent<Image>().color = new Color(.18f, .12f, .3f);
            var handle = new GameObject("Handle", typeof(RectTransform), typeof(Image));
            handle.transform.SetParent(sr, false);
            handle.GetComponent<Image>().color = Color.cyan;
            handle.GetComponent<RectTransform>().sizeDelta = new Vector2(20, 24);
            offsetSlider = sliderObj.GetComponent<Slider>();
            offsetSlider.handleRect = handle.GetComponent<RectTransform>();
            offsetSlider.targetGraphic = handle.GetComponent<Image>();
            offsetSlider.minValue = -200; offsetSlider.maxValue = 200; offsetSlider.wholeNumbers = true;
            offsetSlider.value = timingOffsetMs;
            offsetSlider.onValueChanged.AddListener(value => { timingOffsetMs = value; PlayerPrefs.SetFloat("SynkTimingOffset", value); UpdateOffset(); });
            UpdateOffset();
            if (FindFirstObjectByType<UnityEngine.EventSystems.EventSystem>() == null)
                new GameObject("EventSystem", typeof(UnityEngine.EventSystems.EventSystem), typeof(UnityEngine.EventSystems.StandaloneInputModule));
        }

        static void Stretch(RectTransform rect)
        { rect.anchorMin = Vector2.zero; rect.anchorMax = Vector2.one; rect.offsetMin = rect.offsetMax = Vector2.zero; }
        static Font font;
        static Text Label(Transform parent, string name, Vector2 min, Vector2 max, int size, TextAnchor alignment)
        {
            var obj = new GameObject(name, typeof(RectTransform), typeof(Text)); obj.transform.SetParent(parent, false);
            var rt = obj.GetComponent<RectTransform>(); rt.anchorMin = min; rt.anchorMax = max; rt.offsetMin = rt.offsetMax = Vector2.zero;
            var text = obj.GetComponent<Text>();
            if (font == null) font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            text.font = font; text.fontSize = size; text.alignment = alignment; text.color = new Color(.9f, .92f, 1);
            text.supportRichText = true; text.raycastTarget = false;
            return text;
        }
        static Button MakeButton(Transform parent, string title, Vector2 min, Vector2 max, UnityEngine.Events.UnityAction action)
        {
            var obj = new GameObject(title, typeof(RectTransform), typeof(Image), typeof(Button)); obj.transform.SetParent(parent, false);
            var rt = obj.GetComponent<RectTransform>(); rt.anchorMin = min; rt.anchorMax = max; rt.offsetMin = rt.offsetMax = Vector2.zero;
            obj.GetComponent<Image>().color = new Color(.26f, .09f, .48f, .95f);
            var button = obj.GetComponent<Button>(); button.onClick.AddListener(action);
            Label(rt, "Label", Vector2.zero, Vector2.one, 26, TextAnchor.MiddleCenter).text = title;
            return button;
        }
        void UpdateOffset() => offsetLabel.text = "TIMING OFFSET  " + timingOffsetMs.ToString("+0;-0;0") + " ms   ·   adjust for your audio device";
        void ShowMenu()
        {
            State = Phase.Menu; panel.SetActive(true); pauseButton.gameObject.SetActive(false);
            centerTitle.text = "S Y N K";
            centerBody.text = "ECLIPSE  /  128 BPM\n\n13 lanes. Follow the light.\nTAP on arrival  •  HOLD to the end\nSLIDE along the ribbon  •  FLICK in the arrow direction\n\nTouch near the glowing line. Mouse works in the editor.";
            buttonLabel.text = "PLAY ECLIPSE";
        }
        void PrimaryAction() { if (State == Phase.Paused) Resume(); else StartSong(); }
        void StartSong()
        {
            Notes.Clear(); pointers.Clear();
            foreach (var note in beatmap.notes) Notes.Add(new LiveNote { data = note });
            Notes.Sort((a, b) => a.data.time.CompareTo(b.data.time));
            Score = Combo = BestCombo = judged = perfect = great = good = misses = 0; earned = 0;
            SongTime = -1; Judgement = "READY"; Flash = 1;
            origin = AudioSettings.dspTime + 1;
            audioSource.Stop(); audioSource.time = 0; audioSource.PlayScheduled(origin);
            State = Phase.Playing; panel.SetActive(false); pauseButton.gameObject.SetActive(true);
        }
        void TogglePause() { if (State == Phase.Playing) Pause(); else if (State == Phase.Paused) Resume(); }
        void Pause()
        {
            pausedAt = AudioSettings.dspTime; audioSource.Pause(); State = Phase.Paused;
            pointers.Clear();
            // Releasing a sustained gesture on pause cannot earn an automatic completion.
            foreach (var note in Notes) if (note.started && !note.done) note.pointer = int.MinValue;
            panel.SetActive(true); centerTitle.text = "PAUSED";
            centerBody.text = "Take a breath.\n\nResume and touch active ribbons to continue.";
            buttonLabel.text = "RESUME";
        }
        void Resume()
        {
            double now = AudioSettings.dspTime;
            origin += now - pausedAt;
            if (now < origin) { audioSource.Stop(); audioSource.PlayScheduled(origin); } else audioSource.UnPause();
            resumeGrace = now + .3;
            State = Phase.Playing; panel.SetActive(false);
        }
        void OnApplicationPause(bool paused) { if (paused && State == Phase.Playing) Pause(); }
        void OnApplicationFocus(bool focus) { if (!focus && State == Phase.Playing) Pause(); }
        void OnDestroy() { if (generatedAudio != null) Destroy(generatedAudio); }

        void Update()
        {
            Flash = Mathf.Max(0, Flash - Time.unscaledDeltaTime * 2.5f);
            if (Input.GetKeyDown(KeyCode.Escape)) TogglePause();
            if (State == Phase.Playing)
            {
                SongTime = AudioSettings.dspTime - origin - beatmap.audioOffset + timingOffsetMs / 1000.0;
                ReadInput();
                foreach (var note in Notes)
                {
                    if (note.done) continue;
                    if (!note.started && SongTime > note.data.time + Window) { Judge(note, -1); continue; }
                    if (!note.started) continue;
                    if (note.pointer == int.MinValue && AudioSettings.dspTime < resumeGrace) continue;
                    bool down = pointers.TryGetValue(note.pointer, out var pointer);
                    if (note.data.kind == NoteKind.Flick)
                    {
                        if (down && FlickMatches(note.data.direction, pointer.position - pointer.start)) Judge(note, note.error);
                        else if (!down || SongTime > note.data.time + Window) Judge(note, -1);
                    }
                    else
                    {
                        float lane = ExpectedLane(note);
                        if (!down || Mathf.Abs(LaneAt(pointer.position.x) - lane) > 1.2f || pointer.position.y > .4f)
                            Judge(note, -1);
                        else if (SongTime >= note.data.time + note.data.duration - .045) Judge(note, note.error);
                    }
                }
                foreach (int id in released) pointers.Remove(id);
                if (SongTime > endTime) Finish();
            }
            scoreLabel.text = Score.ToString("N0") + "   <color=#B873FF>" + Rank + "</color>\n<size=22>COMBO  " + Combo + "   /   " + Accuracy.ToString("F2") + "%</size>";
            judgementLabel.text = Judgement;
            judgementLabel.color = new Color(.85f, .65f, 1, Flash);
        }

        Vector2 Normalize(Vector2 screen)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(surface, screen, null, out var local);
            return new Vector2(local.x / surface.rect.width + .5f, local.y / surface.rect.height + .5f);
        }
        public static float LaneAt(float x) => (x - .07f) / .86f * 13 - .5f;
        public float ExpectedLane(LiveNote note)
        {
            if (note.data.kind != NoteKind.Slide) return note.data.lane;
            float t = Mathf.Clamp01((float)((SongTime - note.data.time) / Math.Max(.01, note.data.duration)));
            return Mathf.Lerp(note.data.lane, note.data.endLane, t * t * (3 - 2 * t));
        }
        void ReadInput()
        {
            released.Clear();
            for (int i = 0; i < Input.touchCount; i++)
            {
                var touch = Input.GetTouch(i);
                HandlePointer(touch.fingerId, Normalize(touch.position), touch.phase == TouchPhase.Began,
                    touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled);
            }
            if (Input.touchCount == 0 && (Input.GetMouseButton(0) || Input.GetMouseButtonUp(0)))
                HandlePointer(-1, Normalize(Input.mousePosition), Input.GetMouseButtonDown(0), Input.GetMouseButtonUp(0));
        }
        void HandlePointer(int id, Vector2 position, bool began, bool ended)
        {
            if (began)
            {
                pointers[id] = new Pointer { start = position, position = position, time = SongTime };
                if (position.y < .4f)
                {
                    LiveNote nearest = null; double best = Window + .001;
                    foreach (var note in Notes)
                    {
                        if (note.done) continue;
                        if (note.started)
                        {
                            if (note.pointer == int.MinValue && Mathf.Abs(LaneAt(position.x) - ExpectedLane(note)) < .85f) note.pointer = id;
                            continue;
                        }
                        double delta = Math.Abs(SongTime - note.data.time);
                        if (delta <= best && Mathf.Abs(LaneAt(position.x) - note.data.lane) < .85f) { best = delta; nearest = note; }
                    }
                    if (nearest != null)
                    {
                        nearest.error = best; nearest.pointer = id; nearest.started = true;
                        if (nearest.data.kind == NoteKind.Tap) Judge(nearest, best);
                    }
                }
            }
            if (pointers.TryGetValue(id, out var pointer)) pointer.position = position;
            if (ended) released.Add(id);
        }
        static bool FlickMatches(FlickDirection direction, Vector2 delta)
        {
            // Threshold is relative to screen height/width, so it scales across devices.
            switch (direction)
            {
                case FlickDirection.Up: return delta.y > .035f && delta.y > Mathf.Abs(delta.x);
                case FlickDirection.Down: return delta.y < -.035f && -delta.y > Mathf.Abs(delta.x);
                case FlickDirection.Right: return delta.x > .035f && delta.x > Mathf.Abs(delta.y);
                default: return delta.x < -.035f && -delta.x > Mathf.Abs(delta.y);
            }
        }
        void Judge(LiveNote note, double error)
        {
            note.done = true; judged++; Flash = 1; FlashLane = Mathf.RoundToInt(ExpectedLane(note));
            float value;
            if (error < 0) { Judgement = "MISS"; misses++; Combo = 0; value = 0; }
            else
            {
                Combo++; BestCombo = Mathf.Max(BestCombo, Combo);
                if (error <= .045) { Judgement = "PERFECT"; perfect++; value = 1; }
                else if (error <= .09) { Judgement = "GREAT"; great++; value = .8f; }
                else { Judgement = "GOOD"; good++; value = .5f; }
            }
            earned += value;
            Score = Mathf.RoundToInt(1000000f * earned / Mathf.Max(1, Notes.Count));
        }
        void Finish()
        {
            State = Phase.Results; audioSource.Stop(); panel.SetActive(true); pauseButton.gameObject.SetActive(false);
            int best = Mathf.Max(PlayerPrefs.GetInt("SynkBestScore", 0), Score);
            PlayerPrefs.SetInt("SynkBestScore", best); PlayerPrefs.Save();
            centerTitle.text = Rank + "  /  " + Score.ToString("N0");
            centerBody.text = "TRACK COMPLETE\n\n" + Accuracy.ToString("F2") + "% ACCURACY    •    " + BestCombo + " MAX COMBO\n" +
                perfect + " PERFECT    " + great + " GREAT    " + good + " GOOD    " + misses + " MISS\n\nPERSONAL BEST  " + best.ToString("N0");
            buttonLabel.text = "PLAY AGAIN";
        }
    }
}
