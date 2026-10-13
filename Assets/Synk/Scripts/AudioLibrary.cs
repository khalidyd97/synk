using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using UnityEngine;
using UnityEngine.Networking;

namespace Synk
{
    public sealed partial class SynkGame
    {
        [Serializable] sealed class SongEntry { public string id, title, file; public float bpm = 128; }
        [Serializable] sealed class SongLibrary { public List<SongEntry> songs = new List<SongEntry>(); }
        SongLibrary library = new SongLibrary();
        Beatmap originalMap;
        AudioClip originalClip, importedClip;
        bool importing;
        void SetImportBusy(bool busy)
        {
            importing = busy;
            if (editorRoot != null) editorRoot.GetComponent<CanvasGroup>().interactable = !busy;
        }
        string LibraryPath => Path.Combine(Application.persistentDataPath, "Songs", "library.json");
        void InitializeAudioLibrary()
        {
            originalMap = beatmap; originalClip = audioSource.clip;
            try
            {
                if (File.Exists(LibraryPath)) library = JsonUtility.FromJson<SongLibrary>(File.ReadAllText(LibraryPath)) ?? new SongLibrary();
                if (library.songs == null) library.songs = new List<SongEntry>();
                library.songs.RemoveAll(s => s == null || string.IsNullOrEmpty(s.file) || Path.GetFileName(s.file) != s.file ||
                    string.IsNullOrEmpty(s.id) || !System.Text.RegularExpressions.Regex.IsMatch(s.id, "^[a-f0-9]{64}$") || float.IsNaN(s.bpm) || float.IsInfinity(s.bpm));
                foreach (var entry in library.songs) entry.bpm = Mathf.Clamp(entry.bpm, 30, 300);
            }
            catch (Exception e) { Debug.LogWarning(e.Message); library = new SongLibrary(); }
        }
        bool CanSwitchSong()
        {
            if (importing) { EditorStatus("Audio is still loading…"); return false; }
            if (document.dirty) { EditorStatus("Save your chart or use RELOAD to discard changes before switching songs."); return false; }
            return true;
        }
        void PickAudio()
        {
            if (!CanSwitchSong()) return;
#if UNITY_EDITOR
            string path = UnityEditor.EditorUtility.OpenFilePanel("Import audio (MP3, WAV, OGG)", "", "");
            if (!string.IsNullOrEmpty(path)) StartCoroutine(LoadAudio(path, null));
#elif UNITY_ANDROID || UNITY_IOS
            NativeFilePicker.PickFile(path => { if (!string.IsNullOrEmpty(path)) StartCoroutine(LoadAudio(path, null)); },
#if UNITY_ANDROID
                "audio/*"
#else
                "public.audio"
#endif
            );
#else
            EditorStatus("Audio import is available in the Unity Editor, Android and iOS builds.");
#endif
        }
        void ChooseSong(SongEntry entry)
        {
            if (!CanSwitchSong()) return;
            if (entry == null) { ApplySong(originalMap, originalClip, null); return; }
            StartCoroutine(LoadAudio(Path.Combine(Path.GetDirectoryName(LibraryPath), entry.file), entry));
        }
        IEnumerator LoadAudio(string path, SongEntry entry)
        {
            string ext = Path.GetExtension(path).ToLowerInvariant();
            AudioType type = ext == ".wav" ? AudioType.WAV : ext == ".mp3" ? AudioType.MPEG : ext == ".ogg" ? AudioType.OGGVORBIS : AudioType.UNKNOWN;
            if (type == AudioType.UNKNOWN) { EditorStatus("Choose MP3, WAV or OGG audio. Convert M4A/AAC files first."); yield break; }
            if (!File.Exists(path)) { EditorStatus("This audio file is missing. Import it again."); yield break; }
            if (new FileInfo(path).Length > 150L * 1024 * 1024) { EditorStatus("Choose an audio file smaller than 150 MB."); yield break; }
            SetImportBusy(true); StopAudition(); EditorStatus("Loading audio…");
            using (var request = UnityWebRequestMultimedia.GetAudioClip(new Uri(Path.GetFullPath(path)).AbsoluteUri, type))
            {
                yield return request.SendWebRequest();
                if (request.result != UnityWebRequest.Result.Success)
                { SetImportBusy(false); EditorStatus("Could not decode audio. Try a standard MP3 or WAV file."); yield break; }
                AudioClip clip = DownloadHandlerAudioClip.GetContent(request);
                if (clip == null || clip.length < .2f || clip.length > 1200)
                { if (clip != null) Destroy(clip); SetImportBusy(false); EditorStatus("Choose a song between 0.2 seconds and 20 minutes."); yield break; }
                bool success = true;
                try
                {
                    if (entry == null)
                    {
                        string id;
                        using (var sha = SHA256.Create()) using (var stream = File.OpenRead(path))
                            id = BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "").ToLowerInvariant();
                        entry = library.songs.Find(s => s.id == id);
                        if (entry == null)
                        {
                            entry = new SongEntry { id = id, title = Path.GetFileNameWithoutExtension(path), file = id + ext };
                            Directory.CreateDirectory(Path.GetDirectoryName(LibraryPath));
                            File.Copy(path, Path.Combine(Path.GetDirectoryName(LibraryPath), entry.file), true);
                            library.songs.Add(entry);
                            try { WriteLibrary(); } catch { library.songs.Remove(entry); throw; }
                        }
                    }
                }
                catch (Exception e) { success = false; Debug.LogWarning(e.Message); EditorStatus("Audio could not be saved. Check device storage."); }
                SetImportBusy(false);
                if (!success) { Destroy(clip); yield break; }
                var map = ScriptableObject.CreateInstance<Beatmap>();
                map.songTitle = entry.title; map.artist = "My Library"; map.bpm = entry.bpm; map.music = clip; map.difficulty = "CUSTOM";
                ApplySong(map, clip, entry.id);
                EditorStatus("Audio imported and kept on this device. Record from any position or add notes on the timeline.");
            }
        }
        void WriteLibrary()
        {
            string temp = LibraryPath + ".tmp";
            File.WriteAllText(temp, JsonUtility.ToJson(library, true));
            if (File.Exists(LibraryPath)) File.Replace(temp, LibraryPath, LibraryPath + ".bak"); else File.Move(temp, LibraryPath);
        }
        void ApplySong(Beatmap map, AudioClip clip, string id)
        {
            StopAudition(); capture.Clear(); draftAvailable = false;
            if (importedClip != null) Destroy(importedClip);
            if (beatmap != originalMap) Destroy(beatmap);
            beatmap = map; audioSource.clip = clip; importedClip = id == null ? null : clip;
            songKey = id ?? Hash(beatmap.songTitle + "|" + beatmap.artist + "|" + clip.length.ToString("R", System.Globalization.CultureInfo.InvariantCulture) + "|" + beatmap.audioOffset.ToString("R", System.Globalization.CultureInfo.InvariantCulture));
            chartPath = Path.Combine(Application.persistentDataPath, "Charts", songKey + ".json");
            savedNotes = null; selectedChart = null; loadMessage = ""; LoadRecording();
            document.Load(savedNotes ?? beatmap.notes); editCursor = 0; loopA = 0; loopB = Math.Min(8, EditorEnd); loopEnabled = false;
            songLabel.text = beatmap.songTitle + "\n<size=18>" + beatmap.artist + "</size>";
            BuildWaveform(); RefreshLibrary(); RefreshEditor();
        }
    }
}
