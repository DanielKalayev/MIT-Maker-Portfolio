using System.Collections;
using System.Collections.Generic;
using AYellowpaper.SerializedCollections;
using UnityEngine;
using UnityEngine.SceneManagement;

public class GameManager : MonoBehaviour
{
    public static GameManager instance;

    [Header("Main")]
    public bool GameStarted { get; private set; }
    public bool DoStorySpawn;
    public SettingsObj SettingsObj;

    [Header("Tasks")]
    [SerializedDictionary("Task", "Completed")]
    [SerializeField] private SerializedDictionary<Task, bool> tasksCompleted;

    [Header("Enemies")]
    [SerializeField] private GameObject[] enemies;

    [Header("UI")]
    [SerializeField] private AnimationCurve animCurve;
    [SerializeField] private CanvasGroup blackBG;

    [Header("Audio")]
    [SerializeField] private AudioClip powerOutage;
    [SerializeField] private AudioClip restorePwr;
    [SerializeField] private AudioClip yayyy;
    [SerializeField] private AudioClip facilityEndSFX;

    [Header("Music")]
    [SerializeField] private AudioClip chillMusic;
    [SerializeField] private AudioClip horrorAmbience;

    private void Awake()
    {
        instance = this;

        if (!DoStorySpawn) GameStarted = true;
    }

    void OnEnable()
    {
        SceneManager.sceneLoaded += OnSceneLoaded;
    }
    void OnDisable()
    {
        SceneManager.sceneLoaded -= OnSceneLoaded;
    }

    void OnSceneLoaded(Scene scene, LoadSceneMode mode)
    {
        if (DoStorySpawn)
        {
            SpawnPlayer();
        }
    }
    private void SpawnPlayer()
    {
        blackBG.alpha = 1f;
        ToggleEnemies(false);
        Reactor.instance.ToggleCover(false);
        Player.instance.GetComponent<Rigidbody>().position = Elevator.instance.spawnPos.position;
        IEnumerator waited()
        {
            yield return new WaitForSeconds(1f);

            Elevator.instance.OpenDoor();
            ToggleCG(blackBG, false, 3.5f);
        }
        StartCoroutine(waited());
        SFXManager.instance.playMusic("Chill", chillMusic, 0.05f, true);
    }

    [ContextMenu("Start")]
    public void StartGame()
    {
        IEnumerator StartGameRoutine()
        {
            SFXManager.instance.GlobalSFX(powerOutage, 1f, 0.3f);
            LightObj.KillLights();
            SFXManager.instance.stopMusic("Chill", true);

            Reactor.instance.ToggleCover(false);

            yield return new WaitForSeconds(1.5f);
            GameStarted = true;
            Dialogue.instance.Announce("Find a Way to Restart the Reactor");
            Keybinds.instance.EnableKeybinds();
            SFXManager.instance.playMusic("Horror", horrorAmbience, 0.05f, true);

            if (SettingsObj.SpawnEnemies)
            {
                ToggleEnemies(true);
            }
        }
        StartCoroutine (StartGameRoutine());
    }

    private void ToggleCG(CanvasGroup group, bool toggle, float duration = 1f)
    {
        IEnumerator togg()
        {
            float startAlpha = group.alpha;
            float endAlpha = toggle ? 1f : 0f;

            float timer = 0f;
            while (timer < duration)
            {
                float t = timer / duration;
                t = animCurve.Evaluate(t);
                group.alpha = Mathf.Lerp(startAlpha, endAlpha, t);
                timer += Time.deltaTime / duration;
                yield return null;
            }

            group.alpha = endAlpha;
        }
        StartCoroutine(togg());
    }

    private void ToggleEnemies(bool toggle)
    {
        foreach(GameObject enemy in enemies)
        {
            enemy.SetActive(toggle);
        }
    }

    public void ToggleBlack(bool toggle, float duration = 1f)
    {
        ToggleCG(blackBG, toggle, duration);
    }

    public void CompleteTask(Task task)
    {
        tasksCompleted[task] = true;

        int total = 0;

        foreach (KeyValuePair<Task, bool> taskDone in tasksCompleted)
        {
            if (taskDone.Value) total++;
        }

        Reactor.instance.SetTaskScreen(total);
    }

    [ContextMenu("End")]
    public void CompleteGame()
    {
        IEnumerator EndGameRoutine()
        {
            SFXManager.instance.GlobalSFX(restorePwr, 2f);

            LightObj.RestoreLights();

            SFXManager.instance.stopMusic("Horror", true);

            yield return new WaitForSeconds(1.5f);

            GameStarted = false;
            Inventory.instance.ForceDisableAux();
            Inventory.instance.UnequipAll();

            Keybinds.instance.EnableKeybinds(false);

            Dialogue.instance.Announce("You Did It!");
            SFXManager.instance.playMusic("Chill", chillMusic, 0.05f, true);
            ToggleEnemies(false);

            yield return new WaitForSeconds(6f);

            SFXManager.instance.GlobalSFX(yayyy, 1f);

            yield return new WaitForSeconds(3f);

            SFXManager.instance.GlobalSFX(facilityEndSFX, 1f);

            yield return new WaitForSeconds(6.9f);

            Reactor.instance.Explode();

            yield return new WaitForSeconds(0.45f);

            SceneManager.LoadScene(2);
        }
        StartCoroutine(EndGameRoutine());
    }
}
