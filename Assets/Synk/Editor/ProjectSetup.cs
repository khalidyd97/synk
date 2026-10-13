using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Synk.Editor
{
    [InitializeOnLoad]
    public static class ProjectSetup
    {
        const string ScenePath = "Assets/Synk/Scenes/Main.unity";
        static ProjectSetup() { EditorApplication.delayCall += EnsureScene; }

        [MenuItem("SYNK/Set up mobile project")]
        public static void EnsureScene()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode || File.Exists(ScenePath)) return;
            Directory.CreateDirectory("Assets/Synk/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            new GameObject("SYNK Game").AddComponent<SynkGame>();
            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            PlayerSettings.companyName = "SynkStudio";
            PlayerSettings.productName = "SYNK";
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.synkstudio.rhythm");
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.iOS, "com.synkstudio.rhythm");
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.iOS.targetOSVersionString = "15.0";
            // This project uses the built-in Input API and StandaloneInputModule.
            var settings = new SerializedObject(AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset")[0]);
            var input = settings.FindProperty("activeInputHandler");
            if (input != null) { input.intValue = 0; settings.ApplyModifiedPropertiesWithoutUndo(); }
            AssetDatabase.SaveAssets();
        }

        [MenuItem("SYNK/Build Android APK")]
        public static void BuildAndroid()
        {
            EnsureScene();
            Directory.CreateDirectory("Builds/Android");
            EditorUserBuildSettings.buildAppBundle = false;
            BuildPipeline.BuildPlayer(new[] { ScenePath }, "Builds/Android/SYNK.apk", BuildTarget.Android, BuildOptions.None);
        }

        [MenuItem("SYNK/Export iOS Xcode project")]
        public static void BuildIOS()
        {
            EnsureScene();
            Directory.CreateDirectory("Builds/iOS");
            BuildPipeline.BuildPlayer(new[] { ScenePath }, "Builds/iOS", BuildTarget.iOS, BuildOptions.None);
        }
    }
}
